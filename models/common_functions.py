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
# -- Dmitry Nekrasov <bluebag@yandex.ru>   Fri, 10 May 2024 14:39:59 +0300

import numpy as np

def calculate_k( N, KW ):
    K = 1.0
    for i in range(N):
        K = K * 1 / np.sqrt( 1 + 2**(-2*i) )
    return int( round( K * 2**KW ) )


def generate_atan_table( N, AW, verilog_header_fname=None ):
    pi2 = np.pi / 2
    atan = np.array([ round( np.arctan(2**(-i)) * 2**AW/ pi2 ) for i in range(N) ])
    if verilog_header_fname is not None:
        fmt = lambda x : ("0"*int(np.ceil(AW/4) - len("%x"%x)) ) + "%x"%x
        f = open( verilog_header_fname, "w" )
        f.write( "{ " )
        for i in range( N-1, -1, -1 ):
            comma = ',' if i > 0 else ''
            f.write( f"{AW}'sh_{fmt(atan[i])}{comma} ")
        f.write("}\n")
        f.close()
    return atan

