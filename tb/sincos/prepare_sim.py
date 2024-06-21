#!bin/pythion3
#
# MIT License
#
# Copyright (c) 2024 Dmitriy Nekrasov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ---------------------------------------------------------------------------------
#
# Calculates initial parameters for simulation, creates files list and a header
# file with parameters.
#
# -- Dmitry Nekrasov <bluebag@yandex.ru> Thu, 21 Mar 2024 21:05:25 +0300

import sys
import os
cwd = os.getcwd()
model_path = '/../../models/'
sys.path.append( cwd + model_path )
from common_functions import generate_atan_table
from common_functions import calculate_k

N         = 10
DW        = 18
AW        = 12 # [0-360) deg
SINCOS_AW = AW-2 # Internal angle width [0-90) deg
KW        = SINCOS_AW

CORDIC_PIPELINE = ("none", "even", "all")[1]

K         = calculate_k( N, KW )
atan      = generate_atan_table( N, SINCOS_AW, "atan.vh" )

f = open( "parameters.v", "w" )
f.write(f"parameter N                = {N};\n")
f.write(f"parameter DW               = {DW};\n")
f.write(f"parameter AW               = {AW};\n")
f.write(f'parameter CORDIC_PIPELINE  = "{CORDIC_PIPELINE}";\n')
f.write(f"parameter SINCOS_AW        = {SINCOS_AW};\n")
f.write(f"parameter KW               = {KW};\n")
f.write(f"parameter K                = {K};\n")
f.close()

RTL_SOURCES = [
  '../../rtl/cordic_step.sv',
  '../../rtl/sincos.sv'
]

f = open( "files", "w" )
for i in range(len(RTL_SOURCES)):
    f.write(f"{RTL_SOURCES[i]}\n")
f.close()
