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
 * Coordinate rotation moule. See main readme ../README.md
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Fri, 10 May 2024 14:37:53 +0300
 */

`include "defines.vh"

module roatation #(
  parameter                 N      = 16,
  parameter                 DW     = 16,
  parameter                 AW     = DW, // Angle width
  parameter [N-1:0][AW-1:0] ATAN   = '{default:0},
  parameter                 KW     = DW,    // fixing coefficient width
  parameter [KW-1:0]        K      = 39797, // for DW = KW = 16
  parameter                 REG_EN = 0,
  parameter                 OW     = DW,
  // Can be turned off to save some area and reduce signal setup time
  parameter                 PRECISE_INVERSION = 1
) (
  input                        clk_i,
  input                  [1:0] quadrant_i,
  input               [AW-1:0] angle_i,
  input        signed [DW-1:0] x_i,
  input        signed [DW-1:0] y_i,
  output logic signed [OW-1:0] x_o,
  output logic signed [OW-1:0] y_o
);

// synopsys translate_off
initial
  begin : sim_parameter_check
    if( DW!=16 && K==39797 ) $fatal("\n\n\nYou forgot to re-define K for DW != 16\n\n\n");
    if( OW  < DW )           $fatal("\n\n\noutput_width can't be less than input width\n\n\n");
    if( OW == DW )           $display("%m: output width is the same as input width, it means that the \
source of data should be constained so that abs(x_i, y_i) <= 2**(DW-1)-1 !");
  end // sim_parameter_check
// synopsys translate_on

logic signed [N:0]  [DW:0] x;
logic signed [N:0]  [DW:0] y;
logic signed [N:0]  [AW:0] angle;
logic signed        [DW:0] minus_xn;
logic signed        [DW:0] minus_yn;
logic signed        [DW:0] quad_fix_x;
logic signed        [DW:0] quad_fix_y;
logic signed     [DW+KW:0] kx;
logic signed     [DW+KW:0] ky;
logic signed        [DW:0] kx_shift;
logic signed        [DW:0] ky_shift;
logic signed      [OW-1:0] x_sat;
logic signed      [OW-1:0] y_sat;

assign x[0]     = x_i;
assign y[0]     = y_i;
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
        .clk_i   ( clk_i             ),
        .y_i     ( y[i]              ),
        .x_i     ( x[i]              ),
        .a_i     ( angle[i]          ),
        .a_o     ( angle[i+1]        ),
        .x_o     ( x[i+1]            ),
        .y_o     ( y[i+1]            )
      );
    end // gen_rotators
endgenerate

generate
  if( PRECISE_INVERSION )
    begin : precise_inversion
      // Inversion with built-in overflow protection
      assign minus_xn = ~x[N] + `u( x[N][DW-1] != '0 );
      assign minus_xn = ~y[N] + `u( y[N][DW-1] != '0 );
    end // precise_inversion
  else
    begin : non_precise_inversion
      assign minus_xn = ~x[N];
      assign minus_xn = ~y[N];
    end // non_precise_inversion

always_comb
  unique case( quadrant_i )
    2'd0 : { quad_fix_y, quad_fix_x } = {     y[N],     x[N] };
    2'd1 : { quad_fix_y, quad_fix_x } = {     x[N], minus_yn };
    2'd2 : { quad_fix_y, quad_fix_x } = { minus_yn, minus_xn };
    2'd3 : { quad_fix_y, quad_fix_x } = { minus_xn,     y[N] };
  endcase

assign kx = quad_fix_x * `u(K);
assign ky = quad_fix_y * `u(K);

assign kx_shift = `s(kx[DW+KW:KW]) + `u(kx[KW-1]);
assign ky_shift = `s(ky[DW+KW:KW]) + `u(ky[KW-1]);

generate
  if( OW==DW )
    begin : saturation
      sat #(.IW(DW+1), .OW(DW) ) satx ( kx_shift, x_sat );
      sat #(.IW(DW+1), .OW(DW) ) saty ( ky_shift, y_sat );
    end // saturation
  else
    begin : no_saturation_needed
      assign x_sat = kx_shift;
      assign y_sat = ky_shift;
    end // no_saturation_needed
endgenerate

generate
  if( REG_EN )
    begin : reg_output
      always_ff @( posedge clk_i )
        begin
          x_o <= x_sat;
          y_o <= y_sat;
        end
    end // reg_output
  else
    begin : comb_output
      always_comb
        begin
          x_o = x_sat;
          y_o = y_sat;
        end
    end // comb_output
endgenerate

endmodule
