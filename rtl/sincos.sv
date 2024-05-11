/*
 * MIT License
 *
 * Copyright (c) 2024 Dmitriy Nekrasov
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * ---------------------------------------------------------------------------------
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Fri, 10 May 2024 14:38:19 +0300
 */

`include "defines.vh"

module sincos #(
  parameter                 N      = 16,
  parameter                 DW     = 16,
  parameter                 AW     = DW, // Angle width
  parameter [N-1:0][AW-1:0] ATAN   = '{default:0},
  parameter                 KW     = AW,    // fixing coefficient width
  parameter [KW-1:0]        K      = 39797, // for DW = KW = 16
  parameter                 REG_EN = 0
) (
  input                        clk_i,
  input                  [1:0] quadrant_i,
  input               [AW-1:0] angle_i,
  output logic signed [DW-1:0] sin_o,
  output logic signed [DW-1:0] cos_o
);

// synopsys translate_off
initial
  begin : sim_parameter_check
    if( DW!=16 && K==39797 ) $fatal("\n\n\nYou forgot to re-define K for DW != 16\n\n\n");
  end // sim_parameter_check
// synopsys translate_on

logic signed [N:0][DW:0] x;
logic signed [N:0][DW:0] y;
logic signed [N:0][AW:0] angle;
logic        [DW-1:0]    x_fix;
logic        [DW-1:0]    y_fix;
logic                    x_overflow_safe;
logic                    y_overflow_safe;
logic        [DW-2:0]    x_rnd;
logic        [DW-2:0]    y_rnd;
logic signed [DW-1:0]    sin;
logic signed [DW-1:0]    cos;
logic signed [DW-1:0]    minus_sin;
logic signed [DW-1:0]    minus_cos;
logic signed [DW-1:0]    sin_quad_fix;
logic signed [DW-1:0]    cos_quad_fix;

assign x[0]     = {1'b0, K};
assign y[0]     = 0;
assign angle[0] = {1'b0, angle_i};

genvar i;
generate
  for( i = 0; i < N; i++ )
    begin : gen_rotators
      cordic_step #(
        .DW      ( DW+1              ),
        .AW      ( AW+1              ),
        .SHIFT   ( i                 ),
        // force it to be unsigned, whatever the form
        .ATAN    ( { 1'b0, ATAN[i] } ),
        .MODE    ( "rotation"        )
      ) step (
        .y_i     ( y[i]              ),
        .x_i     ( x[i]              ),
        .a_i     ( angle[i]          ),
        .a_o     ( angle[i+1]        ),
        .x_o     ( x[i+1]            ),
        .y_o     ( y[i+1]            )
      );
    end // gen_rotators
endgenerate

// Cordic works inside the first quadrant, so the values are supposed to be
// positive. But they could be negative and approach 0 from negative side. In
// this case we need to fix it to zero (or to the maximum positive value).
// And the exact action depends on where we are, on the top or at the bottom
// of the angle range
always_comb
  if( angle_i[AW-1] ) // [45-90) degrees if true, else [0-45)
    begin
      x_fix = `sign(x[N]) ? `zeros(DW) : x[N][DW-1:0];
      y_fix = `sign(y[N]) ?  `ones(DW) : y[N][DW-1:0];
    end
  else
    begin
      x_fix = `sign(x[N]) ?  `ones(DW) : x[N][DW-1:0];
      y_fix = `sign(y[N]) ? `zeros(DW) : y[N][DW-1:0];
    end

// So now highest bit is always 0, let's check can we round and not to overflow
assign x_overflow_safe = ( x_fix[DW-1:1] != `ones(DW-1) );
assign y_overflow_safe = ( y_fix[DW-1:1] != `ones(DW-1) );

assign x_rnd = x_fix[DW-1:1] + ( x_fix[0] & x_overflow_safe );
assign y_rnd = y_fix[DW-1:1] + ( y_fix[0] & y_overflow_safe );

// Become signed again
assign sin = { 1'b0, y_rnd };
assign cos = { 1'b0, x_rnd };

// 2's complement inversion with built-in overflow protection
assign minus_sin = ~sin + `u(1'b1); // Probably overflow safe thing
assign minus_cos = ~cos + `u(1'b1); // would be needed here too...

always_comb
  case( quadrant_i )
    2'd0 : sin_quad_fix =       sin;
    2'd1 : sin_quad_fix =       cos;
    2'd2 : sin_quad_fix = minus_sin;
    2'd3 : sin_quad_fix = minus_cos;
  endcase

always_comb
  case( quadrant_i )
    2'd0 : cos_quad_fix =       cos;
    2'd1 : cos_quad_fix = minus_sin;
    2'd2 : cos_quad_fix = minus_cos;
    2'd3 : cos_quad_fix =       sin;
  endcase

generate
  if( REG_EN )
    begin : reg_output
      always_ff @( posedge clk_i )
        begin
          sin_o <= sin_quad_fix;
          cos_o <= cos_quad_fix;
        end
    end // reg_output
  else
    begin : comb_output
      always_comb
        begin
          sin_o = sin_quad_fix;
          cos_o = cos_quad_fix;
        end
    end // comb_output
endgenerate

endmodule

