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
# Here I want to prove to myself that cordic sincos generator not worse or worse
# with negligable differene than rounded precise sin/cos values stored in a
# table, because I want to replace table sin/cos in Fourier transform twidle
# generators. So it should be compared with values that I use in table sin/cos
# rather than precise sin/cos values.
#
# -- Dmitry Nekrasov <bluebag@yandex.ru>   Thu, 09 May 2024 17:30:50 +0300
import numpy as np
from common_functions import calculate_k
from common_functions import generate_atan_table


def reference_sincos( angle ):
    pi2   = np.pi / 2
    theta = pi2 * ( angle / 2**DW )
    return np.sin( theta ), np.cos( theta )


def reference_sincos_int( angle, AW, DW ):
    min_val = -2**(DW-1)
    max_val =  2**(DW-1)-1
    theta = 2 * np.pi * angle / 2**AW
    sin = np.clip( round( np.sin( theta ) * 2**(DW-1) ), min_val, max_val )
    cos = np.clip( round( np.cos( theta ) * 2**(DW-1) ), min_val, max_val )
    return sin, cos


def quadrant_fix( sin, cos, q ):
    ret_sin = { 0 :  sin,
                1 :  cos,
                2 : -sin,
                3 : -cos }
    ret_cos = { 0 :  cos,
                1 : -sin,
                2 : -cos,
                3 :  sin}
    return ret_sin[q], ret_cos[q]

def sincos_int_model( angle, q, atan, N, K, AW, KW, dbg=False ):
    max_val = 2**(AW-1)-1
    sign = lambda x : 1 if x==0 else np.sign( x )
    x, y, z = K, 0, angle
    for i in range( N ):
        x_ = int( x - y * sign( z ) * 2**(-i) )
        y_ = int( y + x * sign( z ) * 2**(-i) )
        z  = z - sign(z) * atan[i]
        x, y = x_, y_
        if( dbg ):
            print( "%4d %4d %4d" % (x, y, z) )
    #print( x, y )
    xn_rnd = round( x / 2 )
    yn_rnd = round( y / 2  )
    #print( xn_rnd, yn_rnd )
    sin = max_val if yn_rnd > max_val else yn_rnd
    cos = max_val if xn_rnd > max_val else xn_rnd
    #print( cos, sin )
    #exit()
    return quadrant_fix( sin, cos, q )
    #return sin / 2**(KW-1), cos / 2**(KW-1)

####################################################################

if __name__ == '__main__':
    N    = 16
    DW   = 16
    AW   = DW+2
    KW   = AW-2
    K    = calculate_k( N, KW )
    atan = generate_atan_table( N, AW-2 )

    # Specific angle test
    if( 0 ):
        angle = ...
        q          = angle // 2**(AW-2)
        angle_in_q = angle %  2**(AW-2)
        sinc, cosc = sincos_int_model( angle_in_q, q, atan, N, K, AW-2, KW )
        sinr, cosr = reference_sincos_int( angle, AW, DW )
        print( "reference : ", sinr, cosr )
        print( "model     : ", sinc, cosc )
        exit()

    sin_err2_acc = 0
    cos_err2_acc = 0
    sin_ref2_acc = 0
    cos_ref2_acc = 0
    sin_max_error = 0
    cos_max_error = 0
    for i in range( 2**AW ):
        angle      = i
        q          = angle // 2**(AW-2)
        angle_in_q = angle %  2**(AW-2)
        sinc, cosc = sincos_int_model( angle_in_q, q, atan, N, K, AW-2, KW )
        sinr, cosr = reference_sincos_int( angle, AW, DW )
        sin_error     = sinc - sinr
        cos_error     = cosc - cosr
        sin_err2_acc += sin_error**2
        cos_err2_acc += cos_error**2
        sin_ref2_acc += sinr**2
        cos_ref2_acc += cosr**2
        sin_max_error = abs( sin_error ) if sin_error > sin_max_error else sin_max_error
        cos_max_error = abs( cos_error ) if cos_error > cos_max_error else cos_max_error
        #print( sinc - sinr, cosc - cosr )

    nmse_sin = 10 * np.log10( sin_err2_acc / sin_ref2_acc )
    nmse_cos = 10 * np.log10( cos_err2_acc / cos_ref2_acc )
    print("NMSE:")
    print( "%4f dB, %4f dB" % ( nmse_sin, nmse_cos ) )
    print("Peak error:")
    print( "%4f %%, %4f %%" % ( sin_max_error * 100 / 2**DW , cos_max_error * 100 / 2**DW) )


