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
 * DSP Python-Verilog testbench template. Fits cases when DSP module is
 * systematically simple and have regular interface of input data, output data
 * with same bit width, input sample valid signal and output sample valid
 * signal. All it does is just translate parameters from higher level test
 * program and applies Python-generated data to input wires, monitors output
 * and collect some metrics (NMSE, peak error in %). It could be developed to do
 * some more complicated things, but this template is already pretty capable.
 * See more details in main README.md
 *
 *-- Dmitry Nekrasov <bluebag@yandex.ru> Thu, 21 Mar 2024 21:05:25 +0300
 */

`timescale 1ns/1ns

`define abs(X)   ( (X) >  0  ? (X) : -(X) )
`define max(X,Y) ( (X) > (Y) ? (X) :  (Y) )

module tb;

// If you see a parameter and it is not declared here, then it is declated
`include "parameters.v" // <------ THERE (automatically generated)

string score; // This one is going to be sourced in an outer script

bit clk;
bit srst;
bit stop_flag;

logic signed [DW-1:0] x_i;
logic signed [DW-1:0] y_i;
logic        [DW-1:0] r;
logic        [AW+1:0] angle;
logic        [AW-1:0] angle_inside_quadrant;
logic        [1:0]    quadrant;
logic                 input_valid;
logic                 output_valid;
logic        [DW-1:0] refr;
logic        [AW+1:0] refa;

initial forever #1 clk = ~clk;

initial
  begin
    @( posedge clk ) srst = 1'b1;
    @( posedge clk ) srst = 1'b0;
  end

//***************************************************************************

task automatic init_input( );
  input_valid <= 0;
  x_i         <= 'x;
  y_i         <= 'x;
endtask


function automatic check_for_x_states();
  for( int i = 0; i < DW; i++ )
    if( r[i]===1'bx || angle[i]===1'bx )
      return 1;
  return 0;
endfunction


task automatic driver ();
  int fx, fy;
  string strx, stry;
  fx = $fopen( INPUT_X_FNAME, "r" );
  fy = $fopen( INPUT_Y_FNAME, "r" );
  if( !fx ) $fatal( "can't open one of fils with test data" );
  if( !fy ) $fatal( "can't open one of fils with test data" );
  while( !$feof( fx ) )
    begin
      $fgets( strx, fx );
      $fgets( stry, fy );
      if( strx=="" || stry=="" )
        begin
          init_input();
          break;
        end
      x_i <= $signed(strx.atoi());
      y_i <= $signed(stry.atoi());
      input_valid <= 1;
      @( posedge clk );
      if( CLK_PER_SAMPLE > 1 )
        begin
          input_valid <= 0;
          repeat (CLK_PER_SAMPLE) @( posedge clk );
        end
    end
  init_input();
  $fclose(fx);
  $fclose(fy);
  repeat (CLK_PER_SAMPLE) @( posedge clk );
  stop_flag = 1;
endtask


task automatic monitor();
  int fr, fa;
  string strr, stra;
  fr = $fopen( REF_R_FNAME, "r" );
  fa = $fopen( REF_A_FNAME, "r" );
  if( !fr ) $fatal( "can't open one of files with reference data" );
  if( !fa ) $fatal( "can't open one of files with reference data" );
  while( ( !$feof( fr ) && !$feof(fa) && !stop_flag ) )
    begin
      $fgets( strr, fr );
      $fgets( stra, fa );
      if( strr=="" ) break;
      if( stra=="" ) break;
      refr = $signed(strr.atoi());
      refa = $signed(stra.atoi());
      do
        @( posedge clk );
      while( output_valid !== 1'b1 );
      if( output_valid===1'b1 && check_for_x_states() )
        $fatal( "\n\n\nX-states were found at the output, exiting\n\n\n" );
    end
  $fclose(fr);
  $fclose(fa);
endtask


function automatic string nmse_str( real err, reference );
  if( err==0 )
    nmse_str = "? (empty error accumulator)";
  else if( reference==0 )
    nmse_str = "? (empty reference accumulator)";
  else
    $sformat( nmse_str, "%f", 10.0*$log10( err / reference ) );
endfunction


// Updates "score" string each cycle. Waits "done" signal terminate and let
// main process quit fork-join block
int er, ea, max_er, max_ea;
task automatic scoreboard( );
  int cnt;
  longint er2_acc, ea2_acc, refr2_acc, refa2_acc;
  string nmse_r, nmse_a;
  real peak_er, peak_ea;
  while( !stop_flag  )
    begin
      if( output_valid === 1'b1 )
        begin
          cnt++;
          er         = int'(refr) - int'(r);
          ea         = int'(refa) - int'(angle);
          er2_acc   += er*er;
          ea2_acc   += ea*ea;
          refr2_acc += int'(refr)*int'(refr);
          refa2_acc += int'(refa)*int'(refa);
          nmse_r    = nmse_str( er2_acc, refr2_acc );
          nmse_a    = nmse_str( ea2_acc, refa2_acc );
          max_er    = `max( max_er, `abs( er ) );
          max_ea    = `max( max_ea, `abs( ea ) );
          peak_er   = ( real'(max_er) / real'(2**DW)  ) * 100;
          peak_ea   = ( real'(max_ea) / real'(2**DW)  ) * 100;
          $sformat( score, "%d vectors processed, nmse (r/a): %s / %s dB, peak error (r/a): %f / %f  %%",
            cnt, nmse_r, nmse_a, peak_er, peak_ea );
        end
      @( negedge clk );
    end
endtask


initial
  begin : main
    init_input();
    repeat ( CLK_PER_SAMPLE ) @( posedge clk );
    fork
      driver();
      monitor();
      scoreboard();
    join
    repeat( CLK_PER_SAMPLE ) @( posedge clk );
    if( TESTBENCH_MODE=="manual" )
      $display( "\n\n\n%s\n\n\n", score );
    $stop;
  end // main

//***************************************************************************

vectoring #(
  .N               ( N                    ),
  .DW              ( DW                   ),
  .AW              ( AW                   ),
  .ATAN            ( `include "atan.vh"   ),
  .KW              ( DW                   ),
  .K               ( K                    ),
  .CORDIC_PIPELINE ( CORDIC_PIPELINE      ),
  .OUTPUT_REG_EN   ( 1                    )
) DUT (
  .clk_i           ( clk                  ),
  .valid_i         ( input_valid          ),
  .x_i             ( x_i                  ),
  .y_i             ( y_i                  ),
  .r_o             ( r                    ),
  .angle_o         ( angle_inside_quadrant),
  .quadrant_o      ( quadrant             ),
  .valid_o         ( output_valid         )
);

assign angle = { quadrant, angle_inside_quadrant };

endmodule


