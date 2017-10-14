/*****************************************************************************
 * predict.S: arm intra prediction
 *****************************************************************************
 * Copyright (C) 2009-2015 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
 *          Mans Rullgard <mans@mansr.com>
 *          Martin Storsjo <martin@martin.st>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
 *
 * This program is also available under a commercial proprietary license.
 * For more information, contact us at licensing@x264.com.
 *****************************************************************************/

#include "asm.S"

#ifdef __arm__

@.fpu neon
//.section .rodata
.const_data
.align 4
p16weight: .short 1,2,3,4,5,6,7,8


.text

.macro ldcol.8  rd,  rs,  rt,  n=8,  hi=0
.if \n == 8 || \hi == 0
    vld1.8          {\rd[0]}, [\rs], \rt
    vld1.8          {\rd[1]}, [\rs], \rt
    vld1.8          {\rd[2]}, [\rs], \rt
    vld1.8          {\rd[3]}, [\rs], \rt
.endif
.if \n == 8 || \hi == 1
    vld1.8          {\rd[4]}, [\rs], \rt
    vld1.8          {\rd[5]}, [\rs], \rt
    vld1.8          {\rd[6]}, [\rs], \rt
    vld1.8          {\rd[7]}, [\rs], \rt
.endif
.endm

.macro ldcol.16  rd1,  rd2,  rs,  rt,  ru
    add             \ru, \rs, \rt, lsl #3
    vld1.8          {\rd1[0]}, [\rs], \rt
    vld1.8          {\rd2[0]}, [\ru], \rt
    vld1.8          {\rd1[1]}, [\rs], \rt
    vld1.8          {\rd2[1]}, [\ru], \rt
    vld1.8          {\rd1[2]}, [\rs], \rt
    vld1.8          {\rd2[2]}, [\ru], \rt
    vld1.8          {\rd1[3]}, [\rs], \rt
    vld1.8          {\rd2[3]}, [\ru], \rt
    vld1.8          {\rd1[4]}, [\rs], \rt
    vld1.8          {\rd2[4]}, [\ru], \rt
    vld1.8          {\rd1[5]}, [\rs], \rt
    vld1.8          {\rd2[5]}, [\ru], \rt
    vld1.8          {\rd1[6]}, [\rs], \rt
    vld1.8          {\rd2[6]}, [\ru], \rt
    vld1.8          {\rd1[7]}, [\rs], \rt
    vld1.8          {\rd2[7]}, [\ru], \rt
.endm

.macro add16x8  dq,  dl,  dh,  rl,  rh
    vaddl.u8        \dq, \rl, \rh
    vadd.u16        \dl, \dl, \dh
    vpadd.u16       \dl, \dl, \dl
    vpadd.u16       \dl, \dl, \dl
.endm


// because gcc doesn't believe in using the free shift in add
function x264_predict_4x4_h_armv6
    ldrb    r1, [r0, #0*FDEC_STRIDE-1]
    ldrb    r2, [r0, #1*FDEC_STRIDE-1]
    ldrb    r3, [r0, #2*FDEC_STRIDE-1]
    ldrb    ip, [r0, #3*FDEC_STRIDE-1]
    add     r1, r1, r1, lsl #8
    add     r2, r2, r2, lsl #8
    add     r3, r3, r3, lsl #8
    add     ip, ip, ip, lsl #8
    add     r1, r1, r1, lsl #16
    str     r1, [r0, #0*FDEC_STRIDE]
    add     r2, r2, r2, lsl #16
    str     r2, [r0, #1*FDEC_STRIDE]
    add     r3, r3, r3, lsl #16
    str     r3, [r0, #2*FDEC_STRIDE]
    add     ip, ip, ip, lsl #16
    str     ip, [r0, #3*FDEC_STRIDE]
    bx      lr
//endfunc
endfunc

function x264_predict_4x4_v_armv6
    ldr     r1,  [r0, #0 - 1 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 0 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 1 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 2 * FDEC_STRIDE]
    str     r1,  [r0, #0 + 3 * FDEC_STRIDE]
    bx      lr
endfunc

function x264_predict_4x4_dc_armv6
    mov     ip, #0
    ldr     r1, [r0, #-FDEC_STRIDE]
    ldrb    r2, [r0, #0*FDEC_STRIDE-1]
    ldrb    r3, [r0, #1*FDEC_STRIDE-1]
    usad8   r1, r1, ip
    add     r2, r2, #4
    ldrb    ip, [r0, #2*FDEC_STRIDE-1]
    add     r2, r2, r3
    ldrb    r3, [r0, #3*FDEC_STRIDE-1]
    add     r2, r2, ip
    add     r2, r2, r3
    add     r1, r1, r2
    lsr     r1, r1, #3
    add     r1, r1, r1, lsl #8
    add     r1, r1, r1, lsl #16
    str     r1, [r0, #0*FDEC_STRIDE]
    str     r1, [r0, #1*FDEC_STRIDE]
    str     r1, [r0, #2*FDEC_STRIDE]
    str     r1, [r0, #3*FDEC_STRIDE]
    bx      lr
endfunc

function x264_predict_4x4_dc_top_neon
    mov         r12, #FDEC_STRIDE
    sub         r1, r0, #FDEC_STRIDE
    vld1.32     d1[], [r1,:32]
    vpaddl.u8   d1, d1
    vpadd.u16   d1, d1, d1
    vrshr.u16   d1, d1, #2
    vdup.8      d1, d1[0]
    vst1.32     d1[0], [r0,:32], r12
    vst1.32     d1[0], [r0,:32], r12
    vst1.32     d1[0], [r0,:32], r12
    vst1.32     d1[0], [r0,:32], r12
    bx          lr
endfunc

// return a1 = (a1+2*b1+c1+2)>>2  a2 = (a2+2*b2+c2+2)>>2
.macro PRED4x4_LOWPASS a1 b1 c1 a2 b2 c2 pb_1
    uhadd8  \a1, \a1, \c1
    uhadd8  \a2, \a2, \c2
    uhadd8  \c1, \a1, \b1
    uhadd8  \c2, \a2, \b2
    eor     \a1, \a1, \b1
    eor     \a2, \a2, \b2
    and     \a1, \a1, \pb_1
    and     \a2, \a2, \pb_1
    uadd8   \a1, \a1, \c1
    uadd8   \a2, \a2, \c2
.endm

function x264_predict_4x4_ddr_armv6
    ldr     r1, [r0, # -FDEC_STRIDE]
    ldrb    r2, [r0, # -FDEC_STRIDE-1]
    ldrb    r3, [r0, #0*FDEC_STRIDE-1]
    push    {r4-r6,lr}
    add     r2, r2, r1, lsl #8
    ldrb    r4, [r0, #1*FDEC_STRIDE-1]
    add     r3, r3, r2, lsl #8
    ldrb    r5, [r0, #2*FDEC_STRIDE-1]
    ldrb    r6, [r0, #3*FDEC_STRIDE-1]
    add     r4, r4, r3, lsl #8
    add     r5, r5, r4, lsl #8
    add     r6, r6, r5, lsl #8
    ldr     ip, =0x01010101
    PRED4x4_LOWPASS r1, r2, r3, r4, r5, r6, ip
    str     r1, [r0, #0*FDEC_STRIDE]
    lsl     r2, r1, #8
    lsl     r3, r1, #16
    lsl     r4, r4, #8
    lsl     r5, r1, #24
    add     r2, r2, r4, lsr #24
    str     r2, [r0, #1*FDEC_STRIDE]
    add     r3, r3, r4, lsr #16
    str     r3, [r0, #2*FDEC_STRIDE]
    add     r5, r5, r4, lsr #8
    str     r5, [r0, #3*FDEC_STRIDE]
    pop     {r4-r6,pc}
endfunc

function x264_predict_4x4_ddl_neon
    sub         r0, #FDEC_STRIDE
    mov         ip, #FDEC_STRIDE
    vld1.64     {d0}, [r0], ip
    vdup.8      d3, d0[7]
    vext.8      d1, d0, d0, #1
    vext.8      d2, d0, d3, #2
    vhadd.u8    d0, d0, d2
    vrhadd.u8   d0, d0, d1
    vst1.32     {d0[0]}, [r0,:32], ip
    vext.8      d1, d0, d0, #1
    vext.8      d2, d0, d0, #2
    vst1.32     {d1[0]}, [r0,:32], ip
    vext.8      d3, d0, d0, #3
    vst1.32     {d2[0]}, [r0,:32], ip
    vst1.32     {d3[0]}, [r0,:32], ip
    bx          lr
endfunc

function x264_predict_8x8_dc_neon
    mov     ip, #0
    ldrd    r2, r3, [r1, #8]
    push    {r4-r5,lr}
    ldrd    r4, r5, [r1, #16]
    lsl     r3, r3, #8
    ldrb    lr, [r1, #7]
    usad8   r2, r2, ip
    usad8   r3, r3, ip
    usada8  r2, r4, ip, r2
    add     lr, lr, #8
    usada8  r3, r5, ip, r3
    add     r2, r2, lr
    mov     ip, #FDEC_STRIDE
    add     r2, r2, r3
    lsr     r2, r2, #4

    vdup.8   d0, r2
.rept 8
    vst1.64 {d0}, [r0,:64], ip
.endr
    pop    {r4-r5,pc}
endfunc

function x264_predict_8x8_h_neon
    add         r1, r1, #7
    mov         ip, #FDEC_STRIDE
    vld1.64     {d16}, [r1]
    vdup.8      d0, d16[7]
    vdup.8      d1, d16[6]
    vst1.64     {d0}, [r0,:64], ip
    vdup.8      d2, d16[5]
    vst1.64     {d1}, [r0,:64], ip
    vdup.8      d3, d16[4]
    vst1.64     {d2}, [r0,:64], ip
    vdup.8      d4, d16[3]
    vst1.64     {d3}, [r0,:64], ip
    vdup.8      d5, d16[2]
    vst1.64     {d4}, [r0,:64], ip
    vdup.8      d6, d16[1]
    vst1.64     {d5}, [r0,:64], ip
    vdup.8      d7, d16[0]
    vst1.64     {d6}, [r0,:64], ip
    vst1.64     {d7}, [r0,:64], ip
    bx          lr
endfunc

function x264_predict_8x8_v_neon
    add         r1, r1, #16
    mov         r12, #FDEC_STRIDE
    vld1.8      {d0}, [r1,:64]
.rept 8
    vst1.8      {d0}, [r0,:64], r12
.endr
    bx          lr
endfunc

function x264_predict_8x8_ddl_neon
    add         r1, #16
    vld1.8      {d0, d1}, [r1,:128]
    vmov.i8     q3, #0
    vrev64.8    d2, d1
    vext.8      q8, q3, q0, #15
    vext.8      q2, q0, q1, #1
    vhadd.u8    q8, q2
    mov         r12, #FDEC_STRIDE
    vrhadd.u8   q0, q8
    vext.8      d2, d0, d1, #1
    vext.8      d3, d0, d1, #2
    vst1.8      d2, [r0,:64], r12
    vext.8      d2, d0, d1, #3
    vst1.8      d3, [r0,:64], r12
    vext.8      d3, d0, d1, #4
    vst1.8      d2, [r0,:64], r12
    vext.8      d2, d0, d1, #5
    vst1.8      d3, [r0,:64], r12
    vext.8      d3, d0, d1, #6
    vst1.8      d2, [r0,:64], r12
    vext.8      d2, d0, d1, #7
    vst1.8      d3, [r0,:64], r12
    vst1.8      d2, [r0,:64], r12
    vst1.8      d1, [r0,:64], r12
    bx          lr
endfunc

function x264_predict_8x8_ddr_neon
    vld1.8      {d0-d3}, [r1,:128]
    vext.8      q2, q0, q1, #7
    vext.8      q3, q0, q1, #9

    vhadd.u8    q2, q2, q3
    vrhadd.u8   d0, d1, d4
    vrhadd.u8   d1, d2, d5

    add         r0, #7*FDEC_STRIDE
    mov         r12, #-1*FDEC_STRIDE

    vext.8      d2, d0, d1, #1
    vst1.8      {d0}, [r0,:64], r12
    vext.8      d4, d0, d1, #2
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d5, d0, d1, #3
    vst1.8      {d4}, [r0,:64], r12
    vext.8      d4, d0, d1, #4
    vst1.8      {d5}, [r0,:64], r12
    vext.8      d5, d0, d1, #5
    vst1.8      {d4}, [r0,:64], r12
    vext.8      d4, d0, d1, #6
    vst1.8      {d5}, [r0,:64], r12
    vext.8      d5, d0, d1, #7
    vst1.8      {d4}, [r0,:64], r12
    vst1.8      {d5}, [r0,:64], r12
    bx          lr
endfunc

function x264_predict_8x8_vl_neon
    add         r1, #16
    mov         r12, #FDEC_STRIDE

    vld1.8      {d0, d1}, [r1,:128]
    vext.8      q1, q1, q0, #15
    vext.8      q2, q0, q2, #1

    vrhadd.u8   q3, q0, q2

    vhadd.u8    q1, q1, q2
    vrhadd.u8   q0, q0, q1

    vext.8      d2, d0, d1, #1
    vst1.8      {d6}, [r0,:64], r12
    vext.8      d3, d6, d7, #1
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #2
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d3, d6, d7, #2
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #3
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d3, d6, d7, #3
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #4
    vst1.8      {d3}, [r0,:64], r12
    vst1.8      {d2}, [r0,:64], r12
    bx          lr
endfunc

function x264_predict_8x8_vr_neon
    add         r1, #8
    mov         r12, #FDEC_STRIDE
    vld1.8      {d4,d5}, [r1,:64]

    vext.8      q1, q2, q2, #14
    vext.8      q0, q2, q2, #15

    vhadd.u8    q3, q2, q1
    vrhadd.u8   q2, q2, q0
    vrhadd.u8   q0, q0, q3

    vmov        d2, d0

    vst1.8      {d5}, [r0,:64], r12
    vuzp.8      d2, d0
    vst1.8      {d1}, [r0,:64], r12
    vext.8      d6, d0, d5, #7
    vext.8      d3, d2, d1, #7
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d6, d0, d5, #6
    vext.8      d3, d2, d1, #6
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d3}, [r0,:64], r12
    vext.8      d6, d0, d5, #5
    vext.8      d3, d2, d1, #5
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d3}, [r0,:64], r12
    bx          lr
endfunc

function x264_predict_8x8_hd_neon
    mov         r12, #FDEC_STRIDE
    add         r1, #7

    vld1.8      {d2,d3}, [r1]
    vext.8      q3, q1, q1, #1
    vext.8      q2, q1, q1, #2

    vrhadd.u8   q8, q1, q3

    vhadd.u8    q1, q2
    vrhadd.u8   q0, q1, q3

    vzip.8      d16, d0

    vext.8      d2, d0, d1, #6
    vext.8      d3, d0, d1, #4
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d0, d1, #2
    vst1.8      {d3}, [r0,:64], r12
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d16, d0, #6
    vst1.8      {d0}, [r0,:64], r12
    vext.8      d3, d16, d0, #4
    vst1.8      {d2}, [r0,:64], r12
    vext.8      d2, d16, d0, #2
    vst1.8      {d3}, [r0,:64], r12
    vst1.8      {d2}, [r0,:64], r12
    vst1.8      {d16}, [r0,:64], r12

    bx          lr
endfunc

function x264_predict_8x8_hu_neon
    mov         r12, #FDEC_STRIDE
    add         r1, #7
    vld1.8      {d7}, [r1]
    vdup.8      d6, d7[0]
    vrev64.8    d7, d7

    vext.8      d4, d7, d6, #2
    vext.8      d2, d7, d6, #1

    vhadd.u8    d16, d7, d4
    vrhadd.u8   d0, d2, d7
    vrhadd.u8   d1, d16, d2

    vzip.8      d0, d1

    vdup.16     q1, d1[3]

    vext.8      q2, q0, q1, #2
    vext.8      q3, q0, q1, #4
    vext.8      q8, q0, q1, #6
    vst1.8      {d0}, [r0,:64], r12
    vst1.8      {d4}, [r0,:64], r12
    vst1.8      {d6}, [r0,:64], r12
    vst1.8      {d16}, [r0,:64], r12

    vst1.8      {d1}, [r0,:64], r12
    vst1.8      {d5}, [r0,:64], r12
    vst1.8      {d7}, [r0,:64], r12
    vst1.8      {d17}, [r0,:64]
    bx          lr
endfunc

function x264_predict_8x8c_dc_top_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {d0}, [r2,:64]
    vpaddl.u8   d0,  d0
    vpadd.u16   d0,  d0,  d0
    vrshrn.u16  d0,  q0,  #2
    vdup.8      d1,  d0[1]
    vdup.8      d0,  d0[0]
    vtrn.32     d0,  d1
    b           pred8x8_dc_end
endfunc

function x264_predict_8x8c_dc_left_neon
    mov         r1,  #FDEC_STRIDE
    sub         r2,  r0,  #1
    ldcol.8     d0,  r2,  r1
    vpaddl.u8   d0,  d0
    vpadd.u16   d0,  d0,  d0
    vrshrn.u16  d0,  q0,  #2
    vdup.8      d1,  d0[1]
    vdup.8      d0,  d0[0]
    b           pred8x8_dc_end
endfunc

function x264_predict_8x8c_dc_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {d0}, [r2,:64]
    sub         r2,  r0,  #1
    ldcol.8     d1,  r2,  r1
    vtrn.32     d0,  d1
    vpaddl.u8   q0,  q0
    vpadd.u16   d0,  d0,  d1
    vpadd.u16   d1,  d0,  d0
    vrshrn.u16  d2,  q0,  #3
    vrshrn.u16  d3,  q0,  #2
    vdup.8      d0,  d2[4]
    vdup.8      d1,  d3[3]
    vdup.8      d4,  d3[2]
    vdup.8      d5,  d2[5]
    vtrn.32     q0,  q2
pred8x8_dc_end:
    add         r2,  r0,  r1,  lsl #2
.rept 4
    vst1.8      {d0}, [r0,:64], r1
    vst1.8      {d1}, [r2,:64], r1
.endr
    bx          lr
endfunc

function x264_predict_8x8c_h_neon
    sub         r1, r0, #1
    mov         ip, #FDEC_STRIDE
.rept 4
    vld1.8      {d0[]}, [r1], ip
    vld1.8      {d2[]}, [r1], ip
    vst1.64     {d0}, [r0,:64], ip
    vst1.64     {d2}, [r0,:64], ip
.endr
    bx          lr
endfunc

function x264_predict_8x8c_v_neon
    sub         r0, r0, #FDEC_STRIDE
    mov         ip, #FDEC_STRIDE
    vld1.64     {d0}, [r0,:64], ip
.rept 8
    vst1.64     {d0}, [r0,:64], ip
.endr
    bx          lr
endfunc

function x264_predict_8x8c_p_neon
    sub         r3,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    add         r2,  r3,  #4
    sub         r3,  r3,  #1
    vld1.32     {d0[0]}, [r3]
    vld1.32     {d2[0]}, [r2,:32], r1
    ldcol.8     d0,  r3,  r1,  4,  hi=1
    add         r3,  r3,  r1
    ldcol.8     d3,  r3,  r1,  4
    vaddl.u8    q8,  d2,  d3
    vrev32.8    d0,  d0
    vtrn.32     d2,  d3
    vsubl.u8    q2,  d2,  d0
    movrel      r3,  p16weight
    vld1.16     {q0}, [r3,:128]
    vmul.s16    d4,  d4,  d0
    vmul.s16    d5,  d5,  d0
    vpadd.i16   d4,  d4,  d5
    vpaddl.s16  d4,  d4
    vshl.i32    d5,  d4,  #4
    vadd.s32    d4,  d4,  d5
    vrshrn.s32  d4,  q2,  #5
    mov         r3,  #0
    vtrn.16     d4,  d5
    vadd.i16    d2,  d4,  d5
    vshl.i16    d3,  d2,  #2
    vrev64.16   d16, d16
    vsub.i16    d3,  d3,  d2
    vadd.i16    d16, d16, d0
    vshl.i16    d2,  d16, #4
    vsub.i16    d2,  d2,  d3
    vext.16     q0,  q0,  q0,  #7
    vmov.16     d0[0], r3
    vmul.i16    q0,  q0,  d4[0]
    vdup.16     q1,  d2[0]
    vdup.16     q3,  d5[0]
    vadd.i16    q1,  q1,  q0
    mov         r3,  #8
1:
    vqshrun.s16 d0,  q1,  #5
    vadd.i16    q1,  q1,  q3
    vst1.8      {d0}, [r0,:64], r1
    subs        r3,  r3,  #1
    bne         1b
    bx          lr
endfunc


function x264_predict_8x16c_dc_top_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {d0}, [r2,:64]
    vpaddl.u8   d0,  d0
    vpadd.u16   d0,  d0,  d0
    vrshrn.u16  d0,  q0,  #2
    vdup.8      d1,  d0[1]
    vdup.8      d0,  d0[0]
    vtrn.32     d0,  d1

    add         r2,  r0,  r1,  lsl #2
.rept 4
    vst1.8      {d0}, [r0,:64], r1
    vst1.8      {d1}, [r2,:64], r1
.endr
    add         r2,  r2,  r1,  lsl #2
    add         r0,  r0,  r1,  lsl #2
.rept 4
    vst1.8      {d0}, [r0,:64], r1
    vst1.8      {d1}, [r2,:64], r1
.endr
    bx          lr
endfunc

function x264_predict_8x16c_h_neon
    sub         r1, r0, #1
    mov         ip, #FDEC_STRIDE
.rept 8
    vld1.8      {d0[]}, [r1], ip
    vld1.8      {d2[]}, [r1], ip
    vst1.64     {d0}, [r0,:64], ip
    vst1.64     {d2}, [r0,:64], ip
.endr
    bx          lr
endfunc

function x264_predict_8x16c_p_neon
    sub         r3,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    add         r2,  r3,  #4
    sub         r3,  r3,  #1
    vld1.32     {d0[0]}, [r3]
    vld1.32     {d2[0]}, [r2,:32], r1
    ldcol.8     d1,  r3,  r1
    add         r3,  r3,  r1
    ldcol.8     d3,  r3,  r1
    vrev64.32   d16, d3
    vaddl.u8    q8,  d2,  d16
    vrev32.8    d0,  d0
    vsubl.u8    q2,  d2,  d0
    vrev64.8    d1,  d1
    vsubl.u8    q3,  d3,  d1
    movrel      r3,  p16weight
    vld1.16     {q0}, [r3,:128]
    vmul.s16    d4,  d4,  d0
    vmul.s16    q3,  q3,  q0
    vpadd.i16   d4,  d4,  d5
    vpadd.i16   d6,  d6,  d7
    vpaddl.s16  d4,  d4        @ d4[0] = H
    vpaddl.s16  d6,  d6
    vpadd.s32   d6,  d6        @ d6[0] = V
    vshl.i32    d5,  d4,  #4
    vadd.s32    d4,  d4,  d5   @ d4[0] = 17*H
    vshl.i32    d7,  d6,  #2
    vrshrn.s32  d4,  q2,  #5   @ d4[0] = b
    vadd.s32    d6,  d6,  d7   @ d6[0] = 5*V
    vrshrn.s32  d6,  q3,  #6   @ d6[0] = c
    mov         r3,  #0
    vshl.i16    d3,  d4,  #2
    vsub.i16    d3,  d3,  d4   @ d2[0] = 3 * b
    vshl.i16    d2,  d6,  #3
    vadd.i16    d3,  d3,  d2   @ d2[0] = 3 * b + 8 * c
    vsub.i16    d3,  d3,  d6   @ d2[0] = 3 * b + 7 * c
    vrev64.16   d16, d16
    vadd.i16    d16, d16, d0   @ d16[0] = src[]+src[] + 1
    vshl.i16    d2,  d16, #4   @ d3[0] = a + 16
    vsub.i16    d2,  d2,  d3   @ i00
    vext.16     q0,  q0,  q0,  #7
    vmov.16     d0[0], r3
    vmul.i16    q0,  q0,  d4[0]
    vdup.16     q1,  d2[0]
    vdup.16     q3,  d6[0]
    vadd.i16    q1,  q1,  q0
    mov         r3,  #16
1:
    vqshrun.s16 d0,  q1,  #5
    vadd.i16    q1,  q1,  q3
    vst1.8      {d0}, [r0,:64], r1
    subs        r3,  r3,  #1
    bne         1b
    bx          lr
endfunc


function x264_predict_16x16_dc_top_neon
    sub         r2,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    vld1.8      {q0}, [r2,:128]
    add16x8     q0,  d0,  d1,  d0,  d1
    vrshrn.u16  d0,  q0,  #4
    vdup.8      q0,  d0[0]
    b           pred16x16_dc_end
endfunc

function x264_predict_16x16_dc_left_neon
    mov         r1,  #FDEC_STRIDE
    sub         r2,  r0,  #1
    ldcol.8     d0,  r2,  r1
    ldcol.8     d1,  r2,  r1
    add16x8     q0,  d0,  d1,  d0,  d1
    vrshrn.u16  d0,  q0,  #4
    vdup.8      q0,  d0[0]
    b           pred16x16_dc_end
endfunc

function x264_predict_16x16_dc_neon
    sub         r3, r0, #FDEC_STRIDE
    sub         r0, r0, #1
    vld1.64     {d0-d1}, [r3,:128]
    ldrb        ip, [r0], #FDEC_STRIDE
    vaddl.u8    q0, d0, d1
    ldrb        r1, [r0], #FDEC_STRIDE
    vadd.u16    d0, d0, d1
    vpadd.u16   d0, d0, d0
    vpadd.u16   d0, d0, d0
.rept 4
    ldrb        r2, [r0], #FDEC_STRIDE
    add         ip, ip, r1
    ldrb        r3, [r0], #FDEC_STRIDE
    add         ip, ip, r2
    ldrb        r1, [r0], #FDEC_STRIDE
    add         ip, ip, r3
.endr
    ldrb        r2, [r0], #FDEC_STRIDE
    add         ip, ip, r1
    ldrb        r3, [r0], #FDEC_STRIDE
    add         ip, ip, r2

    sub         r0, r0, #FDEC_STRIDE*16
    add         ip, ip, r3
    vdup.16     d1, ip
    vadd.u16    d0, d0, d1
    mov         r1, #FDEC_STRIDE
    add         r0, r0, #1
    vrshr.u16   d0, d0, #5
    vdup.8      q0, d0[0]
pred16x16_dc_end:
.rept 16
    vst1.64     {d0-d1}, [r0,:128], r1
.endr
    bx          lr
endfunc

function x264_predict_16x16_h_neon
    sub         r1, r0, #1
    mov         ip, #FDEC_STRIDE
.rept 8
    vld1.8      {d0[]}, [r1], ip
    vmov        d1, d0
    vld1.8      {d2[]}, [r1], ip
    vmov        d3, d2
    vst1.64     {d0-d1}, [r0,:128], ip
    vst1.64     {d2-d3}, [r0,:128], ip
.endr
    bx          lr
endfunc

function x264_predict_16x16_v_neon
    sub         r0, r0, #FDEC_STRIDE
    mov         ip, #FDEC_STRIDE
    vld1.64     {d0-d1}, [r0,:128], ip
.rept 16
    vst1.64     {d0-d1}, [r0,:128], ip
.endr
    bx          lr
endfunc

function x264_predict_16x16_p_neon
    sub         r3,  r0,  #FDEC_STRIDE
    mov         r1,  #FDEC_STRIDE
    add         r2,  r3,  #8
    sub         r3,  r3,  #1
    vld1.8      {d0}, [r3]
    vld1.8      {d2}, [r2,:64], r1
    ldcol.8     d1,  r3,  r1
    add         r3,  r3,  r1
    ldcol.8     d3,  r3,  r1
    vrev64.8    q0,  q0
    vaddl.u8    q8,  d2,  d3
    vsubl.u8    q2,  d2,  d0
    vsubl.u8    q3,  d3,  d1
    movrel      r3,  p16weight
    vld1.8      {q0}, [r3,:128]
    vmul.s16    q2,  q2,  q0
    vmul.s16    q3,  q3,  q0
    vadd.i16    d4,  d4,  d5
    vadd.i16    d5,  d6,  d7
    vpadd.i16   d4,  d4,  d5
    vpadd.i16   d4,  d4,  d4
    vshll.s16   q3,  d4,  #2
    vaddw.s16   q2,  q3,  d4
    vrshrn.s32  d4,  q2,  #6
    mov         r3,  #0
    vtrn.16     d4,  d5
    vadd.i16    d2,  d4,  d5
    vshl.i16    d3,  d2,  #3
    vrev64.16   d16, d17
    vsub.i16    d3,  d3,  d2
    vadd.i16    d16, d16, d0
    vshl.i16    d2,  d16, #4
    vsub.i16    d2,  d2,  d3
    vshl.i16    d3,  d4,  #4
    vext.16     q0,  q0,  q0,  #7
    vsub.i16    d6,  d5,  d3
    vmov.16     d0[0], r3
    vmul.i16    q0,  q0,  d4[0]
    vdup.16     q1,  d2[0]
    vdup.16     q2,  d4[0]
    vdup.16     q3,  d6[0]
    vshl.i16    q2,  q2,  #3
    vadd.i16    q1,  q1,  q0
    vadd.i16    q3,  q3,  q2
    mov         r3,  #16
1:
    vqshrun.s16 d0,  q1,  #5
    vadd.i16    q1,  q1,  q2
    vqshrun.s16 d1,  q1,  #5
    vadd.i16    q1,  q1,  q3
    vst1.8      {q0}, [r0,:128], r1
    subs        r3,  r3,  #1
    bne         1b
    bx          lr
endfunc



#elif defined(__arm64__)

const p8weight, align=4
    .short      1, 2, 3, 4, 1, 2, 3, 4
endconst
const p16weight, align=4
    .short      1, 2, 3, 4, 5, 6, 7, 8
endconst

.macro ldcol.8  vd,  xn,  xm,  n=8,  hi=0
.if \n == 8 || \hi == 0
    ld1        {\vd\().b}[0], [\xn], \xm
    ld1        {\vd\().b}[1], [\xn], \xm
    ld1        {\vd\().b}[2], [\xn], \xm
    ld1        {\vd\().b}[3], [\xn], \xm
.endif
.if \n == 8 || \hi == 1
    ld1        {\vd\().b}[4], [\xn], \xm
    ld1        {\vd\().b}[5], [\xn], \xm
    ld1        {\vd\().b}[6], [\xn], \xm
    ld1        {\vd\().b}[7], [\xn], \xm
.endif
.endm

.macro ldcol.16  vd,  xn,  xm
    ldcol.8     \vd, \xn, \xm
    ld1        {\vd\().b}[ 8], [\xn], \xm
    ld1        {\vd\().b}[ 9], [\xn], \xm
    ld1        {\vd\().b}[10], [\xn], \xm
    ld1        {\vd\().b}[11], [\xn], \xm
    ld1        {\vd\().b}[12], [\xn], \xm
    ld1        {\vd\().b}[13], [\xn], \xm
    ld1        {\vd\().b}[14], [\xn], \xm
    ld1        {\vd\().b}[15], [\xn], \xm
.endm


function x264_predict_4x4_h_aarch64, export=1
    ldrb    w1,  [x0, #0*FDEC_STRIDE-1]
    mov     w5,  #0x01010101
    ldrb    w2,  [x0, #1*FDEC_STRIDE-1]
    ldrb    w3,  [x0, #2*FDEC_STRIDE-1]
    mul     w1,  w1,  w5
    ldrb    w4,  [x0, #3*FDEC_STRIDE-1]
    mul     w2,  w2,  w5
    str     w1,  [x0, #0*FDEC_STRIDE]
    mul     w3,  w3,  w5
    str     w2,  [x0, #1*FDEC_STRIDE]
    mul     w4,  w4,  w5
    str     w3,  [x0, #2*FDEC_STRIDE]
    str     w4,  [x0, #3*FDEC_STRIDE]
    ret
endfunc

function x264_predict_4x4_v_aarch64, export=1
    ldr     w1,  [x0, #0 - 1 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 0 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 1 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 2 * FDEC_STRIDE]
    str     w1,  [x0, #0 + 3 * FDEC_STRIDE]
    ret
endfunc

function x264_predict_4x4_dc_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE
    ldrb        w4,  [x0, #-1 + 0 * FDEC_STRIDE]
    ldrb        w5,  [x0, #-1 + 1 * FDEC_STRIDE]
    ldrb        w6,  [x0, #-1 + 2 * FDEC_STRIDE]
    ldrb        w7,  [x0, #-1 + 3 * FDEC_STRIDE]
    add         w4,  w4,  w5
    ldr         s0, [x1]
    add         w6,  w6,  w7
    uaddlv      h0,  v0.8b
    add         w4,  w4,  w6
    dup         v0.4h,  v0.h[0]
    dup         v1.4h,  w4
    add         v0.4h,  v0.4h,  v1.4h
    rshrn       v0.8b,  v0.8h,  #3
    str         s0,  [x0]
    str         s0,  [x0, #1 * FDEC_STRIDE]
    str         s0,  [x0, #2 * FDEC_STRIDE]
    str         s0,  [x0, #3 * FDEC_STRIDE]
    ret
endfunc

function x264_predict_4x4_dc_top_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE
    ldr         s0, [x1]
    uaddlv      h0,  v0.8b
    dup         v0.4h,  v0.h[0]
    rshrn       v0.8b,  v0.8h,  #2
    str         s0,  [x0]
    str         s0,  [x0, #1 * FDEC_STRIDE]
    str         s0,  [x0, #2 * FDEC_STRIDE]
    str         s0,  [x0, #3 * FDEC_STRIDE]
    ret
    ret
endfunc

function x264_predict_4x4_ddr_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE+1
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.8b}, [x1], x7            // # -FDEC_STRIDE-1
    ld1r       {v1.8b}, [x1], x7            // #0*FDEC_STRIDE-1
    ld1r       {v2.8b}, [x1], x7            // #1*FDEC_STRIDE-1
    ext         v0.8b,  v1.8b,  v0.8b,  #7
    ld1r       {v3.8b}, [x1], x7            // #2*FDEC_STRIDE-1
    ext         v0.8b,  v2.8b,  v0.8b,  #7  // a
    ld1r       {v4.8b}, [x1], x7            // #3*FDEC_STRIDE-1
    ext         v1.8b,  v3.8b,  v0.8b,  #7  // b
    ext         v2.8b,  v4.8b,  v1.8b,  #7  // c
    uaddl       v0.8h,  v0.8b,  v1.8b
    uaddl       v1.8h,  v1.8b,  v2.8b
    add         v0.8h,  v0.8h,  v1.8h
    rshrn       v0.8b,  v0.8h,  #2

    ext         v3.8b,  v0.8b, v0.8b,  #3
    ext         v2.8b,  v0.8b, v0.8b,  #2
    ext         v1.8b,  v0.8b, v0.8b,  #1

    str         s3,  [x0], #FDEC_STRIDE
    str         s2,  [x0], #FDEC_STRIDE
    str         s1,  [x0], #FDEC_STRIDE
    str         s0,  [x0]
    ret
endfunc

function x264_predict_4x4_ddl_neon, export=1
    sub         x0,  x0,  #FDEC_STRIDE
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.8b}, [x0],  x7
    dup         v3.8b,  v0.b[7]
    ext         v1.8b,  v0.8b,  v0.8b,  #1
    ext         v2.8b,  v0.8b,  v3.8b,  #2
    uhadd       v0.8b,  v0.8b,  v2.8b
    urhadd      v0.8b,  v0.8b,  v1.8b
    str         s0,  [x0], #FDEC_STRIDE
    ext         v1.8b,  v0.8b,  v0.8b,  #1
    ext         v2.8b,  v0.8b,  v0.8b,  #2
    str         s1,  [x0], #FDEC_STRIDE
    ext         v3.8b,  v0.8b,  v0.8b,  #3
    str         s2,  [x0], #FDEC_STRIDE
    str         s3,  [x0]
    ret
endfunc

function x264_predict_8x8_dc_neon, export=1
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.16b}, [x1], #16
    ld1        {v1.8b},  [x1]
    ext         v0.16b, v0.16b, v0.16b, #7
    uaddlv      h1,  v1.8b
    uaddlv      h0,  v0.8b
    add         v0.8h,  v0.8h,  v1.8h
    dup         v0.8h,  v0.h[0]
    rshrn       v0.8b,  v0.8h,  #4
.rept 8
    st1        {v0.8b}, [x0], x7
.endr
    ret
endfunc

function x264_predict_8x8_h_neon, export=1
    mov         x7,  #FDEC_STRIDE
    ld1        {v16.16b}, [x1]
    dup         v0.8b, v16.b[14]
    dup         v1.8b, v16.b[13]
    st1        {v0.8b}, [x0], x7
    dup         v2.8b, v16.b[12]
    st1        {v1.8b}, [x0], x7
    dup         v3.8b, v16.b[11]
    st1        {v2.8b}, [x0], x7
    dup         v4.8b, v16.b[10]
    st1        {v3.8b}, [x0], x7
    dup         v5.8b, v16.b[9]
    st1        {v4.8b}, [x0], x7
    dup         v6.8b, v16.b[8]
    st1        {v5.8b}, [x0], x7
    dup         v7.8b, v16.b[7]
    st1        {v6.8b}, [x0], x7
    st1        {v7.8b}, [x0], x7
    ret
endfunc

function x264_predict_8x8_v_neon, export=1
    add         x1,  x1,  #16
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.8b}, [x1]
.rept 8
    st1        {v0.8b}, [x0], x7
.endr
    ret
endfunc

function x264_predict_8x8_ddl_neon, export=1
    add         x1,  x1,  #16
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.16b}, [x1]
    movi        v3.16b, #0
    dup         v2.16b, v0.b[15]
    ext         v4.16b, v3.16b, v0.16b, #15
    ext         v2.16b, v0.16b, v2.16b, #1
    uhadd       v4.16b, v4.16b, v2.16b
    urhadd      v0.16b, v0.16b, v4.16b
    ext         v1.16b, v0.16b, v0.16b, #1
    ext         v2.16b, v0.16b, v0.16b, #2
    st1        {v1.8b}, [x0], x7
    ext         v3.16b, v0.16b, v0.16b, #3
    st1        {v2.8b}, [x0], x7
    ext         v4.16b, v0.16b, v0.16b, #4
    st1        {v3.8b}, [x0], x7
    ext         v5.16b, v0.16b, v0.16b, #5
    st1        {v4.8b}, [x0], x7
    ext         v6.16b, v0.16b, v0.16b, #6
    st1        {v5.8b}, [x0], x7
    ext         v7.16b, v0.16b, v0.16b, #7
    st1        {v6.8b}, [x0], x7
    ext         v0.16b, v0.16b, v0.16b, #8
    st1        {v7.8b}, [x0], x7
    st1        {v0.8b}, [x0], x7
    ret
endfunc

function x264_predict_8x8_ddr_neon, export=1
    ld1        {v0.16b,v1.16b}, [x1]
    ext         v2.16b, v0.16b, v1.16b, #7
    ext         v4.16b, v0.16b, v1.16b, #9
    ext         v3.16b, v0.16b, v1.16b, #8

    uhadd       v2.16b, v2.16b, v4.16b
    urhadd      v7.16b, v3.16b, v2.16b

    add         x0,  x0,  #7*FDEC_STRIDE
    mov         x7,  #-1*FDEC_STRIDE

    ext         v6.16b, v7.16b, v7.16b, #1
    st1        {v7.8b},  [x0], x7
    ext         v5.16b, v7.16b, v7.16b, #2
    st1        {v6.8b},  [x0], x7
    ext         v4.16b, v7.16b, v7.16b, #3
    st1        {v5.8b},  [x0], x7
    ext         v3.16b, v7.16b, v7.16b, #4
    st1        {v4.8b},  [x0], x7
    ext         v2.16b, v7.16b, v7.16b, #5
    st1        {v3.8b},  [x0], x7
    ext         v1.16b, v7.16b, v7.16b, #6
    st1        {v2.8b},  [x0], x7
    ext         v0.16b, v7.16b, v7.16b, #7
    st1        {v1.8b},  [x0], x7
    st1        {v0.8b},  [x0], x7
    ret
endfunc

function x264_predict_8x8_vl_neon, export=1
    add         x1,  x1,  #16
    mov         x7, #FDEC_STRIDE

    ld1        {v0.16b}, [x1]
    ext         v1.16b, v1.16b, v0.16b, #15
    ext         v2.16b, v0.16b, v2.16b, #1

    uhadd       v1.16b, v1.16b, v2.16b
    urhadd      v3.16b, v0.16b, v2.16b

    urhadd      v0.16b, v0.16b, v1.16b

    ext        v4.16b, v0.16b, v0.16b, #1
    st1        {v3.8b}, [x0], x7
    ext        v5.16b, v3.16b, v3.16b, #1
    st1        {v4.8b}, [x0], x7
    ext        v6.16b, v0.16b, v0.16b, #2
    st1        {v5.8b}, [x0], x7
    ext        v7.16b, v3.16b, v3.16b, #2
    st1        {v6.8b}, [x0], x7
    ext        v4.16b, v0.16b, v0.16b, #3
    st1        {v7.8b}, [x0], x7
    ext        v5.16b, v3.16b, v3.16b, #3
    st1        {v4.8b}, [x0], x7
    ext        v6.16b, v0.16b, v0.16b, #4
    st1        {v5.8b}, [x0], x7
    st1        {v6.8b}, [x0], x7
    ret
endfunc

function x264_predict_8x8_vr_neon, export=1
    add         x1,  x1,  #8
    mov         x7,  #FDEC_STRIDE
    ld1        {v2.16b}, [x1]

    ext         v1.16b, v2.16b, v2.16b, #14
    ext         v0.16b, v2.16b, v2.16b, #15

    uhadd       v3.16b, v2.16b, v1.16b
    urhadd      v2.16b, v2.16b, v0.16b
    urhadd      v0.16b, v0.16b, v3.16b

    ext         v1.16b, v2.16b, v2.16b, #8
    uzp1        v2.8b,  v0.8b,  v0.8b
    uzp2        v3.8b,  v0.8b,  v0.8b
    ext         v0.16b, v0.16b, v0.16b, #8

    st1        {v1.8b}, [x0], x7
    st1        {v0.8b}, [x0], x7
    ext         v4.8b, v3.8b, v1.8b, #7
    ext         v5.8b, v2.8b, v0.8b, #7
    st1        {v4.8b}, [x0], x7
    st1        {v5.8b}, [x0], x7
    ext         v6.8b, v3.8b, v1.8b, #6
    ext         v7.8b, v2.8b, v0.8b, #6
    st1        {v6.8b}, [x0], x7
    st1        {v7.8b}, [x0], x7
    ext         v1.8b, v3.8b, v1.8b, #5
    ext         v0.8b, v2.8b, v0.8b, #5
    st1        {v1.8b}, [x0], x7
    st1        {v0.8b}, [x0], x7
    ret
endfunc

function x264_predict_8x8_hd_neon, export=1
    add         x1,  x1,  #7
    mov         x7, #FDEC_STRIDE

    ld1        {v1.16b}, [x1]
    ext         v3.16b, v1.16b, v1.16b, #1
    ext         v2.16b, v1.16b, v1.16b, #2

    urhadd      v4.16b, v1.16b, v3.16b

    uhadd       v1.16b, v1.16b, v2.16b
    urhadd      v0.16b, v1.16b, v3.16b

    zip1        v16.8b, v4.8b,  v0.8b
    zip2        v17.8b, v4.8b,  v0.8b
    ext         v7.16b, v0.16b, v0.16b, #8

    ext         v0.8b,  v17.8b, v7.8b,  #6
    ext         v1.8b,  v17.8b, v7.8b,  #4
    st1        {v0.8b},  [x0], x7
    ext         v2.8b,  v17.8b, v7.8b,  #2
    st1        {v1.8b},  [x0], x7
    st1        {v2.8b},  [x0], x7
    ext         v3.8b,  v16.8b, v17.8b, #6
    st1        {v17.8b}, [x0], x7
    ext         v4.8b,  v16.8b, v17.8b, #4
    st1        {v3.8b},  [x0], x7
    ext         v5.8b,  v16.8b, v17.8b, #2
    st1        {v4.8b},  [x0], x7
    st1        {v5.8b},  [x0], x7
    st1        {v16.8b}, [x0], x7

    ret
endfunc

function x264_predict_8x8_hu_neon, export=1
    add         x1,  x1,  #7
    mov         x7,  #FDEC_STRIDE
    ld1        {v7.8b}, [x1]
    dup         v6.8b,  v7.b[0]
    rev64       v7.8b,  v7.8b

    ext         v4.8b,  v7.8b,  v6.8b,  #2
    ext         v2.8b,  v7.8b,  v6.8b,  #1

    uhadd       v5.8b,  v7.8b,  v4.8b
    urhadd      v0.8b,  v2.8b,  v7.8b
    urhadd      v1.8b,  v5.8b,  v2.8b

    zip1        v16.8b, v0.8b,  v1.8b
    zip2        v17.8b, v0.8b,  v1.8b

    dup         v18.4h, v17.h[3]

    ext         v0.8b,  v16.8b, v17.8b, #2
    ext         v1.8b,  v16.8b, v17.8b, #4
    ext         v2.8b,  v16.8b, v17.8b, #6
    st1        {v16.8b}, [x0], x7
    st1        {v0.8b},  [x0], x7
    st1        {v1.8b},  [x0], x7
    st1        {v2.8b},  [x0], x7

    ext         v4.8b,  v17.8b, v18.8b, #2
    ext         v5.8b,  v17.8b, v18.8b, #4
    ext         v6.8b,  v17.8b, v18.8b, #6
    st1        {v17.8b}, [x0], x7
    st1        {v4.8b},  [x0], x7
    st1        {v5.8b},  [x0], x7
    st1        {v6.8b},  [x0]
    ret
endfunc


function x264_predict_8x8c_dc_top_neon, export=1
    sub         x2,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.8b},  [x2]
    uaddlp      v0.4h,  v0.8b
    addp        v0.4h,  v0.4h,  v0.4h
    rshrn       v0.8b,  v0.8h,  #2
    dup         v3.8b,  v0.b[1]
    dup         v2.8b,  v0.b[0]
    transpose   v0.2s,  v1.2s,  v2.2s,  v3.2s
    b           pred8x8c_dc_end
endfunc

function x264_predict_8x8c_dc_left_neon, export=1
    ldrb        w2,  [x0, #0 * FDEC_STRIDE - 1]
    ldrb        w3,  [x0, #1 * FDEC_STRIDE - 1]
    ldrb        w4,  [x0, #2 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, #3 * FDEC_STRIDE - 1]
    mov         x1,  #FDEC_STRIDE
    add         w2,  w2,  w3
    add         w3,  w4,  w5
    ldrb        w6,  [x0, #4 * FDEC_STRIDE - 1]
    ldrb        w7,  [x0, #5 * FDEC_STRIDE - 1]
    ldrb        w8,  [x0, #6 * FDEC_STRIDE - 1]
    ldrb        w9,  [x0, #7 * FDEC_STRIDE - 1]
    add         w6,  w6,  w7
    add         w7,  w8,  w9
    add         w2,  w2,  w3
    add         w6,  w6,  w7
    dup         v0.8h,  w2
    dup         v1.8h,  w6
    rshrn       v0.8b,  v0.8h,  #2
    rshrn       v1.8b,  v1.8h,  #2
    b           pred8x8c_dc_end
endfunc

function x264_predict_8x8c_dc_neon, export=1
    mov         x1,  #FDEC_STRIDE
    sub         x2,  x0,  #FDEC_STRIDE
    ldrb        w10, [x0, #0 * FDEC_STRIDE - 1]
    ldrb        w11, [x0, #1 * FDEC_STRIDE - 1]
    ldrb        w12, [x0, #2 * FDEC_STRIDE - 1]
    ldrb        w13, [x0, #3 * FDEC_STRIDE - 1]
    add         w10, w10, w11
    ldrb        w4,  [x0, #4 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, #5 * FDEC_STRIDE - 1]
    add         w12, w12, w13
    ldrb        w6,  [x0, #6 * FDEC_STRIDE - 1]
    ldrb        w7,  [x0, #7 * FDEC_STRIDE - 1]
    add         w4,  w4,  w5
    add         w6,  w6,  w7
    add         w10, w10, w12, lsl #16
    add         w4,  w4,  w6,  lsl #16
    ld1        {v0.8b},  [x2]
    add         x10, x10, x4,  lsl #32
    uaddlp      v0.4h,  v0.8b  // s0, s1
    mov         v1.d[0],  x10  // s2, s3
    add         v3.4h,  v0.4h,  v1.4h
    addp        v0.4h,  v0.4h,  v1.4h // s0, s1, s2, s3
    addp        v1.4h,  v3.4h,  v3.4h // s0+s2, s1+s3, s0+s2, s1+s3
    uzp2        v0.4h,  v0.4h,  v0.4h // s1,    s3,    s1,    s3
    uzp1        v1.2d,  v1.2d,  v1.2d
    uzp1        v0.2d,  v0.2d,  v0.2d
    rshrn       v3.8b,  v1.8h,  #3
    rshrn       v2.8b,  v0.8h,  #2
    uzp1        v0.8b,  v3.8b,  v2.8b
    uzp2        v1.8b,  v2.8b,  v3.8b
pred8x8c_dc_end:
    add         x2,  x0,  #2 * FDEC_STRIDE
    add         x4,  x0,  #4 * FDEC_STRIDE
    add         x5,  x0,  #6 * FDEC_STRIDE
    st1        {v0.8b}, [x0], x1
    st1        {v0.8b}, [x2], x1
    st1        {v0.8b}, [x0]
    st1        {v0.8b}, [x2]
    st1        {v1.8b}, [x4], x1
    st1        {v1.8b}, [x5], x1
    st1        {v1.8b}, [x4]
    st1        {v1.8b}, [x5]
    ret
endfunc

function x264_predict_8x8c_h_neon, export=1
    sub         x1,  x0,  #1
    mov         x7,  #FDEC_STRIDE
.rept 4
    ld1r       {v0.8b}, [x1], x7
    ld1r       {v1.8b}, [x1], x7
    st1        {v0.8b}, [x0], x7
    st1        {v1.8b}, [x0], x7
.endr
    ret
endfunc

function x264_predict_8x8c_v_aarch64, export=1
    ldr         x1,  [x0, #-FDEC_STRIDE]
.irp c, 0,1,2,3,4,5,6,7
    str         x1,  [x0, #\c * FDEC_STRIDE]
.endr
    ret
endfunc

function x264_predict_8x8c_p_neon, export=1
    sub         x3,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    add         x2,  x3,  #4
    sub         x3,  x3,  #1
    ld1        {v0.s}[0], [x3]
    ld1        {v2.s}[0], [x2], x1
    ldcol.8     v0,  x3,  x1,  4,  hi=1
    add         x3,  x3,  x1
    ldcol.8     v3,  x3,  x1,  4
    movrel      x4,  p8weight
    movrel      x5,  p16weight
    uaddl       v4.8h,  v2.8b,  v3.8b
    rev32       v0.8b,  v0.8b
    trn1        v2.2s,  v2.2s,  v3.2s
    ld1        {v7.8h}, [x4]
    usubl       v2.8h,  v2.8b,  v0.8b
    mul         v2.8h,  v2.8h,  v7.8h
    ld1        {v0.8h}, [x5]
    saddlp      v2.4s,  v2.8h
    addp        v2.4s,  v2.4s,  v2.4s
    shl         v3.2s,  v2.2s,  #4
    add         v2.2s,  v2.2s,  v3.2s
    rshrn       v5.4h,  v2.4s,  #5    // b, c, x, x
    addp        v2.4h,  v5.4h,  v5.4h
    shl         v3.4h,  v2.4h,  #2
    sub         v3.4h,  v3.4h,  v2.4h // 3 * (b + c)
    rev64       v4.4h,  v4.4h
    add         v4.4h,  v4.4h,  v0.4h
    shl         v2.4h,  v4.4h,  #4              // a
    sub         v2.4h,  v2.4h,  v3.4h           // a - 3 * (b + c) + 16
    ext         v0.16b, v0.16b, v0.16b, #14
    sub         v6.4h,  v5.4h,  v3.4h
    mov         v0.h[0],  wzr
    mul         v0.8h,  v0.8h,  v5.h[0]         // 0,1,2,3,4,5,6,7 * b
    dup         v1.8h,  v2.h[0]                 // pix
    dup         v2.8h,  v5.h[1]                 // c
    add         v1.8h,  v1.8h,  v0.8h           // pix + x*b
    mov         x3,  #8
1:
    subs        x3,  x3,  #1
    sqshrun     v0.8b,  v1.8h,  #5
    add         v1.8h,  v1.8h,  v2.8h
    st1        {v0.8b}, [x0], x1
    b.ne        1b
    ret
endfunc


.macro loadsum4 wd, t1, t2, t3, x, idx
    ldrb        \wd,  [\x, #(\idx + 0) * FDEC_STRIDE - 1]
    ldrb        \t1,  [\x, #(\idx + 1) * FDEC_STRIDE - 1]
    ldrb        \t2,  [\x, #(\idx + 2) * FDEC_STRIDE - 1]
    ldrb        \t3,  [\x, #(\idx + 3) * FDEC_STRIDE - 1]
    add         \wd,  \wd,  \t1
    add         \t1,  \t2,  \t3
    add         \wd,  \wd,  \t1
.endm

function x264_predict_8x16c_h_neon, export=1
    sub         x2,  x0,  #1
    add         x3,  x0,  #FDEC_STRIDE - 1
    mov         x7,  #2 * FDEC_STRIDE
    add         x1,  x0,  #FDEC_STRIDE
.rept 4
    ld1r       {v0.8b}, [x2], x7
    ld1r       {v1.8b}, [x3], x7
    ld1r       {v2.8b}, [x2], x7
    ld1r       {v3.8b}, [x3], x7
    st1        {v0.8b}, [x0], x7
    st1        {v1.8b}, [x1], x7
    st1        {v2.8b}, [x0], x7
    st1        {v3.8b}, [x1], x7
.endr
    ret
endfunc

function x264_predict_8x16c_v_neon, export=1
    sub         x1,  x0,  #FDEC_STRIDE
    mov         x2,  #2 * FDEC_STRIDE
    ld1        {v0.8b}, [x1], x2
.rept 8
    st1        {v0.8b}, [x0], x2
    st1        {v0.8b}, [x1], x2
.endr
    ret
endfunc

function x264_predict_8x16c_p_neon, export=1
    movrel      x4,  p16weight
    ld1        {v17.8h}, [x4]
    sub         x3,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    add         x2,  x3,  #4
    sub         x3,  x3,  #1

    ld1        {v0.8b}, [x3]
    ld1        {v2.8b}, [x2], x1
    ldcol.8     v1,  x3,  x1
    add         x3,  x3,  x1
    ldcol.8     v3,  x3,  x1
    ext         v4.8b,  v2.8b,  v2.8b,  #3
    ext         v5.8b,  v3.8b,  v3.8b,  #7
    rev32       v0.8b,  v0.8b
    rev64       v1.8b,  v1.8b

    uaddl       v4.8h,  v5.8b,  v4.8b // a * 1/16

    usubl       v2.8h,  v2.8b,  v0.8b
    mul         v2.8h,  v2.8h,  v17.8h
    saddlp      v2.4s,  v2.8h
    addp        v2.4s,  v2.4s,  v2.4s  // H

    usubl       v3.8h,  v3.8b,  v1.8b
    mul         v3.8h,  v3.8h,  v17.8h
    saddlp      v3.4s,  v3.8h
    addp        v3.4s,  v3.4s,  v3.4s
    addp        v3.4s,  v3.4s,  v3.4s  // V

    ext         v17.16b, v17.16b, v17.16b, #14

    shl         v4.4h,  v4.4h,  #4     // a
    shl         v6.2s,  v2.2s,  #4     // 16 * H
    shl         v7.2s,  v3.2s,  #2     // 4 * V
    add         v2.2s,  v2.2s,  v6.2s  // 17 * H
    add         v3.2s,  v3.2s,  v7.2s  // 5 * V
    rshrn       v2.4h,  v2.4s,  #5     // b
    rshrn       v3.4h,  v3.4s,  #6     // c

    mov         v17.h[0],  wzr

    sub         v4.4h,  v4.4h,  v2.4h  // a - b
    shl         v6.4h,  v2.4h,  #1     // 2 * b
    add         v4.4h,  v4.4h,  v3.4h  // a - b + c
    shl         v7.4h,  v3.4h,  #3     // 8 * c
    sub         v4.4h,  v4.4h,  v6.4h  // a - 3b + c
    sub         v4.4h,  v4.4h,  v7.4h  // a - 3b - 7c

    mul         v0.8h,  v17.8h, v2.h[0]         // 0,1,2,3,4,5,6,7 * b
    dup         v1.8h,  v4.h[0]                 // i00
    dup         v2.8h,  v3.h[0]                 // c
    add         v1.8h,  v1.8h,  v0.8h           // pix + {0..7}*b
    mov         x3,  #16
1:
    subs        x3,  x3,  #2
    sqrshrun    v4.8b,  v1.8h,  #5
    add         v1.8h,  v1.8h,  v2.8h
    sqrshrun    v5.8b,  v1.8h,  #5
    st1        {v4.8b}, [x0], x1
    add         v1.8h,  v1.8h,  v2.8h
    st1        {v5.8b}, [x0], x1
    b.ne        1b
    ret
endfunc

function x264_predict_8x16c_dc_neon, export=1
    mov         x1,  #FDEC_STRIDE
    sub         x10, x0,  #FDEC_STRIDE
    loadsum4    w2, w3, w4, w5, x0, 0
    ld1        {v6.8b}, [x10]
    loadsum4    w6, w7, w8, w9, x0, 4
    uaddlp      v6.4h,  v6.8b
    dup         v22.8h, w2              // s2
    dup         v23.8h, w6              // s3
    loadsum4    w2, w3, w4, w5, x0, 8
    addp        v6.4h,  v6.4h,  v6.4h   // s0, s1
    loadsum4    w6, w7, w8, w9, x0, 12
    dup         v20.8h, v6.h[0]         // s0
    dup         v21.8h, v6.h[1]         // s1
    dup         v24.8h, w2              // s4
    dup         v25.8h, w6              // s5

    ext         v16.16b, v20.16b, v21.16b, #8
    ext         v17.16b, v22.16b, v21.16b, #8
    ext         v1.16b,  v23.16b, v21.16b, #8
    ext         v2.16b,  v24.16b, v21.16b, #8
    ext         v3.16b,  v25.16b, v21.16b, #8

    add         v0.8h,  v16.8h, v17.8h
    add         v1.8h,  v1.8h,  v23.8h
    add         v2.8h,  v2.8h,  v24.8h
    add         v3.8h,  v3.8h,  v25.8h

    rshrn       v0.8b,  v0.8h,  #3
    rshrn       v1.8b,  v1.8h,  #3
    rshrn       v2.8b,  v2.8h,  #3
    rshrn       v3.8b,  v3.8h,  #3

    add         x11, x0,  #4  * FDEC_STRIDE
    add         x12, x0,  #8  * FDEC_STRIDE
    add         x13, x0,  #12 * FDEC_STRIDE
.rept 4
    st1        {v0.8b}, [x0],  x1
    st1        {v1.8b}, [x11], x1
    st1        {v2.8b}, [x12], x1
    st1        {v3.8b}, [x13], x1
.endr
    ret
endfunc

function x264_predict_8x16c_dc_left_neon, export=1
    mov         x1,  #FDEC_STRIDE
    ldrb        w2,  [x0, # 0 * FDEC_STRIDE - 1]
    ldrb        w3,  [x0, # 1 * FDEC_STRIDE - 1]
    ldrb        w4,  [x0, # 2 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, # 3 * FDEC_STRIDE - 1]
    add         w2,  w2,  w3

    ldrb        w6,  [x0, # 4 * FDEC_STRIDE - 1]
    add         w4,  w4,  w5
    ldrb        w7,  [x0, # 5 * FDEC_STRIDE - 1]
    add         w2,  w2,  w4
    ldrb        w8,  [x0, # 6 * FDEC_STRIDE - 1]
    ldrb        w9,  [x0, # 7 * FDEC_STRIDE - 1]
    dup         v0.8h,  w2
    add         w6,  w6,  w7
    rshrn       v0.8b,  v0.8h,  #2
    add         w8,  w8,  w9

    ldrb        w10, [x0, # 8 * FDEC_STRIDE - 1]
    ldrb        w11, [x0, # 9 * FDEC_STRIDE - 1]
    add         w6,  w6,  w8
    ldrb        w12, [x0, #10 * FDEC_STRIDE - 1]
    ldrb        w13, [x0, #11 * FDEC_STRIDE - 1]
    dup         v1.8h,  w6
    add         w10,  w10,  w11
    rshrn       v1.8b,  v1.8h,  #2
    add         w12,  w12,  w13

    ldrb        w2,  [x0, #12 * FDEC_STRIDE - 1]
    ldrb        w3,  [x0, #13 * FDEC_STRIDE - 1]
    add         w10,  w10,  w12
    ldrb        w4,  [x0, #14 * FDEC_STRIDE - 1]
    ldrb        w5,  [x0, #15 * FDEC_STRIDE - 1]
    dup         v2.8h,  w10
    add         w2,  w2,  w3
    rshrn       v2.8b,  v2.8h,  #2
    add         w4,  w4,  w5
    st1        {v0.8b}, [x0], x1
    st1        {v0.8b}, [x0], x1
    add         w2,  w2,  w4
    st1        {v0.8b}, [x0], x1
    dup         v3.8h,  w2
    st1        {v0.8b}, [x0], x1
    rshrn       v3.8b,  v3.8h,  #2

.irp  idx, 1, 2, 3
.rept 4
    st1        {v\idx\().8b}, [x0], x1
.endr
.endr
    ret
endfunc

function x264_predict_8x16c_dc_top_neon, export=1
    sub         x2,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.8b}, [x2]
    uaddlp      v0.4h,  v0.8b
    addp        v0.4h,  v0.4h,  v0.4h
    rshrn       v4.8b,  v0.8h,  #2
    dup         v0.8b,  v4.b[0]
    dup         v1.8b,  v4.b[1]
    ext         v0.8b,  v0.8b,  v1.8b,  #4
.rept 16
    st1        {v0.8b}, [x0], x1
.endr
    ret
endfunc


function x264_predict_16x16_dc_top_neon, export=1
    sub         x2,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.16b}, [x2]
    uaddlv      h0,     v0.16b
    rshrn       v0.8b,  v0.8h,  #4
    dup         v0.16b, v0.b[0]
    b           pred16x16_dc_end
endfunc

function x264_predict_16x16_dc_left_neon, export=1
    sub         x2,  x0,  #1
    mov         x1,  #FDEC_STRIDE
    ldcol.16    v0,  x2,  x1
    uaddlv      h0,     v0.16b
    rshrn       v0.8b,  v0.8h,  #4
    dup         v0.16b, v0.b[0]
    b           pred16x16_dc_end
endfunc

function x264_predict_16x16_dc_neon, export=1
    sub         x3,  x0,  #FDEC_STRIDE
    sub         x2,  x0,  #1
    mov         x1,  #FDEC_STRIDE
    ld1        {v0.16b}, [x3]
    ldcol.16    v1,  x2,  x1
    uaddlv      h0,     v0.16b
    uaddlv      h1,     v1.16b
    add         v0.4h,  v0.4h,  v1.4h
    rshrn       v0.8b,  v0.8h,  #5
    dup         v0.16b, v0.b[0]
pred16x16_dc_end:
.rept 16
    st1        {v0.16b}, [x0], x1
.endr
    ret
endfunc

function x264_predict_16x16_h_neon, export=1
    sub         x1,  x0,  #1
    mov         x7, #FDEC_STRIDE
.rept 8
    ld1r       {v0.16b}, [x1], x7
    ld1r       {v1.16b}, [x1], x7
    st1        {v0.16b}, [x0], x7
    st1        {v1.16b}, [x0], x7
.endr
    ret
endfunc

function x264_predict_16x16_v_neon, export=1
    sub         x0,  x0,  #FDEC_STRIDE
    mov         x7,  #FDEC_STRIDE
    ld1        {v0.16b}, [x0], x7
.rept 16
    st1        {v0.16b}, [x0], x7
.endr
    ret
endfunc

function x264_predict_16x16_p_neon, export=1
    sub         x3,  x0,  #FDEC_STRIDE
    mov         x1,  #FDEC_STRIDE
    add         x2,  x3,  #8
    sub         x3,  x3,  #1
    ld1        {v0.8b}, [x3]
    ld1        {v2.8b}, [x2], x1
    ldcol.8     v1,  x3,  x1
    add         x3,  x3,  x1
    ldcol.8     v3,  x3,  x1
    rev64       v0.8b,  v0.8b
    rev64       v1.8b,  v1.8b
    movrel      x4,  p16weight
    uaddl       v4.8h,  v2.8b,  v3.8b
    ld1        {v7.8h}, [x4]
    usubl       v2.8h,  v2.8b,  v0.8b
    usubl       v3.8h,  v3.8b,  v1.8b
    mul         v2.8h,  v2.8h,  v7.8h
    mul         v3.8h,  v3.8h,  v7.8h
    saddlp      v2.4s,  v2.8h
    saddlp      v3.4s,  v3.8h
    addp        v2.4s,  v2.4s,  v3.4s
    addp        v2.4s,  v2.4s,  v2.4s
    shl         v3.2s,  v2.2s,  #2
    add         v2.2s,  v2.2s,  v3.2s
    rshrn       v5.4h,  v2.4s,  #6    // b, c, x, x
    addp        v2.4h,  v5.4h,  v5.4h
    shl         v3.4h,  v2.4h,  #3
    sub         v3.4h,  v3.4h,  v2.4h // 7 * (b + c)
    ext         v4.16b, v4.16b, v4.16b, #14
    add         v4.4h,  v4.4h,  v7.4h
    shl         v2.4h,  v4.4h,  #4              // a
    sub         v2.4h,  v2.4h,  v3.4h           // a - 7 * (b + c) + 16
    ext         v7.16b, v7.16b, v7.16b, #14
    mov         v7.h[0],  wzr
    dup         v3.8h,  v5.h[0]
    mul         v0.8h,  v7.8h,  v5.h[0]         // 0,1,2,3,4,5,6,7 * b
    dup         v1.8h,  v2.h[0]                 // pix
    dup         v2.8h,  v5.h[1]                 // c
    shl         v3.8h,  v3.8h,  #3
    add         v1.8h,  v1.8h,  v0.8h           // pix + x*b
    add         v3.8h,  v3.8h,  v1.8h           // pix + x{8-15}*b
    mov         x3,  #16
1:
    subs        x3,  x3,  #1
    sqshrun     v0.8b,  v1.8h,  #5
    add         v1.8h,  v1.8h,  v2.8h
    sqshrun2    v0.16b, v3.8h,  #5
    add         v3.8h,  v3.8h,  v2.8h
    st1        {v0.16b}, [x0], x1
    b.ne        1b
    ret
endfunc

#endif 


