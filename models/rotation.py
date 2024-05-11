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
from common_functions import calculate_k
from common_functions import generate_atan_table

def reference_rotation( x, y, z ):
    pi2   = np.pi / 2
    theta = pi2 * ( z / 2**DW )
    xr = int( x * np.cos( theta ) - y * np.sin( theta ) )
    yr = int( x * np.sin( theta ) + y * np.cos( theta ) )
    return xr, yr


def quadrant_fix( x, y, q ):
    retval = { 0 : (  x,  y ),
               1 : ( -y,  x ),
               2 : ( -x, -y ),
               3 : (  y, -x ) }
    return retval[q]


def rotation_int_model( x, y, z, atan, N, K, AW, KW ):
    sign = lambda x : 1 if x==0 else np.sign( x )
    q = int( z / 2**AW )
    z = z - q * 2**AW
    for i in range( N ):
        x_ = int( x - y * sign( z ) * 2**(-i) )
        y_ = int( y + x * sign( z ) * 2**(-i) )
        z  = z - sign(z) * atan[i]
        x, y = x_, y_
    vec = quadrant_fix( x, y, q )
    x, y = vec[0], vec[1]
    return x * K // 2**KW, y * K // 2**KW

####################################################################

if __name__ == '__main__':
    N  = 8
    DW = 8
    AW = 8
    KW = AW
    K  = calculate_k( N, KW )
    atan = generate_atan_table( N, AW )
    rng = np.random.default_rng()

    x = int( rng.uniform( -2**(DW-1), 2**(DW-1)-1, 1 ) )
    y = int( rng.uniform( -2**(DW-1), 2**(DW-1)-1, 1 ) )
    z = int( rng.uniform(          0, 2**(AW+2)-1, 1 ) )

    xc, yc = rotation_int_model( x, y, z, atan, N, K, AW, KW )
    xr, yr = reference_rotation( x, y, z )

    print( "reference : ", xr, yr )
    print( "model     : ", xc, yc )
