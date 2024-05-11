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

def quadrant_fix( x, y ):
    quadrant = { (  True,  True ) : 0,
                 ( False,  True ) : 1,
                 ( False, False ) : 2,
                 (  True, False ) : 3 }
    retval = { 0 : (  x,  y ),
               1 : (  y, -x ),
               2 : ( -x, -y ),
               3 : ( -y,  x ) }
    q = quadrant[ ( x >= 0, y >= 0 ) ]
    return retval[q], q


def reference_vectoring( x, y, AW ):
    if( y == 0 and x > 0 ):
        return x, 0
    pi2   = np.pi / 2
    tmp, q = quadrant_fix( x, y )
    x, y = tmp[0], tmp[1]
    x = 0.00000000001 if x==0 else x # Dumb, i know..
    arctan = np.arctan( y/x )
    r = int( round( abs( complex( x, y ) ) ) )
    z = int( round( ( arctan / pi2 ) * ( 2**AW-1 ) ) )
    return r, ( z + q * 256 )


def range_check( r, z, DW, AW ):
    if( r > 2**DW-1 ):
        print( f"Error, r value ({r}) is outside output range" )
        exit()
    if( z > 2**AW-1 ):
        print( f"Error, angle value ({z}) is outside output range" )
        exit()


def vectoring_int_model( x, y, atan, N, K, DW, AW, KW, dbg=False ):
    sign = lambda x : 1 if x==0 else np.sign( x )
    max_angle = 2**AW-1
    tmp, q = quadrant_fix( x, y )
    x, y, z = tmp[0], tmp[1], 0
    on_axis = ( x==0 or y==0 )
    for i in range( N ):
        x_ = int( x + y * sign( y ) * 2**(-i) )
        y_ = int( y - x * sign( y ) * 2**(-i) )
        z  = z - sign( y ) * atan[i]
        x, y = x_, y_
        if( dbg ):
            print( "%4d %4d %4d" % (x, y, z) )
    angle_fix   = max_angle if ( -z > 2**AW-1 ) else -z
    angle_final = 0 if on_axis else angle_fix
    r = int( round( x * K / ( 2**KW ) ) )
    range_check( r, angle_final, DW, AW )
    return r, ( angle_final + q * 2**AW )

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

    rc, ac = vectoring_int_model( x, y, atan, N, K, DW, AW, KW, dbg=True )
    rr, ar = reference_vectoring( x, y, AW )

    print( "reference : ", rr, ar )
    print( "model     : ", rc, ac )
