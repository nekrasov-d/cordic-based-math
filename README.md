# Cordic-based math #

Cordic-based arithmeric RTL library

Contents:
  - [x] Rotation
  - [x] Vectorization
  - [x] Sine/cosine generator
  - [ ] Square root

### Design notes ###

   1. I don't see a point to make abs/arg-only modules because their features are
      included into rotation/vectorization and a synthesizer will backtace-remove
      no fanout circuits anyway
   2. There are two approaches to optimizatin vs reliability balance, In general
      we would want to have no redundant logic. For example, saturation, condition
      check cirquits that never actually used because the data never gets to these
      values (ever or if the parameters were set correctly). We may do thorough
      check, modeling, calculations to remove all redundant logic. This is the
      "ASIC" way where we count every gate, especially in highly replicated
      units. But when we don't have much time (for example, short time-to-market
      FPGA solutions), we might waste a bit of chip capacity to make it more
      error-proof if some was designed not the best way or some engineer made
      mistakes embedding our IP-cores. Here I focus on the second way, but try
      to make it so that the optimization for redundant checks would be easy
      keeping arithmetic atomized in clear expressions.
   3. It seems pointless to make cordic steps amount N more than quadrant angle
      (angle_i input, AW parameter) bit width. Optimal solution is N = AW.
   4. Fixed cordic coefficient K could be used if you need some gain/attenuation
      in your system that is relarively close to one, or attenuation that is not
      a power of two times less. In this case you may include this
      gain/attenuatuon into K value and not to waste area for another
      multiplier. It's a good idea to make option to make this coefficient
      dynamic, so that the gain is dynamially controlled, gain=K equals 0 dB
      gain. Typically, variable to variable multiplier costs more area than
      variable to constant, but an FPGA synthesizer may use DSP/multiplier block
      for variable to constant multiplication anyway.

### Rotation ###

Status:
  - [x] Done
  - [x] Simulation
  - [ ] Hardware run

Source files:
|       file         |  comment  |
| ------------------ | --------- |
| rtl/rotation.sv    | top level |
| rtl/cordic_step.sv |           |
| rtl/sat.sv         |           |

Basic rotation module. Takes two input values of the same bit width DW ( x_i and y_i )
and rotates them counter clockwise to some angle also given as an argument and scaled
to it's input bitwidth AW representing 90 degree range. Degrees from 90 to 360 could
be achived by putting quadrant index at the quadrant_i input.

Specs:
  * 1 clock 1 data
  * Latency: 0 clocks or 1 clock (if output register is enabled)
  * Output register on/off
  * Parameterized step amount N
  * Parameterized data bit width
  * Parameterized angle bit width
  * Separated angle / quadrant input
  * Angle input range scaled to [0-90) degree angle range
  * Additional quadrant_i input extents angle range to [0-360) degrees
  * Parameterized fix coefficient (K) bit width
  * Independet output bit width set (output bit width >= input bit width)
  * Comes along with the Python script (atan_generator.py) generating
  arctangent table and K coefficints for given angle bit width and step amount
  * Amount of adders needed (including constant K multiplication partial product
  adders) : <b>TODO: count</b>
  * Amount of variable \* variable multipliers needed: 0
  * Amount of block RAM needed: 0 bit

#### Overflow protection ####

It is clear that if input data width and output data width are the same,
we can get overflows. You can imagine it clearly if take two coordinates
of nearly max range, and then rotatne them a little bit in any direction.
It will quickly go outside one of axis range. There could be two
solutions: 1) Make output 1 bit wider. 2) Contol input source the way that
the hypotenuse of xy pair is always indie [min_val, max_val) for each
axis. But the calculations inside rotation module is not precise, and it
may happen that even if the constraints for xy pair are in effect, we
still cat face overflow. Possible solutions are a) give the source more
constraints b) add output value saturation logic. I decided to make b).
But this module could do both, use bigger output width or saturate output
data to output data bit width equal to input data bit width

#### Area optimization ####

If the module faces strict area consumption requirements, one may reduce logic
using PRECISE_INVERSION parameter. Made zero, it would replace precise
2's complement inversions with just bitwise inversions, losing some precision but
reducing two addters and two comparators.

TODO: Embed more area vs precision tradeoff options.

#### Testbench ####

Testbench (tb/rotation/) is based on my [DSP testbench template](...)
with little amount of modifications. See source -> README.md for more details.

The top level is test.py, altough tb.sv could also be the top level if you
already generated config, input data and reference data

Configure:
  just open test.py and edit global variables in the beginning of the file.

Run:
  python3 test.py

Results example ( N = DW = AW = 16, nsamples = 10e4):
```
  10000 vectors processed, nmse (x/y): -71.485825 / -71.476577 dB, peak error (x/y): 0.013733 / 0.013733  %
```

### Vectoring ###

Status:
  - [x] Done
  - [x] Simulation
  - [ ] Hardware run

Source files:
|       file         |  comment  |
| ------------------ | --------- |
| rtl/vectoring.sv   | top level |
| rtl/cordic_step.sv |           |

Receives two values as a vector coordinates and returns vector length and angle
with x-axis counter clockwise (0-360 degrees).

The idea behind this design is similar to the idea behind rotation. But instead
of checking sign of the angle to select next rotation direction, we check the
sign of Y-axis coordinate. And just like the actual angle approaches to the
given angle each step in rotation-mode cordic, Y-axis value approaches to 0 in
vectoring-mode cordic. When it is 0 or near to 0, it means that given vector meet
X-axis and the X-axis value now is the lenght of the vector (multipiled by
fixing coefficient K). The angle is negated at the output because cordic gives
clockwise angle needed to rotate vector to make it meet X axis. We invert angle
before put at at the output port.

Specs:
  * 1 clock 1 data
  * Latency: 0 clocks or 1 clock (if output register enabled)
  * Output register on/off
  * Parameterized step amount N
  * Parameterized data bit width
  * Separated angle / quadrant output
  * Angle input output scaled to [0-90) degree angle range + quadrant input
  gives [0-360) degrees ouput range
  * Parameterized fix coefficient (K) bit width
  * Takes pre-computed K as a static parameter
  * Comes along with a Python script (atan_generator.py) generating
  arctangent table and K coefficints for given angle bit width and step amount
  * Amount of adders needed (including constant K multiplication partial product
  adders) : <b>TODO: count</b>
  * Amount of variable \* variable multipliers needed: 0
  * Amount of block RAM needed: 0 bit

### Increasing angle precision ###

It was oserved that the precision of angle computation could be very small when
input values are small. Yes, if they are small ( say, [x,y] = [3,5] when bit
width is 8 bits ), the information about angle were already corrupted by
non-precise quantization. But it seems that the presented RTL soulution (and
it's Python model as well) gives results worse that it theoretically could.

Possible solutions:

  1. Multiply input values to some static integer coefficient (say, 256)
     Then, after all computations are done, rivide output r by 256 using right
     shift. Cons: it would require increased bitwidth -> higher area costs /
     delay. Pros: less logic than in option 2.
  2. Dynamic scaling (x2, x4, x8) depending on the data. Analyze input value
     magnitude and scale them just right to make them use whole value range.
     Then scale r back by right shift. Pros: increase precision with the same
     cordic bit width. Cons: more logic to detect range. And also it won't work
     if one of input values is big, only if both are small. Not sure if this
     precision loss remains the same if only one of values is small. TODO: check
     it.

TODO: try to impement or at least model one of these solutions.

#### Testbench ####

Testbench (tb/vectoring/) is based on my [DSP testbench template](...)
with little amount of modifications. See source -> README.md for more details.

The top level is test.py, altough tb.sv could also be the top level if you
already generated config, input data and reference data

Configure:
  just open test.py and edit global variables in the beginning

Run:
  python3 test.py

Results example ( N = DW = AW = 16, nsamples = 10e4):
```
Paramters: N = 16, DW = 16, AW = 16
Results:         100 vectors processed, nmse (r/a): -73.735460 / -88.291452 dB, peak error (r/a): 0.012207 / 0.033569  %
```

### Sine / cosine generator ###

This is a simplified version of rotation module. The Y-axis is always 0, and the
X-axis value is 1, but because this value is static, we can use cordic fix
coefficient K to remove K multiplier at the output. And we don't have any
overflow riscs here, obtained sine and cosine values are always < 1.

Status:
  - [x] Done
  - [x] Simulation
  - [ ] Hardware run

Source files:
|       file         |  comment  |
| ------------------ | --------- |
| rtl/sincos.sv      | top level |
| rtl/cordic_step.sv |           |

Specs:
  * 1 clock 1 data
  * Latency: 0 clocks or 1 clock (if output register enabled)
  * Output register on/off
  * Parameterized step amount N
  * Parameterized data bit width
  * Parameterized angle bit width
  * Angle and quadrant has different inputs to not to confuse bit widths
  * Internal angle precision based on computations inside one quadrant. For
  example, if given angle bit width is 16, and you want range of 360, then
  external angle source is scaled to 18 bit width where 2^18-1 is the angle
  closest to 360 degrees. Two MSBs are used as the quadrant_i input, the others
  are the angle cordic is about to use.
  * Parameterized fix coefficient (K) bit width
  * Takes pre-computed K as a static parameter
  * Comes along with a Python script (atan_generator.py) generating
  arctangent table and K coefficints for given angle bit width and step amount
  * Amount of adders needed: <b>TODO: count</b>
  * Amount of variable \* variable multipliers needed: 0
  * Amount of block RAM needed: 0 bit

#### Internal bit width and output bit width ####

We need signed output. Cordic generates unsigned output (inside first
quadrant). It means than we can do cordic bit width 1 bit smaller than output
bit width. But if we waste some area we may keep the design more protected from
wrong configuration and also keep code more clean and transparent.

Anyway, I'd like to make the code more versatile, but now I'm leaving this as a TODO

DW (internal) strictly equals to the desired output width for now.

#### Testbench ####

Unlike rotation and vectoring, I decided to keep sincos testbench very simple.
All I need here is to run all the angles through te module and see waveforms in
simulator in analog fomant. As soot as I see clear waves, to cracks, no jumps
etc., I can be pretty much sure it works alright. And to try just a couple of
different data width options would be enough.

The top level is tb.sv, but you need ro run prepare_sim.py firstly

Configure:
  just open prepare_sim.py and edit global variables in the beginning of the
  file. Then run python3 prepare_sim.py

Run:
  vsim -do make.tcl

Results example (with model run results on the background):
N = DW = AW = 18 (360 deg), nsamples = 2 full periods

![image:](https://raw.githubusercontent.com/nekrasov-d/cordic-based-math/main/tb/sincos/results.png)

### Square root ###

Status:
  - [x] In progress

The idea was picked [here](https://www.mathworks.com/help/fixedpoint/ug/compute-square-root-using-cordic.html)

The process is very similar to vectoring. When we do vectoring, we aquire square
root of the sum of catheti squared. But now we don't have catheti, so we need to
break input value into sum of two values...


### Authors ####

 -- Dmitry Nekrasov <bluebag@yandex.ru>  Sun, 05 May 2024 09:03:06 +0300

### License ###

MIT






