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
 * Extremely simplified testbench for this one. Because I plan to cover
 * precision aspects in the Python model, all I need here is just to observe
 * wavefroms on any bit width (let it be 16). As soon as I see clear sine/cosine
 * on outputs (without any jumps), I can be pretty much sure it works alright.
 *
 * -- Dmitry Nekrasov <bluebag@yandex.ru>   Thu, 09 May 2024 20:15:48 +0300
 */

`timescale 1ns/1ns

module tb;

// If you see a parameter and it is not declared here, then it is declated
`include "parameters.v" // <------ THERE (automatically generated)

bit clk;
initial forever #1 clk = ~clk;

bit [AW-1:0] counter;

always_ff @( posedge clk )
  counter <= counter + 1'b1;

initial
   begin : main
     repeat ( 2**AW ) @( posedge clk );
     $stop;
   end // main

sincos #(
  .N               ( N                    ),
  .DW              ( DW                   ),
  .AW              ( SINCOS_AW            ),
  .ATAN            ( `include "atan.vh"   ),
  .KW              ( DW                   ),
  .K               ( K                    ),
  .CORDIC_PIPELINE ( CORDIC_PIPELINE      ),
  .OUTPUT_REG_EN   ( 1                    )
) DUT (
  .clk_i           ( clk                  ),
  .quadrant_i      ( counter[AW-1:AW-2]   ),
  .angle_i         ( counter[AW-3:0]      ),
  .sin_o           (                      ),
  .cos_o           (                      )
);

endmodule
