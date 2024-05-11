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
 *  -- Dmitry Nekrasov <bluebag@yandex.ru>   Fri, 10 May 2024 14:38:30 +0300
 */

`include "defines.vh"

module vectoring #(
  parameter                 N      = 16,
  parameter                 DW     = 16,
  parameter                 AW     = DW, // Angle width
  parameter [N-1:0][AW-1:0] ATAN   = '{default:0},
  parameter                 KW     = AW,    // fixing coefficient width
  parameter [KW-1:0]        K      = 39797, // for DW = KW = 16
  parameter                 REG_EN = 0,
  parameter                 OW     = DW
) (
  input                        clk_i,
  input        signed [DW-1:0] x_i,
  input        signed [DW-1:0] y_i,
  output logic        [OW-1:0] r_o,
  output logic        [AW-1:0] angle_o,
  output logic           [1:0] quadrant_o
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

localparam [AW-1:0] MAX_ANGLE = {AW{1'b1}};


logic signed      [DW-1:0] minus_x;
logic signed      [DW-1:0] minus_y;
logic                [1:0] q;
logic signed      [DW-1:0] quad_fix_x;
logic signed      [DW-1:0] quad_fix_y;
logic signed [N:0]  [DW:0] x;
logic signed [N:0]  [DW:0] y;
logic signed [N:0]  [AW:0] angle;
logic                      angle_overflow;
logic             [AW-1:0] angle_inv;
logic             [AW-1:0] angle_fix; // Not signed anymore!
logic             [AW-1:0] angle_final;
logic            [DW+KW:0] kx;
logic               [DW:0] r;
logic             [OW-1:0] r_sat;

always_comb
  unique case({ `sign(y_i), `sign(x_i) } )
    2'b00 : q = 2'd0;
    2'b01 : q = 2'd1;
    2'b11 : q = 2'd2;
    2'b10 : q = 2'd3;
  endcase

assign minus_x = `s( ~x_i ) + `u( 1'b1 );
assign minus_y = `s( ~y_i ) + `u( 1'b1 );

always_comb
  unique case( q )
    2'd0 : { quad_fix_y, quad_fix_x } = {     y_i,     x_i };
    2'd1 : { quad_fix_y, quad_fix_x } = { minus_x,     y_i };
    2'd2 : { quad_fix_y, quad_fix_x } = { minus_y, minus_x };
    2'd3 : { quad_fix_y, quad_fix_x } = {     x_i, minus_y };
  endcase

assign x[0]     = quad_fix_x;
assign y[0]     = quad_fix_y;
assign angle[0] = 0;

genvar i;
generate
  for( i = 0; i < N; i++ )
    begin : gen_rotators
      cordic_step #(
        .DW      ( DW+1             ),
        .AW      ( AW+1             ),
        .SHIFT   ( i                ),
        // force it to be unsigned, whatever the form
        .ATAN    ( {1'b0, ATAN[i] } ),
        .MODE    ( "vectoring"      )
      ) step (
        .x_i     ( x[i]             ),
        .y_i     ( y[i]             ),
        .a_i     ( angle[i]         ),
        .a_o     ( angle[i+1]       ),
        .x_o     ( x[i+1]           ),
        .y_o     ( y[i+1]           )
      );
    end // gen_rotators
endgenerate

// Cordic loop returns angle which is required to put vector down to
// the x axis. Of course, if we work in the first quadrant, we need negative
// angle (clockwise rotation) to do it. But we need the opposite thing, the
// angle between vector and x axis. This is why we invert angle. See
// ../models/vectoring.py, the same thing is made there.
assign angle_overflow = ~angle[N][AW]; // angle[N] is supposed to be always negative
assign angle_inv      = ~angle[N][AW-1:0]; // Inverson without 2's complement +1
// Safe +1 in the 'else' branch. if angle[N] = 10...0 we got 111..11 in
// inversion and +1 will overflow the output. To prevent this, use comparator output
assign angle_fix = angle_overflow ? MAX_ANGLE : angle_inv + `u( angle_inv != {AW{1'b1}} );

assign kx = `u(x[N]) * `u(K);

assign r = kx[DW+KW:KW] + `u(kx[KW-1]);

// corner cases (literaly)
always_comb
  case( { ( y_i==0 ), ( x_i==0 ) } )
    2'b00   : angle_final = angle_fix;
    default : angle_final = '0;
  endcase

generate
  if( REG_EN )
    begin : reg_output
      always_ff @( posedge clk_i )
        begin
          r_o        <= r[DW-1:0];
          angle_o    <= angle_final;
          quadrant_o <= q;
        end
    end // reg_output
  else
    begin : comb_output
      always_comb
        begin
          r_o        = r[DW-1:0];
          angle_o    = angle_final;
          quadrant_o = q;
        end
    end // comb_output
endgenerate

endmodule
