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
 * Basic cordic element. Performs one elementary rotation operation.
 * Could be used both in rotation and vectoring modes
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Sun, 07 Apr 2024 22:25:31 +0300
*/

`include "defines.vh"

module cordic_step #(
  parameter          DW    = 0,
  parameter          AW    = 0,
  parameter          SHIFT = 0,
  parameter [AW-1:0] ATAN  = 0,
  parameter          MODE  = "rotation", // "vectoring",
  parameter          REG_EN = 0
) (
  input                        clk_i,
  input        signed [DW-1:0] x_i,
  input        signed [DW-1:0] y_i,
  input        signed [AW-1:0] a_i,
  output logic signed [AW-1:0] a_o,
  output logic signed [DW-1:0] x_o,
  output logic signed [DW-1:0] y_o
);

logic signed [DW-1:0] x_shift;
logic signed [DW-1:0] y_shift;

assign x_shift = x_i >>> SHIFT;
assign y_shift = y_i >>> SHIFT;

generate
  if( MODE=="rotation" )
    begin : rotation_mode
      if( REG_EN )
        always_ff @( posedge clk_i )
          begin
            x_o <= `sign(a_i) ? x_i + y_shift : x_i - y_shift;
            y_o <= `sign(a_i) ? y_i - x_shift : y_i + x_shift;
            a_o <= `sign(a_i) ? a_i + ATAN    : a_i - ATAN;
          end
      else
        always_comb
          begin
            x_o = `sign(a_i) ? x_i + y_shift : x_i - y_shift;
            y_o = `sign(a_i) ? y_i - x_shift : y_i + x_shift;
            a_o = `sign(a_i) ? a_i + ATAN    : a_i - ATAN;
          end
    end // rotation_mode
  else
    begin : vectoring_mode
      if( REG_EN )
        always_ff @( posedge clk_i )
          begin
            x_o <= `sign(y_i) ? x_i - y_shift : x_i + y_shift;
            y_o <= `sign(y_i) ? y_i + x_shift : y_i - x_shift;
            a_o <= `sign(y_i) ? a_i + ATAN    : a_i - ATAN;
          end
      else
        always_comb
          begin
            x_o = `sign(y_i) ? x_i - y_shift : x_i + y_shift;
            y_o = `sign(y_i) ? y_i + x_shift : y_i - x_shift;
            a_o = `sign(y_i) ? a_i + ATAN    : a_i - ATAN;
          end
    end // vectoring_mode
endgenerate

endmodule
