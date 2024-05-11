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
logic signed [DW-1:0] x_o;
logic signed [DW-1:0] y_o;
logic signed [DW-1:0] refx;
logic signed [DW-1:0] refy;
logic        [AW+1:0] z;
logic        [1:0]    quadrant;
logic        [AW-1:0] angle;
logic                 input_valid;
logic                 output_valid;

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
  quadrant    <= 'x;
  angle       <= 'x;
endtask


function automatic check_for_x_states();
  for( int i = 0; i < DW; i++ )
    if( x_o[i]===1'bx || y_o[i]===1'bx )
      return 1;
  return 0;
endfunction


task automatic driver ();
  int fx, fy, fz;
  string strx, stry, strz;
  fx = $fopen( INPUT_X_FNAME, "r" );
  fy = $fopen( INPUT_Y_FNAME, "r" );
  fz = $fopen( INPUT_Z_FNAME, "r" );
  if( !fx ) $fatal( "can't open one of fils with test data" );
  if( !fy ) $fatal( "can't open one of fils with test data" );
  if( !fz ) $fatal( "can't open one of fils with test data" );
  while( !$feof( fx ) )
    begin
      $fgets( strx, fx );
      $fgets( stry, fy );
      $fgets( strz, fz );
      if( strx=="" || stry=="" || strz=="" )
        begin
          init_input();
          break;
        end
      x_i <=   $signed(strx.atoi());
      y_i <=   $signed(stry.atoi());
      z    = $unsigned(strz.atoi());
      quadrant <= z[AW+1:AW];
      angle    <= z[AW-1:0];
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
  $fclose(fz);
  repeat (CLK_PER_SAMPLE) @( posedge clk );
  stop_flag = 1;
endtask


task automatic monitor();
  int fx, fy;
  string strx, stry;
  fx = $fopen( REF_X_FNAME, "r" );
  fy = $fopen( REF_Y_FNAME, "r" );
  if( !fx ) $fatal( "can't open one of files with reference data" );
  if( !fy ) $fatal( "can't open one of files with reference data" );
  while( ( !$feof( fx ) && !$feof(fy) && !stop_flag ) )
    begin
      @( posedge clk );
      if( input_valid === 1'b1 )
        begin
          $fgets( strx, fx );
          $fgets( stry, fy );
          if( strx=="" ) break;
          if( stry=="" ) break;
          refx = $signed(strx.atoi());
          refy = $signed(stry.atoi());
        end
      if( output_valid===1'b1 && check_for_x_states() )
        $fatal( "\n\n\nX-states were found at the output, exiting\n\n\n" );
    end
  $fclose(fx);
  $fclose(fy);
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
task automatic scoreboard( );
  int cnt;
  //int ex, ey, max_ex, max_ey;
  longint ex2_acc, ey2_acc, refx2_acc, refy2_acc;
  int ex, ey, max_ex, max_ey;
  string nmse_x, nmse_y;
  real peak_ex, peak_ey;
  while( !stop_flag  )
    begin
      if( output_valid === 1'b1 )
        begin
          cnt++;
          ex         = int'(refx) - int'(x_o);
          ey         = int'(refy) - int'(y_o);
          ex2_acc   += ex*ex;
          ey2_acc   += ey*ey;
          refx2_acc += int'(refx)*int'(refx);
          refy2_acc += int'(refy)*int'(refy);
          nmse_x    = nmse_str( ex2_acc, refx2_acc );
          nmse_y    = nmse_str( ey2_acc, refy2_acc );
          max_ex    = `max( max_ex, `abs( ex ) );
          max_ey    = `max( max_ey, `abs( ey ) );
          peak_ex   = ( real'(max_ex) / real'(2**DW)  ) * 100;
          peak_ey   = ( real'(max_ey) / real'(2**DW)  ) * 100;
          $sformat( score, "%d vectors processed, nmse (x/y): %s / %s dB, peak error (x/y): %f / %f  %%",
            cnt, nmse_x, nmse_y, peak_ex, peak_ey );
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


roatation #(
  .N             ( N                    ),
  .DW            ( DW                   ),
  .AW            ( AW                   ),
  .ATAN          ( `include "atan.vh"   ),
  .KW            ( DW                   ),
  .K             ( K                    ),
  .REG_EN        ( 1                    )
) DUT (
  .clk_i         ( clk                  ),
  .quadrant_i    ( quadrant             ),
  .angle_i       ( angle                ),
  .x_i           ( x_i                  ),
  .y_i           ( y_i                  ),
  .x_o           ( x_o                  ),
  .y_o           ( y_o                  )
);

always_ff @( posedge clk )
  output_valid <= input_valid;

endmodule


