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
# Simple CORDIC initializing data (K and arctan table) generator. Just edit
# variables below and run it
#   python3 atan_generator.py
#
# Output products:
#    - K : integer value. Copy it in parameters section when declare module instance
#    - "atan_file_name.vh" : file with { value1, value_2 ... } string, each
#      value corresponds to one arctangent. I suggest to use it like this
#      ...
#        .ATAN    ( `include "atan_file_name.vh" ),
#      ...
#      in the parameters section of a module instance. If all parameters (DW,
#      AW, N aka STEPS_AMOUNT) are aligned, then this string fits the instance.
#
# -- Dmitry Nekrasov <bluebag@yandex.ru>   Thu, 09 May 2024 17:30:50 +0300
import numpy as np
from models.common_functions import calculate_k
from models.common_functions import generate_atan_table

################################################################################
#                              USER PARAMETERS

# Data bit  width. Both input and output. If you generate atan/K for sin/cos
# generator, this refers to output data bit width only.
DW           = 16
# angle_i bit width + quadrant_i bit width. (QUADRANT_AW + 2)
# Represents [0-360) degrees angle range.
AW           = 18
# angle_i bit width
# Represents [0-90) degrees angle range.
QUADRANT_AW  = AW - 2
# You may re-define it, although it seems pointless to make STEPS_AMOUNT more
# than the number of bits in angle_i input (QUADRANT_AW). STE
STEPS_AMOUNT = QUADRANT_AW
# K coefficient bit width. Should be equal to data bit width, but I make another
# variable to point it out explicitly: This is K value bit width.
KW   = DW
# Change to yours
ATAN_FNAME = "atan_file_name.vh"

################################################################################

K    = calculate_k( STEPS_AMOUNT, KW )
atan = generate_atan_table( STEPS_AMOUNT, QUADRANT_AW, ATAN_FNAME )

print( "" )
print( f"Generated K value : {K}" )
print( f"put it at the K parameter input in instance declaration ( .K ( {K} ), )")
print( f"Generated arctangent table file : {ATAN_FNAME}" )
print( f'Inclue it at the ATAN parameter input in a module instance declaration: .ATAN ( `include "{ATAN_FNAME}" ),')
print( "" )
