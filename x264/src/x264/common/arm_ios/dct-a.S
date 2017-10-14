/****************************************************************************
 * dct-a.S: arm transform and zigzag
 *****************************************************************************
 * Copyright (C) 2009-2015 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
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

.const_data
//.section .rodata
.align 4

scan4x4_frame:
.byte    0,1,   8,9,   2,3,   4,5
.byte    2,3,   8,9,  16,17, 10,11
.byte   12,13,  6,7,  14,15, 20,21
.byte   10,11, 12,13,  6,7,  14,15

.text

// sum = a + (b>>shift)   sub = (a>>shift) - b
.macro SUMSUB_SHR shift sum sub a b t0 t1
    vshr.s16    \t0,  \b, #\shift
    vshr.s16    \t1,  \a, #\shift
    vadd.s16    \sum, \a, \t0
    vsub.s16    \sub, \t1, \b
.endm

// sum = (a>>shift) + b   sub = a - (b>>shift)
.macro SUMSUB_SHR2 shift sum sub a b t0 t1
    vshr.s16    \t0,  \a, #\shift
    vshr.s16    \t1,  \b, #\shift
    vadd.s16    \sum, \t0, \b
    vsub.s16    \sub, \a, \t1
.endm

// a += 1.5*ma   b -= 1.5*mb
.macro SUMSUB_15 a b ma mb t0 t1
    vshr.s16    \t0, \ma, #1
    vshr.s16    \t1, \mb, #1
    vadd.s16    \t0, \t0, \ma
    vadd.s16    \t1, \t1, \mb
    vadd.s16    \a,  \a,  \t0
    vsub.s16    \b,  \b,  \t1
.endm


function x264_dct4x4dc_neon
    vld1.64         {d0-d3}, [r0,:128]
    SUMSUB_ABCD     d4, d5, d6, d7, d0, d1, d2, d3
    SUMSUB_ABCD     d0, d2, d3, d1, d4, d6, d5, d7

    vmov.s16        d31, #1
    HADAMARD        1, sumsub, q2, q3, q0, q1
    vtrn.32         d4,  d5
    vadd.s16        d16, d4,  d31
    vtrn.32         d6,  d7
    vadd.s16        d17, d6,  d31
    vrhadd.s16      d0,  d4,  d5
    vhsub.s16       d1,  d16, d5
    vhsub.s16       d2,  d17, d7
    vrhadd.s16      d3,  d6,  d7
    vst1.64         {d0-d3}, [r0,:128]
    bx              lr
endfunc

function x264_idct4x4dc_neon
    vld1.64         {d0-d3}, [r0,:128]
    SUMSUB_ABCD     d4, d5, d6, d7, d0, d1, d2, d3
    SUMSUB_ABCD     d0, d2, d3, d1, d4, d6, d5, d7

    HADAMARD        1, sumsub, q2, q3, q0, q1
    HADAMARD        2, sumsub, d0, d1, d4, d5
    HADAMARD        2, sumsub, d3, d2, d6, d7
    vst1.64         {d0-d3}, [r0,:128]
    bx              lr
endfunc


.macro DCT_1D d0 d1 d2 d3  d4 d5 d6 d7
    SUMSUB_AB       \d1, \d6, \d5, \d6
    SUMSUB_AB       \d3, \d7, \d4, \d7
    vadd.s16        \d0, \d3, \d1
    vadd.s16        \d4, \d7, \d7
    vadd.s16        \d5, \d6, \d6
    vsub.s16        \d2, \d3, \d1
    vadd.s16        \d1, \d4, \d6
    vsub.s16        \d3, \d7, \d5
.endm

function x264_sub4x4_dct_neon
    mov             r3, #FENC_STRIDE
    mov             ip, #FDEC_STRIDE
    vld1.32         {d0[]}, [r1,:32], r3
    vld1.32         {d1[]}, [r2,:32], ip
    vld1.32         {d2[]}, [r1,:32], r3
    vsubl.u8        q8,  d0,  d1
    vld1.32         {d3[]}, [r2,:32], ip
    vld1.32         {d4[]}, [r1,:32], r3
    vsubl.u8        q9,  d2,  d3
    vld1.32         {d5[]}, [r2,:32], ip
    vld1.32         {d6[]}, [r1,:32], r3
    vsubl.u8        q10, d4,  d5
    vld1.32         {d7[]}, [r2,:32], ip
    vsubl.u8        q11, d6,  d7

    DCT_1D          d0, d1, d2, d3, d16, d18, d20, d22
    TRANSPOSE4x4_16 d0, d1, d2, d3
    DCT_1D          d4, d5, d6, d7, d0, d1, d2, d3
    vst1.64         {d4-d7}, [r0,:128]
    bx              lr
endfunc

function x264_sub8x4_dct_neon, export=0
    vld1.64         {d0}, [r1,:64], r3
    vld1.64         {d1}, [r2,:64], ip
    vsubl.u8        q8,  d0,  d1
    vld1.64         {d2}, [r1,:64], r3
    vld1.64         {d3}, [r2,:64], ip
    vsubl.u8        q9,  d2,  d3
    vld1.64         {d4}, [r1,:64], r3
    vld1.64         {d5}, [r2,:64], ip
    vsubl.u8        q10, d4,  d5
    vld1.64         {d6}, [r1,:64], r3
    vld1.64         {d7}, [r2,:64], ip
    vsubl.u8        q11, d6,  d7

    DCT_1D          q0, q1, q2, q3,  q8, q9, q10, q11
    TRANSPOSE4x4_16 q0, q1, q2, q3

    SUMSUB_AB       q8,  q12, q0,  q3
    SUMSUB_AB       q9,  q10, q1,  q2
    vadd.i16        q13, q12, q12
    vadd.i16        q11, q10, q10
    vadd.i16        d0,  d16, d18
    vadd.i16        d1,  d26, d20
    vsub.i16        d2,  d16, d18
    vsub.i16        d3,  d24, d22
    vst1.64         {d0-d1}, [r0,:128]!
    vadd.i16        d4,  d17, d19
    vadd.i16        d5,  d27, d21
    vst1.64         {d2-d3}, [r0,:128]!
    vsub.i16        d6,  d17, d19
    vsub.i16        d7,  d25, d23
    vst1.64         {d4-d5}, [r0,:128]!
    vst1.64         {d6-d7}, [r0,:128]!
    bx              lr
endfunc

function x264_sub8x8_dct_neon
    push            {lr}
    mov             r3, #FENC_STRIDE
    mov             ip, #FDEC_STRIDE
    bl              x264_sub8x4_dct_neon
    pop             {lr}
    b               x264_sub8x4_dct_neon
endfunc

function x264_sub16x16_dct_neon
    push            {lr}
    mov             r3, #FENC_STRIDE
    mov             ip, #FDEC_STRIDE
    bl              x264_sub8x4_dct_neon
    bl              x264_sub8x4_dct_neon
    sub             r1, r1, #8*FENC_STRIDE-8
    sub             r2, r2, #8*FDEC_STRIDE-8
    bl              x264_sub8x4_dct_neon
    bl              x264_sub8x4_dct_neon
    sub             r1, r1, #8
    sub             r2, r2, #8
    bl              x264_sub8x4_dct_neon
    bl              x264_sub8x4_dct_neon
    sub             r1, r1, #8*FENC_STRIDE-8
    sub             r2, r2, #8*FDEC_STRIDE-8
    bl              x264_sub8x4_dct_neon
    pop             {lr}
    b               x264_sub8x4_dct_neon
endfunc


.macro DCT8_1D type
    SUMSUB_AB       q2,  q1,  q11, q12  // s34/d34
    SUMSUB_AB       q3,  q11, q10, q13  // s25/d25
    SUMSUB_AB       q13, q10, q9,  q14  // s16/d16
    SUMSUB_AB       q14, q8,  q8,  q15  // s07/d07

    SUMSUB_AB       q9,  q2,  q14, q2   // a0/a2
    SUMSUB_AB       q12, q14, q13, q3   // a1/a3

    SUMSUB_AB       q3,  q13, q8,  q1   // a6/a5
    vshr.s16        q0,  q10, #1
    vshr.s16        q15, q11, #1
    vadd.s16        q0,  q0,  q10
    vadd.s16        q15, q15, q11
    vsub.s16        q3,  q3,  q0
    vsub.s16        q13, q13, q15

    SUMSUB_AB       q0,  q15, q10, q11  // a4/a7
    vshr.s16        q10, q8,  #1
    vshr.s16        q11, q1,  #1
    vadd.s16        q10, q10, q8
    vadd.s16        q11, q11, q1
    vadd.s16        q10, q0,  q10
    vadd.s16        q15, q15, q11

    SUMSUB_AB       q8,  q12, q9,  q12
    SUMSUB_SHR   2, q9,  q15, q10, q15,  q0, q1
    SUMSUB_SHR   1, q10, q14, q2,  q14,  q0, q1
    SUMSUB_SHR2  2, q11, q13, q3,  q13,  q0, q1
.endm

function x264_sub8x8_dct8_neon
    mov             r3, #FENC_STRIDE
    mov             ip, #FDEC_STRIDE
    vld1.64         {d16}, [r1,:64], r3
    vld1.64         {d17}, [r2,:64], ip
    vsubl.u8        q8,  d16, d17
    vld1.64         {d18}, [r1,:64], r3
    vld1.64         {d19}, [r2,:64], ip
    vsubl.u8        q9,  d18, d19
    vld1.64         {d20}, [r1,:64], r3
    vld1.64         {d21}, [r2,:64], ip
    vsubl.u8        q10, d20, d21
    vld1.64         {d22}, [r1,:64], r3
    vld1.64         {d23}, [r2,:64], ip
    vsubl.u8        q11, d22, d23
    vld1.64         {d24}, [r1,:64], r3
    vld1.64         {d25}, [r2,:64], ip
    vsubl.u8        q12, d24, d25
    vld1.64         {d26}, [r1,:64], r3
    vld1.64         {d27}, [r2,:64], ip
    vsubl.u8        q13, d26, d27
    vld1.64         {d28}, [r1,:64], r3
    vld1.64         {d29}, [r2,:64], ip
    vsubl.u8        q14, d28, d29
    vld1.64         {d30}, [r1,:64], r3
    vld1.64         {d31}, [r2,:64], ip
    vsubl.u8        q15, d30, d31

    DCT8_1D row
    vswp            d17, d24    // 8, 12
    vswp            d21, d28    // 10,14
    vtrn.32         q8,  q10
    vtrn.32         q12, q14

    vswp            d19, d26    // 9, 13
    vswp            d23, d30    // 11,15
    vtrn.32         q9,  q11
    vtrn.32         q13, q15

    vtrn.16         q10, q11
    vtrn.16         q12, q13
    vtrn.16         q8,  q9
    vtrn.16         q14, q15
    DCT8_1D col

    vst1.64         {d16-d19}, [r0,:128]!
    vst1.64         {d20-d23}, [r0,:128]!
    vst1.64         {d24-d27}, [r0,:128]!
    vst1.64         {d28-d31}, [r0,:128]!
    bx              lr
endfunc

function x264_sub16x16_dct8_neon
    push            {lr}
    bl              X(x264_sub8x8_dct8_neon)
    sub             r1,  r1,  #FENC_STRIDE*8 - 8
    sub             r2,  r2,  #FDEC_STRIDE*8 - 8
    bl              X(x264_sub8x8_dct8_neon)
    sub             r1,  r1,  #8
    sub             r2,  r2,  #8
    bl              X(x264_sub8x8_dct8_neon)
    pop             {lr}
    sub             r1,  r1,  #FENC_STRIDE*8 - 8
    sub             r2,  r2,  #FDEC_STRIDE*8 - 8
    b               X(x264_sub8x8_dct8_neon)
endfunc


// First part of IDCT (minus final SUMSUB_BA)
.macro IDCT_1D d4 d5 d6 d7 d0 d1 d2 d3
    SUMSUB_AB       \d4, \d5, \d0, \d2
    vshr.s16        \d7, \d1, #1
    vshr.s16        \d6, \d3, #1
    vsub.s16        \d7, \d7, \d3
    vadd.s16        \d6, \d6, \d1
.endm

function x264_add4x4_idct_neon
    mov             r2, #FDEC_STRIDE
    vld1.64         {d0-d3}, [r1,:128]

    IDCT_1D         d4, d5, d6, d7, d0, d1, d2, d3
    vld1.32         {d30[0]}, [r0,:32], r2
    SUMSUB_AB       q0, q1, q2, q3

    TRANSPOSE4x4_16 d0, d1, d3, d2

    IDCT_1D         d4, d5, d6, d7, d0, d1, d3, d2
    vld1.32         {d30[1]}, [r0,:32], r2
    SUMSUB_AB       q0, q1, q2, q3

    vrshr.s16       q0, q0, #6
    vld1.32         {d31[1]}, [r0,:32], r2
    vrshr.s16       q1, q1, #6
    vld1.32         {d31[0]}, [r0,:32], r2

    sub             r0, r0, r2, lsl #2
    vaddw.u8        q0, q0, d30
    vaddw.u8        q1, q1, d31
    vqmovun.s16     d0, q0
    vqmovun.s16     d2, q1

    vst1.32         {d0[0]}, [r0,:32], r2
    vst1.32         {d0[1]}, [r0,:32], r2
    vst1.32         {d2[1]}, [r0,:32], r2
    vst1.32         {d2[0]}, [r0,:32], r2
    bx              lr
endfunc

function x264_add8x4_idct_neon, export=0
    vld1.64         {d0-d3}, [r1,:128]!
    IDCT_1D         d16, d18, d20, d22, d0, d1, d2, d3
    vld1.64         {d4-d7}, [r1,:128]!
    IDCT_1D         d17, d19, d21, d23, d4, d5, d6, d7
    SUMSUB_AB       q0,  q3,  q8,  q10
    SUMSUB_AB       q1,  q2,  q9,  q11

    TRANSPOSE4x4_16 q0,  q1,  q2,  q3

    IDCT_1D         q8,  q9,  q10, q11, q0, q1, q2, q3
    SUMSUB_AB       q0,  q3,  q8,  q10
    SUMSUB_AB       q1,  q2,  q9,  q11

    vrshr.s16       q0,  q0,  #6
    vld1.32         {d28}, [r0,:64], r2
    vrshr.s16       q1,  q1,  #6
    vld1.32         {d29}, [r0,:64], r2
    vrshr.s16       q2,  q2,  #6
    vld1.32         {d30}, [r0,:64], r2
    vrshr.s16       q3,  q3,  #6
    vld1.32         {d31}, [r0,:64], r2

    sub             r0,  r0,  r2,  lsl #2
    vaddw.u8        q0,  q0,  d28
    vaddw.u8        q1,  q1,  d29
    vaddw.u8        q2,  q2,  d30
    vaddw.u8        q3,  q3,  d31

    vqmovun.s16     d0,  q0
    vqmovun.s16     d1,  q1
    vst1.32         {d0}, [r0,:64], r2
    vqmovun.s16     d2,  q2
    vst1.32         {d1}, [r0,:64], r2
    vqmovun.s16     d3,  q3
    vst1.32         {d2}, [r0,:64], r2
    vst1.32         {d3}, [r0,:64], r2
    bx              lr
endfunc

function x264_add8x8_idct_neon
    mov             r2, #FDEC_STRIDE
    mov             ip, lr
    bl              x264_add8x4_idct_neon
    mov             lr, ip
    b               x264_add8x4_idct_neon
endfunc

function x264_add16x16_idct_neon
    mov             r2, #FDEC_STRIDE
    mov             ip, lr
    bl              x264_add8x4_idct_neon
    bl              x264_add8x4_idct_neon
    sub             r0, r0, #8*FDEC_STRIDE-8
    bl              x264_add8x4_idct_neon
    bl              x264_add8x4_idct_neon
    sub             r0, r0, #8
    bl              x264_add8x4_idct_neon
    bl              x264_add8x4_idct_neon
    sub             r0, r0, #8*FDEC_STRIDE-8
    bl              x264_add8x4_idct_neon
    mov             lr, ip
    b               x264_add8x4_idct_neon
endfunc


.macro IDCT8_1D type
.ifc \type, col
    vswp            d21, d28
.endif
    SUMSUB_AB       q0,  q1,  q8,  q12              // a0/a2
.ifc \type, row
    vld1.64         {d28-d31}, [r1,:128]!
.else
    vswp            d19, d26
.endif
    SUMSUB_SHR   1, q2,  q3,  q10, q14,  q8, q12    // a6/a4
.ifc \type, col
    vswp            d23, d30
.endif
    SUMSUB_AB       q8,  q10, q13, q11
    SUMSUB_15       q8,  q10, q9,  q15,  q12, q14   // a7/a1
    SUMSUB_AB       q14, q15, q15, q9
    SUMSUB_15       q15, q14, q13, q11,  q12, q9    // a5/a3

    SUMSUB_SHR   2, q13, q14, q14, q15,  q11, q9    // b3/b5
    SUMSUB_SHR2  2, q12, q15, q8,  q10,  q11, q9    // b1/b7

    SUMSUB_AB       q10, q2,  q0,  q2               // b0/b6
    SUMSUB_AB       q11, q3,  q1,  q3               // b2/b4

    SUMSUB_AB       q8,  q15, q10, q15
    SUMSUB_AB       q9,  q14, q11, q14
    SUMSUB_AB       q10, q13, q3,  q13
.ifc \type, row
    vtrn.16         q8,  q9
.endif
    SUMSUB_AB       q11, q12, q2,  q12
.endm

function x264_add8x8_idct8_neon
    mov             r2,  #FDEC_STRIDE
    vld1.64         {d16-d19}, [r1,:128]!
    vld1.64         {d20-d23}, [r1,:128]!
    vld1.64         {d24-d27}, [r1,:128]!

    IDCT8_1D row
    vtrn.16         q10, q11
    vtrn.16         q12, q13
    vtrn.16         q14, q15
    vtrn.32         q8,  q10
    vtrn.32         q9,  q11
    vtrn.32         q12, q14
    vtrn.32         q13, q15
    vswp            d17, d24
    IDCT8_1D col

    vld1.64         {d0}, [r0,:64], r2
    vrshr.s16       q8,  q8,  #6
    vld1.64         {d1}, [r0,:64], r2
    vrshr.s16       q9,  q9,  #6
    vld1.64         {d2}, [r0,:64], r2
    vrshr.s16       q10, q10, #6
    vld1.64         {d3}, [r0,:64], r2
    vrshr.s16       q11, q11, #6
    vld1.64         {d4}, [r0,:64], r2
    vrshr.s16       q12, q12, #6
    vld1.64         {d5}, [r0,:64], r2
    vrshr.s16       q13, q13, #6
    vld1.64         {d6}, [r0,:64], r2
    vrshr.s16       q14, q14, #6
    vld1.64         {d7}, [r0,:64], r2
    vrshr.s16       q15, q15, #6
    sub             r0,  r0,  r2,  lsl #3

    vaddw.u8        q8,  q8,  d0
    vaddw.u8        q9,  q9,  d1
    vaddw.u8        q10, q10, d2
    vqmovun.s16     d0,  q8
    vqmovun.s16     d1,  q9
    vqmovun.s16     d2,  q10
    vaddw.u8        q11, q11, d3
    vst1.64         {d0}, [r0,:64], r2
    vaddw.u8        q12, q12, d4
    vst1.64         {d1}, [r0,:64], r2
    vaddw.u8        q13, q13, d5
    vst1.64         {d2}, [r0,:64], r2
    vqmovun.s16     d3,  q11
    vqmovun.s16     d4,  q12
    vaddw.u8        q14, q14, d6
    vaddw.u8        q15, q15, d7
    vst1.64         {d3}, [r0,:64], r2
    vqmovun.s16     d5,  q13
    vst1.64         {d4}, [r0,:64], r2
    vqmovun.s16     d6,  q14
    vqmovun.s16     d7,  q15
    vst1.64         {d5}, [r0,:64], r2
    vst1.64         {d6}, [r0,:64], r2
    vst1.64         {d7}, [r0,:64], r2
    bx              lr
endfunc

function x264_add16x16_idct8_neon
    mov             ip,  lr
    bl              X(x264_add8x8_idct8_neon)
    sub             r0,  r0,  #8*FDEC_STRIDE-8
    bl              X(x264_add8x8_idct8_neon)
    sub             r0,  r0,  #8
    bl              X(x264_add8x8_idct8_neon)
    sub             r0,  r0,  #8*FDEC_STRIDE-8
    mov             lr,  ip
    b               X(x264_add8x8_idct8_neon)
endfunc


function x264_add8x8_idct_dc_neon
    mov             r2,  #FDEC_STRIDE
    vld1.64         {d16}, [r1,:64]
    vrshr.s16       d16, d16, #6
    vld1.64         {d0}, [r0,:64], r2
    vmov.i16        q15, #0
    vld1.64         {d1}, [r0,:64], r2
    vld1.64         {d2}, [r0,:64], r2
    vdup.16         d20, d16[0]
    vld1.64         {d3}, [r0,:64], r2
    vdup.16         d21, d16[1]
    vld1.64         {d4}, [r0,:64], r2
    vdup.16         d22, d16[2]
    vld1.64         {d5}, [r0,:64], r2
    vdup.16         d23, d16[3]
    vld1.64         {d6}, [r0,:64], r2
    vsub.s16        q12, q15, q10
    vld1.64         {d7}, [r0,:64], r2
    vsub.s16        q13, q15, q11

    sub             r0,  r0,  #8*FDEC_STRIDE

    vqmovun.s16     d20, q10
    vqmovun.s16     d22, q11
    vqmovun.s16     d24, q12
    vqmovun.s16     d26, q13

    vmov            d21, d20
    vqadd.u8        q0,  q0,  q10
    vmov            d23, d22
    vqadd.u8        q1,  q1,  q10
    vmov            d25, d24
    vqadd.u8        q2,  q2,  q11
    vmov            d27, d26
    vqadd.u8        q3,  q3,  q11
    vqsub.u8        q0,  q0,  q12
    vqsub.u8        q1,  q1,  q12
    vqsub.u8        q2,  q2,  q13

    vst1.64         {d0}, [r0,:64], r2
    vqsub.u8        q3,  q3,  q13
    vst1.64         {d1}, [r0,:64], r2
    vst1.64         {d2}, [r0,:64], r2
    vst1.64         {d3}, [r0,:64], r2
    vst1.64         {d4}, [r0,:64], r2
    vst1.64         {d5}, [r0,:64], r2
    vst1.64         {d6}, [r0,:64], r2
    vst1.64         {d7}, [r0,:64], r2
    bx              lr
endfunc

.macro ADD16x4_IDCT_DC dc
    vld1.64         {d16-d17}, [r0,:128], r3
    vld1.64         {d18-d19}, [r0,:128], r3
    vdup.16         d4,  \dc[0]
    vdup.16         d5,  \dc[1]
    vld1.64         {d20-d21}, [r0,:128], r3
    vdup.16         d6,  \dc[2]
    vdup.16         d7,  \dc[3]
    vld1.64         {d22-d23}, [r0,:128], r3
    vsub.s16        q12, q15, q2
    vsub.s16        q13, q15, q3

    vqmovun.s16     d4,  q2
    vqmovun.s16     d5,  q3
    vqmovun.s16     d6,  q12
    vqmovun.s16     d7,  q13

    vqadd.u8        q8,  q8,  q2
    vqadd.u8        q9,  q9,  q2
    vqadd.u8        q10, q10, q2
    vqadd.u8        q11, q11, q2

    vqsub.u8        q8,  q8,  q3
    vqsub.u8        q9,  q9,  q3
    vqsub.u8        q10, q10, q3
    vst1.64         {d16-d17}, [r2,:128], r3
    vqsub.u8        q11, q11, q3
    vst1.64         {d18-d19}, [r2,:128], r3
    vst1.64         {d20-d21}, [r2,:128], r3
    vst1.64         {d22-d23}, [r2,:128], r3
.endm

function x264_add16x16_idct_dc_neon
    mov             r2,  r0
    mov             r3,  #FDEC_STRIDE
    vmov.i16        q15, #0

    vld1.64         {d0-d3}, [r1,:64]
    vrshr.s16       q0, #6
    vrshr.s16       q1, #6

    ADD16x4_IDCT_DC d0
    ADD16x4_IDCT_DC d1
    ADD16x4_IDCT_DC d2
    ADD16x4_IDCT_DC d3
    bx              lr
endfunc

function x264_sub8x8_dct_dc_neon
    mov             r3,  #FENC_STRIDE
    mov             ip,  #FDEC_STRIDE
    vld1.64         {d16}, [r1,:64], r3
    vld1.64         {d17}, [r2,:64], ip
    vsubl.u8        q8,  d16, d17
    vld1.64         {d18}, [r1,:64], r3
    vld1.64         {d19}, [r2,:64], ip
    vsubl.u8        q9,  d18, d19
    vld1.64         {d20}, [r1,:64], r3
    vld1.64         {d21}, [r2,:64], ip
    vsubl.u8        q10, d20, d21
    vld1.64         {d22}, [r1,:64], r3
    vadd.s16        q0,  q8,  q9
    vld1.64         {d23}, [r2,:64], ip
    vsubl.u8        q11, d22, d23
    vld1.64         {d24}, [r1,:64], r3
    vadd.s16        q0,  q0,  q10
    vld1.64         {d25}, [r2,:64], ip
    vsubl.u8        q12, d24, d25
    vld1.64         {d26}, [r1,:64], r3
    vadd.s16        q0,  q0,  q11
    vld1.64         {d27}, [r2,:64], ip
    vsubl.u8        q13, d26, d27
    vld1.64         {d28}, [r1,:64], r3
    vld1.64         {d29}, [r2,:64], ip
    vsubl.u8        q14, d28, d29
    vld1.64         {d30}, [r1,:64], r3
    vadd.s16        q1,  q12, q13
    vld1.64         {d31}, [r2,:64], ip
    vsubl.u8        q15, d30, d31
    vadd.s16        q1,  q1,  q14

    vadd.s16        d4,  d0,  d1
    vadd.s16        q1,  q1,  q15
    vsub.s16        d5,  d0,  d1
    vadd.s16        d6,  d2,  d3
    vsub.s16        d7,  d2,  d3
    vadd.s16        q0,  q2,  q3
    vsub.s16        q1,  q2,  q3

    vpadd.s16       d0,  d0,  d2
    vpadd.s16       d1,  d1,  d3
    vpadd.s16       d0,  d0,  d1
    vst1.64         {d0}, [r0,:64]
    bx              lr
endfunc

function x264_sub8x16_dct_dc_neon
    mov             r3,  #FENC_STRIDE
    mov             ip,  #FDEC_STRIDE
    vld1.64         {d16}, [r1,:64], r3
    vld1.64         {d17}, [r2,:64], ip
    vsubl.u8        q8,  d16, d17
    vld1.64         {d18}, [r1,:64], r3
    vld1.64         {d19}, [r2,:64], ip
    vsubl.u8        q9,  d18, d19
    vld1.64         {d20}, [r1,:64], r3
    vld1.64         {d21}, [r2,:64], ip
    vsubl.u8        q10, d20, d21
    vld1.64         {d22}, [r1,:64], r3
    vadd.s16        q0,  q8,  q9
    vld1.64         {d23}, [r2,:64], ip
    vsubl.u8        q11, d22, d23
    vld1.64         {d24}, [r1,:64], r3
    vadd.s16        q0,  q0,  q10
    vld1.64         {d25}, [r2,:64], ip
    vsubl.u8        q12, d24, d25
    vld1.64         {d26}, [r1,:64], r3
    vadd.s16        q0,  q0,  q11
    vld1.64         {d27}, [r2,:64], ip
    vsubl.u8        q13, d26, d27
    vld1.64         {d28}, [r1,:64], r3
    vld1.64         {d29}, [r2,:64], ip
    vsubl.u8        q14, d28, d29
    vld1.64         {d30}, [r1,:64], r3
    vadd.s16        q1,  q12, q13
    vld1.64         {d31}, [r2,:64], ip
    vsubl.u8        q15, d30, d31

    vld1.64         {d16}, [r1,:64], r3
    vadd.s16        q1,  q1,  q14
    vld1.64         {d17}, [r2,:64], ip
    vadd.s16        q1,  q1,  q15
    vld1.64         {d18}, [r1,:64], r3
    vsubl.u8        q8,  d16, d17
    vld1.64         {d19}, [r2,:64], ip
    vsubl.u8        q9,  d18, d19
    vld1.64         {d20}, [r1,:64], r3
    vld1.64         {d21}, [r2,:64], ip
    vsubl.u8        q10, d20, d21
    vld1.64         {d22}, [r1,:64], r3
    vadd.s16        q2,  q8,  q9
    vld1.64         {d23}, [r2,:64], ip
    vsubl.u8        q11, d22, d23
    vld1.64         {d24}, [r1,:64], r3
    vadd.s16        q2,  q2,  q10
    vld1.64         {d25}, [r2,:64], ip
    vsubl.u8        q12, d24, d25
    vld1.64         {d26}, [r1,:64], r3
    vadd.s16        q2,  q2,  q11
    vld1.64         {d27}, [r2,:64], ip
    vsubl.u8        q13, d26, d27
    vld1.64         {d28}, [r1,:64], r3
    vld1.64         {d29}, [r2,:64], ip
    vsubl.u8        q14, d28, d29
    vld1.64         {d30}, [r1,:64], r3
    vadd.s16        q3,  q12, q13
    vld1.64         {d31}, [r2,:64], ip
    vsubl.u8        q15, d30, d31
    vadd.s16        q3,  q3,  q14

    vadd.s16        d16, d0,  d1  @ b0
    vadd.s16        q3,  q3,  q15
    vsub.s16        d17, d0,  d1  @ b4
    vadd.s16        d18, d2,  d3  @ b1
    vsub.s16        d19, d2,  d3  @ b5
    vadd.s16        d20, d4,  d5  @ b2
    vsub.s16        d21, d4,  d5  @ b6
    vadd.s16        d22, d6,  d7  @ b3
    vsub.s16        d23, d6,  d7  @ b7
    vadd.s16        q0,  q8,  q9  @ b0 + b1, b4 + b5; a0, a2
    vsub.s16        q1,  q8,  q9  @ b0 - b1, b4 - b5; a4, a6
    vadd.s16        q2,  q10, q11 @ b2 + b3, b6 + b7; a1, a3
    vsub.s16        q3,  q10, q11 @ b2 - b3, b6 - b7; a5, a7

    vadd.s16        q8,  q0,  q2  @ a0 + a1, a2 + a3
    vsub.s16        q9,  q0,  q2  @ a0 - a1, a2 - a3
    vsub.s16        q10, q1,  q3  @ a4 - a5, a6 - a7
    vadd.s16        q11, q1,  q3  @ a4 + a5, a6 + a7

    vpadd.s16       d0,  d16, d17
    vpadd.s16       d1,  d18, d19
    vpadd.s16       d2,  d20, d21
    vpadd.s16       d3,  d22, d23
    vpadd.s16       d0,  d0,  d1
    vpadd.s16       d1,  d2,  d3
    vst1.64         {q0}, [r0,:64]
    bx              lr
endfunc


function x264_zigzag_scan_4x4_frame_neon
    movrel      r2, scan4x4_frame
    vld1.64     {d0-d3},   [r1,:128]
    vld1.64     {d16-d19}, [r2,:128]
    vtbl.8      d4, {d0-d1}, d16
    vtbl.8      d5, {d1-d3}, d17
    vtbl.8      d6, {d0-d2}, d18
    vtbl.8      d7, {d2-d3}, d19
    vst1.64     {d4-d7},   [r0,:128]
    bx          lr
endfunc



#elif defined(__arm64__)

const scan4x4_frame, align=4
.byte    0,1,   8,9,   2,3,   4,5
.byte   10,11, 16,17, 24,25, 18,19
.byte   12,13,  6,7,  14,15, 20,21
.byte   26,27, 28,29, 22,23, 30,31
endconst

const scan4x4_field, align=4
.byte    0,1,   2,3,   8,9,   4,5
.byte    6,7,  10,11, 12,13, 14,15
endconst

const sub4x4_frame, align=4
.byte    0,  1,  4,  8
.byte    5,  2,  3,  6
.byte    9, 12, 13, 10
.byte    7, 11, 14, 15
endconst

const sub4x4_field, align=4
.byte    0,  4,  1,  8
.byte   12,  5,  9, 13
.byte    2,  6, 10, 14
.byte    3,  7, 11, 15
endconst

// sum = a + (b>>shift)   sub = (a>>shift) - b
.macro SUMSUB_SHR shift sum sub a b t0 t1
    sshr        \t0,  \b, #\shift
    sshr        \t1,  \a, #\shift
    add         \sum, \a, \t0
    sub         \sub, \t1, \b
.endm

// sum = (a>>shift) + b   sub = a - (b>>shift)
.macro SUMSUB_SHR2 shift sum sub a b t0 t1
    sshr        \t0,  \a, #\shift
    sshr        \t1,  \b, #\shift
    add         \sum, \t0, \b
    sub         \sub, \a, \t1
.endm

// a += 1.5*ma   b -= 1.5*mb
.macro SUMSUB_15 a b ma mb t0 t1
    sshr        \t0, \ma, #1
    sshr        \t1, \mb, #1
    add         \t0, \t0, \ma
    add         \t1, \t1, \mb
    add         \a,  \a,  \t0
    sub         \b,  \b,  \t1
.endm


function x264_dct4x4dc_neon, export=1
    ld1        {v0.4h,v1.4h,v2.4h,v3.4h}, [x0]
    movi        v31.4h, #1
    SUMSUB_AB   v4.4h,  v5.4h,  v0.4h,  v1.4h
    SUMSUB_AB   v6.4h,  v7.4h,  v2.4h,  v3.4h
    SUMSUB_AB   v0.4h,  v2.4h,  v4.4h,  v6.4h
    SUMSUB_AB   v3.4h,  v1.4h,  v5.4h,  v7.4h
    transpose   v4.4h,  v6.4h,  v0.4h,  v2.4h
    transpose   v5.4h,  v7.4h,  v1.4h,  v3.4h
    SUMSUB_AB   v0.4h,  v2.4h,  v4.4h,  v6.4h
    SUMSUB_AB   v1.4h,  v3.4h,  v5.4h,  v7.4h
    transpose   v4.2s,  v5.2s,  v0.2s,  v1.2s
    transpose   v6.2s,  v7.2s,  v2.2s,  v3.2s
    add         v16.4h, v4.4h,  v31.4h
    add         v17.4h, v6.4h,  v31.4h
    srhadd      v0.4h,  v4.4h,  v5.4h
    shsub       v1.4h,  v16.4h, v5.4h
    shsub       v2.4h,  v17.4h, v7.4h
    srhadd      v3.4h,  v6.4h,  v7.4h
    st1        {v0.4h,v1.4h,v2.4h,v3.4h}, [x0]
    ret
endfunc

function x264_idct4x4dc_neon, export=1
    ld1        {v0.4h,v1.4h,v2.4h,v3.4h}, [x0]
    SUMSUB_AB   v4.4h,  v5.4h,  v0.4h,  v1.4h
    SUMSUB_AB   v6.4h,  v7.4h,  v2.4h,  v3.4h
    SUMSUB_AB   v0.4h,  v2.4h,  v4.4h,  v6.4h
    SUMSUB_AB   v3.4h,  v1.4h,  v5.4h,  v7.4h
    transpose   v4.4h,  v6.4h,  v0.4h,  v2.4h
    transpose   v5.4h,  v7.4h,  v1.4h,  v3.4h
    SUMSUB_AB   v0.4h,  v2.4h,  v4.4h,  v6.4h
    SUMSUB_AB   v1.4h,  v3.4h,  v5.4h,  v7.4h
    transpose   v4.2s,  v5.2s,  v0.2s,  v1.2s
    transpose   v6.2s,  v7.2s,  v2.2s,  v3.2s
    SUMSUB_AB   v0.4h,  v1.4h,  v4.4h,  v5.4h
    SUMSUB_AB   v3.4h,  v2.4h,  v6.4h,  v7.4h
    st1        {v0.4h,v1.4h,v2.4h,v3.4h}, [x0]
    ret
endfunc

.macro DCT_1D v0 v1 v2 v3 v4 v5 v6 v7
    SUMSUB_AB   \v1, \v6, \v5, \v6
    SUMSUB_AB   \v3, \v7, \v4, \v7
    add         \v0, \v3, \v1
    add         \v4, \v7, \v7
    add         \v5, \v6, \v6
    sub         \v2, \v3, \v1
    add         \v1, \v4, \v6
    sub         \v3, \v7, \v5
.endm

function x264_sub4x4_dct_neon, export=1
    mov         x3, #FENC_STRIDE
    mov         x4, #FDEC_STRIDE
    ld1        {v0.s}[0], [x1], x3
    ld1        {v1.s}[0], [x2], x4
    ld1        {v2.s}[0], [x1], x3
    usubl       v16.8h, v0.8b,  v1.8b
    ld1        {v3.s}[0], [x2], x4
    ld1        {v4.s}[0], [x1], x3
    usubl       v17.8h, v2.8b,  v3.8b
    ld1        {v5.s}[0], [x2], x4
    ld1        {v6.s}[0], [x1], x3
    usubl       v18.8h, v4.8b,  v5.8b
    ld1        {v7.s}[0], [x2], x4
    usubl       v19.8h, v6.8b,  v7.8b

    DCT_1D      v0.4h, v1.4h, v2.4h, v3.4h, v16.4h, v17.4h, v18.4h, v19.4h
    transpose4x4.h v0, v1, v2, v3, v4, v5, v6, v7
    DCT_1D      v4.4h, v5.4h, v6.4h, v7.4h, v0.4h, v1.4h, v2.4h, v3.4h
    st1        {v4.4h,v5.4h,v6.4h,v7.4h}, [x0]
    ret
endfunc

function x264_sub8x4_dct_neon
    ld1        {v0.8b}, [x1], x3
    ld1        {v1.8b}, [x2], x4
    usubl       v16.8h, v0.8b,  v1.8b
    ld1        {v2.8b}, [x1], x3
    ld1        {v3.8b}, [x2], x4
    usubl       v17.8h, v2.8b,  v3.8b
    ld1        {v4.8b}, [x1], x3
    ld1        {v5.8b}, [x2], x4
    usubl       v18.8h, v4.8b,  v5.8b
    ld1        {v6.8b}, [x1], x3
    ld1        {v7.8b}, [x2], x4
    usubl       v19.8h, v6.8b,  v7.8b

    DCT_1D      v0.8h, v1.8h, v2.8h, v3.8h, v16.8h, v17.8h, v18.8h, v19.8h
    transpose4x8.h  v0, v1, v2, v3, v4, v5, v6, v7

    SUMSUB_AB   v16.8h, v19.8h, v0.8h,  v3.8h
    SUMSUB_AB   v17.8h, v18.8h, v1.8h,  v2.8h
    add         v22.8h, v19.8h, v19.8h
    add         v21.8h, v18.8h, v18.8h
    add         v0.8h,  v16.8h, v17.8h
    sub         v1.8h,  v16.8h, v17.8h

    add         v2.8h,  v22.8h, v18.8h
    sub         v3.8h,  v19.8h, v21.8h

    zip1        v4.2d,  v0.2d,  v2.2d
    zip2        v6.2d,  v0.2d,  v2.2d
    zip1        v5.2d,  v1.2d,  v3.2d
    zip2        v7.2d,  v1.2d,  v3.2d

    st1        {v4.8h}, [x0], #16
    st1        {v5.8h}, [x0], #16
    st1        {v6.8h}, [x0], #16
    st1        {v7.8h}, [x0], #16
    ret
endfunc

function x264_sub8x8_dct_neon, export=1
    mov         x5,  x30
    mov         x3, #FENC_STRIDE
    mov         x4, #FDEC_STRIDE
    bl          x264_sub8x4_dct_neon
    mov         x30, x5
    b           x264_sub8x4_dct_neon
endfunc

function x264_sub16x16_dct_neon, export=1
    mov         x5,  x30
    mov         x3, #FENC_STRIDE
    mov         x4, #FDEC_STRIDE
    bl          x264_sub8x4_dct_neon
    bl          x264_sub8x4_dct_neon
    sub         x1, x1, #8*FENC_STRIDE-8
    sub         x2, x2, #8*FDEC_STRIDE-8
    bl          x264_sub8x4_dct_neon
    bl          x264_sub8x4_dct_neon
    sub         x1, x1, #8
    sub         x2, x2, #8
    bl          x264_sub8x4_dct_neon
    bl          x264_sub8x4_dct_neon
    sub         x1, x1, #8*FENC_STRIDE-8
    sub         x2, x2, #8*FDEC_STRIDE-8
    bl          x264_sub8x4_dct_neon
    mov         x30, x5
    b           x264_sub8x4_dct_neon
endfunc


.macro DCT8_1D type
    SUMSUB_AB   v18.8h, v17.8h, v3.8h,  v4.8h   // s34/d34
    SUMSUB_AB   v19.8h, v16.8h, v2.8h,  v5.8h   // s25/d25
    SUMSUB_AB   v22.8h, v21.8h, v1.8h,  v6.8h   // s16/d16
    SUMSUB_AB   v23.8h, v20.8h, v0.8h,  v7.8h   // s07/d07

    SUMSUB_AB   v24.8h, v26.8h,  v23.8h, v18.8h  // a0/a2
    SUMSUB_AB   v25.8h, v27.8h,  v22.8h, v19.8h  // a1/a3

    SUMSUB_AB   v30.8h, v29.8h,  v20.8h, v17.8h  // a6/a5
    sshr        v23.8h, v21.8h, #1
    sshr        v18.8h, v16.8h, #1
    add         v23.8h, v23.8h, v21.8h
    add         v18.8h, v18.8h, v16.8h
    sub         v30.8h, v30.8h, v23.8h
    sub         v29.8h, v29.8h, v18.8h

    SUMSUB_AB   v28.8h, v31.8h,  v21.8h, v16.8h   // a4/a7
    sshr        v22.8h, v20.8h, #1
    sshr        v19.8h, v17.8h, #1
    add         v22.8h, v22.8h, v20.8h
    add         v19.8h, v19.8h, v17.8h
    add         v22.8h, v28.8h, v22.8h
    add         v31.8h, v31.8h, v19.8h

    SUMSUB_AB      v0.8h,  v4.8h,  v24.8h, v25.8h
    SUMSUB_SHR  2, v1.8h,  v7.8h,  v22.8h, v31.8h, v16.8h, v17.8h
    SUMSUB_SHR  1, v2.8h,  v6.8h,  v26.8h, v27.8h, v18.8h, v19.8h
    SUMSUB_SHR2 2, v3.8h,  v5.8h,  v30.8h, v29.8h, v20.8h, v21.8h
.endm

function x264_sub8x8_dct8_neon, export=1
    mov         x3, #FENC_STRIDE
    mov         x4, #FDEC_STRIDE
    ld1        {v16.8b}, [x1], x3
    ld1        {v17.8b}, [x2], x4
    ld1        {v18.8b}, [x1], x3
    ld1        {v19.8b}, [x2], x4
    usubl       v0.8h,  v16.8b, v17.8b
    ld1        {v20.8b}, [x1], x3
    ld1        {v21.8b}, [x2], x4
    usubl       v1.8h,  v18.8b, v19.8b
    ld1        {v22.8b}, [x1], x3
    ld1        {v23.8b}, [x2], x4
    usubl       v2.8h,  v20.8b, v21.8b
    ld1        {v24.8b}, [x1], x3
    ld1        {v25.8b}, [x2], x4
    usubl       v3.8h,  v22.8b, v23.8b
    ld1        {v26.8b}, [x1], x3
    ld1        {v27.8b}, [x2], x4
    usubl       v4.8h,  v24.8b, v25.8b
    ld1        {v28.8b}, [x1], x3
    ld1        {v29.8b}, [x2], x4
    usubl       v5.8h,  v26.8b, v27.8b
    ld1        {v30.8b}, [x1], x3
    ld1        {v31.8b}, [x2], x4
    usubl       v6.8h,  v28.8b, v29.8b
    usubl       v7.8h,  v30.8b, v31.8b

    DCT8_1D row
    transpose8x8.h v0, v1, v2, v3, v4, v5, v6, v7, v30, v31
    DCT8_1D col

    st1        {v0.8h,v1.8h,v2.8h,v3.8h}, [x0], #64
    st1        {v4.8h,v5.8h,v6.8h,v7.8h}, [x0], #64
    ret
endfunc

function x264_sub16x16_dct8_neon, export=1
    mov         x7,  x30
    bl          X(x264_sub8x8_dct8_neon)
    sub         x1,  x1,  #FENC_STRIDE*8 - 8
    sub         x2,  x2,  #FDEC_STRIDE*8 - 8
    bl          X(x264_sub8x8_dct8_neon)
    sub         x1,  x1,  #8
    sub         x2,  x2,  #8
    bl          X(x264_sub8x8_dct8_neon)
    mov         x30, x7
    sub         x1,  x1,  #FENC_STRIDE*8 - 8
    sub         x2,  x2,  #FDEC_STRIDE*8 - 8
    b           X(x264_sub8x8_dct8_neon)
endfunc


// First part of IDCT (minus final SUMSUB_BA)
.macro IDCT_1D d4 d5 d6 d7 d0 d1 d2 d3
    SUMSUB_AB   \d4, \d5, \d0, \d2
    sshr        \d7, \d1, #1
    sshr        \d6, \d3, #1
    sub         \d7, \d7, \d3
    add         \d6, \d6, \d1
.endm

function x264_add4x4_idct_neon, export=1
    mov         x2, #FDEC_STRIDE
    ld1        {v0.4h,v1.4h,v2.4h,v3.4h}, [x1]

    IDCT_1D     v4.4h, v5.4h, v6.4h, v7.4h, v0.4h, v1.4h, v2.4h, v3.4h
    ld1        {v28.s}[0], [x0], x2
    SUMSUB_AB   v0.4h, v2.4h, v4.4h, v6.4h
    SUMSUB_AB   v1.4h, v3.4h, v5.4h, v7.4h

    transpose4x4.h v0, v1, v3, v2, v16, v17, v18, v19

    IDCT_1D     v4.4h, v5.4h, v6.4h, v7.4h, v0.4h, v1.4h, v3.4h, v2.4h
    ld1        {v29.s}[0], [x0], x2
    SUMSUB_AB   v0.4h, v2.4h, v4.4h, v6.4h
    SUMSUB_AB   v1.4h, v3.4h, v5.4h, v7.4h

    srshr       v0.4h,  v0.4h,  #6
    srshr       v1.4h,  v1.4h,  #6
    ld1        {v31.s}[0], [x0], x2
    srshr       v2.4h,  v2.4h,  #6
    srshr       v3.4h,  v3.4h,  #6
    ld1        {v30.s}[0], [x0], x2

    sub         x0,  x0,  x2,  lsl #2
    uaddw       v0.8h,  v0.8h,  v28.8b
    uaddw       v1.8h,  v1.8h,  v29.8b
    uaddw       v2.8h,  v2.8h,  v30.8b
    uaddw       v3.8h,  v3.8h,  v31.8b
    sqxtun      v0.8b,  v0.8h
    sqxtun      v1.8b,  v1.8h
    sqxtun      v2.8b,  v2.8h
    sqxtun      v3.8b,  v3.8h

    st1        {v0.s}[0], [x0], x2
    st1        {v1.s}[0], [x0], x2
    st1        {v3.s}[0], [x0], x2
    st1        {v2.s}[0], [x0], x2
    ret
endfunc

function x264_add8x4_idct_neon, export=1
    ld1        {v0.8h,v1.8h}, [x1], #32
    ld1        {v2.8h,v3.8h}, [x1], #32
    transpose   v20.2d, v21.2d, v0.2d, v2.2d
    transpose   v22.2d, v23.2d, v1.2d, v3.2d
    IDCT_1D     v16.8h, v17.8h, v18.8h, v19.8h, v20.8h, v21.8h, v22.8h, v23.8h
    SUMSUB_AB   v0.8h,  v3.8h,  v16.8h, v18.8h
    SUMSUB_AB   v1.8h,  v2.8h,  v17.8h, v19.8h

    transpose4x8.h v0, v1, v2, v3, v4, v5, v6, v7

    IDCT_1D     v16.8h, v17.8h, v18.8h, v19.8h, v0.8h, v1.8h, v2.8h, v3.8h
    SUMSUB_AB   v0.8h,  v3.8h,  v16.8h, v18.8h
    SUMSUB_AB   v1.8h,  v2.8h,  v17.8h, v19.8h

    srshr       v0.8h,  v0.8h,  #6
    ld1        {v28.8b}, [x0], x2
    srshr       v1.8h,  v1.8h,  #6
    ld1        {v29.8b}, [x0], x2
    srshr       v2.8h,  v2.8h,  #6
    ld1        {v30.8b}, [x0], x2
    srshr       v3.8h,  v3.8h,  #6
    ld1        {v31.8b}, [x0], x2

    sub         x0,  x0,  x2,  lsl #2
    uaddw       v0.8h,  v0.8h,  v28.8b
    uaddw       v1.8h,  v1.8h,  v29.8b
    uaddw       v2.8h,  v2.8h,  v30.8b
    uaddw       v3.8h,  v3.8h,  v31.8b

    sqxtun      v0.8b,  v0.8h
    sqxtun      v1.8b,  v1.8h
    st1        {v0.8b}, [x0], x2
    sqxtun      v2.8b,  v2.8h
    st1        {v1.8b}, [x0], x2
    sqxtun      v3.8b,  v3.8h
    st1        {v2.8b}, [x0], x2
    st1        {v3.8b}, [x0], x2
    ret
endfunc

function x264_add8x8_idct_neon, export=1
    mov             x2, #FDEC_STRIDE
    mov             x5,  x30
    bl              X(x264_add8x4_idct_neon)
    mov             x30, x5
    b               X(x264_add8x4_idct_neon)
endfunc

function x264_add16x16_idct_neon, export=1
    mov             x2, #FDEC_STRIDE
    mov             x5,  x30
    bl              X(x264_add8x4_idct_neon)
    bl              X(x264_add8x4_idct_neon)
    sub             x0, x0, #8*FDEC_STRIDE-8
    bl              X(x264_add8x4_idct_neon)
    bl              X(x264_add8x4_idct_neon)
    sub             x0, x0, #8
    bl              X(x264_add8x4_idct_neon)
    bl              X(x264_add8x4_idct_neon)
    sub             x0, x0, #8*FDEC_STRIDE-8
    bl              X(x264_add8x4_idct_neon)
    mov             x30, x5
    b               X(x264_add8x4_idct_neon)
endfunc

.macro IDCT8_1D type
    SUMSUB_AB   v0.8h,  v1.8h,  v16.8h, v20.8h          // a0/a2
.ifc \type, row
    ld1        {v22.8h,v23.8h}, [x1], #32
.endif
    SUMSUB_SHR  1, v2.8h,  v3.8h,  v18.8h, v22.8h, v16.8h, v20.8h   // a6/a4
    SUMSUB_AB   v16.8h, v18.8h, v21.8h, v19.8h
    SUMSUB_15   v16.8h, v18.8h, v17.8h, v23.8h, v20.8h, v22.8h      // a7/a1
    SUMSUB_AB   v22.8h, v23.8h, v23.8h, v17.8h
    SUMSUB_15   v23.8h, v22.8h, v21.8h, v19.8h, v20.8h, v17.8h      // a5/a3

    SUMSUB_SHR  2, v21.8h, v22.8h, v22.8h, v23.8h, v19.8h, v17.8h   // b3/b5
    SUMSUB_SHR2 2, v20.8h, v23.8h, v16.8h, v18.8h, v19.8h, v17.8h   // b1/b7

    SUMSUB_AB   v18.8h, v2.8h,  v0.8h,  v2.8h           // b0/b6
    SUMSUB_AB   v19.8h, v3.8h,  v1.8h,  v3.8h           // b2/b4

    SUMSUB_AB   v16.8h, v23.8h, v18.8h, v23.8h
    SUMSUB_AB   v17.8h, v22.8h, v19.8h, v22.8h
    SUMSUB_AB   v18.8h, v21.8h, v3.8h,  v21.8h
    SUMSUB_AB   v19.8h, v20.8h, v2.8h,  v20.8h
.endm

function x264_add8x8_idct8_neon, export=1
    mov         x2,  #FDEC_STRIDE
    ld1        {v16.8h,v17.8h}, [x1], #32
    ld1        {v18.8h,v19.8h}, [x1], #32
    ld1        {v20.8h,v21.8h}, [x1], #32

    IDCT8_1D    row

    transpose8x8.h v16, v17, v18, v19, v20, v21, v22, v23, v30, v31

    IDCT8_1D    col

    ld1        {v0.8b}, [x0], x2
    srshr       v16.8h, v16.8h, #6
    ld1        {v1.8b}, [x0], x2
    srshr       v17.8h, v17.8h, #6
    ld1        {v2.8b}, [x0], x2
    srshr       v18.8h, v18.8h, #6
    ld1        {v3.8b}, [x0], x2
    srshr       v19.8h, v19.8h, #6
    ld1        {v4.8b}, [x0], x2
    srshr       v20.8h, v20.8h, #6
    ld1        {v5.8b}, [x0], x2
    srshr       v21.8h, v21.8h, #6
    ld1        {v6.8b}, [x0], x2
    srshr       v22.8h, v22.8h, #6
    ld1        {v7.8b}, [x0], x2
    srshr       v23.8h, v23.8h, #6
    sub         x0,  x0,  x2,  lsl #3

    uaddw       v16.8h, v16.8h, v0.8b
    uaddw       v17.8h, v17.8h, v1.8b
    uaddw       v18.8h, v18.8h, v2.8b
    sqxtun      v0.8b,  v16.8h
    sqxtun      v1.8b,  v17.8h
    sqxtun      v2.8b,  v18.8h
    uaddw       v19.8h, v19.8h, v3.8b
    st1        {v0.8b}, [x0], x2
    uaddw       v20.8h, v20.8h, v4.8b
    st1        {v1.8b}, [x0], x2
    uaddw       v21.8h, v21.8h, v5.8b
    st1        {v2.8b}, [x0], x2
    sqxtun      v3.8b,  v19.8h
    sqxtun      v4.8b,  v20.8h
    uaddw       v22.8h, v22.8h, v6.8b
    uaddw       v23.8h, v23.8h, v7.8b
    st1        {v3.8b}, [x0], x2
    sqxtun      v5.8b,  v21.8h
    st1        {v4.8b}, [x0], x2
    sqxtun      v6.8b,  v22.8h
    sqxtun      v7.8b,  v23.8h
    st1        {v5.8b}, [x0], x2
    st1        {v6.8b}, [x0], x2
    st1        {v7.8b}, [x0], x2
    ret
endfunc

function x264_add16x16_idct8_neon, export=1
    mov             x7,  x30
    bl              X(x264_add8x8_idct8_neon)
    sub             x0,  x0,  #8*FDEC_STRIDE-8
    bl              X(x264_add8x8_idct8_neon)
    sub             x0,  x0,  #8
    bl              X(x264_add8x8_idct8_neon)
    sub             x0,  x0,  #8*FDEC_STRIDE-8
    mov             x30, x7
    b               X(x264_add8x8_idct8_neon)
endfunc

function x264_add8x8_idct_dc_neon, export=1
    mov         x2,  #FDEC_STRIDE
    ld1        {v16.4h}, [x1]
    ld1        {v0.8b}, [x0], x2
    srshr       v16.4h, v16.4h, #6
    ld1        {v1.8b}, [x0], x2
    dup         v20.8h, v16.h[0]
    dup         v21.8h, v16.h[1]
    ld1        {v2.8b}, [x0], x2
    dup         v22.8h, v16.h[2]
    dup         v23.8h, v16.h[3]
    ld1        {v3.8b}, [x0], x2
    trn1        v20.2d, v20.2d,  v21.2d
    ld1        {v4.8b}, [x0], x2
    trn1        v21.2d, v22.2d,  v23.2d
    ld1        {v5.8b}, [x0], x2
    neg         v22.8h, v20.8h
    ld1        {v6.8b}, [x0], x2
    neg         v23.8h, v21.8h
    ld1        {v7.8b}, [x0], x2

    sub         x0,  x0,  #8*FDEC_STRIDE

    sqxtun      v20.8b,  v20.8h
    sqxtun      v21.8b,  v21.8h
    sqxtun      v22.8b,  v22.8h
    sqxtun      v23.8b,  v23.8h

    uqadd       v0.8b,  v0.8b,  v20.8b
    uqadd       v1.8b,  v1.8b,  v20.8b
    uqadd       v2.8b,  v2.8b,  v20.8b
    uqadd       v3.8b,  v3.8b,  v20.8b
    uqadd       v4.8b,  v4.8b,  v21.8b
    uqadd       v5.8b,  v5.8b,  v21.8b
    uqadd       v6.8b,  v6.8b,  v21.8b
    uqadd       v7.8b,  v7.8b,  v21.8b
    uqsub       v0.8b,  v0.8b,  v22.8b
    uqsub       v1.8b,  v1.8b,  v22.8b
    uqsub       v2.8b,  v2.8b,  v22.8b
    uqsub       v3.8b,  v3.8b,  v22.8b
    uqsub       v4.8b,  v4.8b,  v23.8b
    uqsub       v5.8b,  v5.8b,  v23.8b
    uqsub       v6.8b,  v6.8b,  v23.8b
    uqsub       v7.8b,  v7.8b,  v23.8b

    st1        {v0.8b}, [x0], x2
    st1        {v1.8b}, [x0], x2
    st1        {v2.8b}, [x0], x2
    st1        {v3.8b}, [x0], x2
    st1        {v4.8b}, [x0], x2
    st1        {v5.8b}, [x0], x2
    st1        {v6.8b}, [x0], x2
    st1        {v7.8b}, [x0], x2
    ret
endfunc

.macro ADD16x4_IDCT_DC dc
    ld1         {v4.16b}, [x0], x3
    dup         v24.8h,  \dc[0]
    dup         v25.8h,  \dc[1]
    ld1         {v5.16b}, [x0], x3
    dup         v26.8h,  \dc[2]
    dup         v27.8h,  \dc[3]
    ld1         {v6.16b}, [x0], x3
    trn1        v24.2d,  v24.2d,  v25.2d
    ld1         {v7.16b}, [x0], x3
    trn1        v25.2d,  v26.2d,  v27.2d
    neg         v26.8h,  v24.8h
    neg         v27.8h,  v25.8h

    sqxtun      v20.8b,  v24.8h
    sqxtun      v21.8b,  v26.8h
    sqxtun2     v20.16b, v25.8h
    sqxtun2     v21.16b, v27.8h

    uqadd        v4.16b, v4.16b, v20.16b
    uqadd        v5.16b, v5.16b, v20.16b
    uqadd        v6.16b, v6.16b, v20.16b
    uqadd        v7.16b, v7.16b, v20.16b

    uqsub        v4.16b, v4.16b, v21.16b
    uqsub        v5.16b, v5.16b, v21.16b
    uqsub        v6.16b, v6.16b, v21.16b
    st1         {v4.16b}, [x2], x3
    uqsub        v7.16b, v7.16b, v21.16b
    st1         {v5.16b}, [x2], x3
    st1         {v6.16b}, [x2], x3
    st1         {v7.16b}, [x2], x3
.endm

function x264_add16x16_idct_dc_neon, export=1
    mov         x2,  x0
    mov         x3,  #FDEC_STRIDE

    ld1        {v0.4h,v1.4h,v2.4h,v3.4h}, [x1]
    srshr       v0.4h,  v0.4h,  #6
    srshr       v1.4h,  v1.4h,  #6

    ADD16x4_IDCT_DC v0.h
    srshr       v2.4h,  v2.4h,  #6
    ADD16x4_IDCT_DC v1.h
    srshr       v3.4h,  v3.4h,  #6
    ADD16x4_IDCT_DC v2.h
    ADD16x4_IDCT_DC v3.h
    ret
endfunc

.macro sub4x4x2_dct_dc, dst, t0, t1, t2, t3, t4, t5, t6, t7
    ld1        {\t0\().8b}, [x1], x3
    ld1        {\t1\().8b}, [x2], x4
    ld1        {\t2\().8b}, [x1], x3
    ld1        {\t3\().8b}, [x2], x4
    usubl       \t0\().8h,  \t0\().8b,  \t1\().8b
    ld1        {\t4\().8b}, [x1], x3
    ld1        {\t5\().8b}, [x2], x4
    usubl       \t1\().8h,  \t2\().8b,  \t3\().8b
    ld1        {\t6\().8b}, [x1], x3
    ld1        {\t7\().8b}, [x2], x4
    add         \dst\().8h, \t0\().8h,  \t1\().8h
    usubl       \t2\().8h,  \t4\().8b,  \t5\().8b
    usubl       \t3\().8h,  \t6\().8b,  \t7\().8b
    add         \dst\().8h, \dst\().8h, \t2\().8h
    add         \dst\().8h, \dst\().8h, \t3\().8h
.endm

function x264_sub8x8_dct_dc_neon, export=1
    mov             x3,  #FENC_STRIDE
    mov             x4,  #FDEC_STRIDE

    sub4x4x2_dct_dc  v0, v16, v17, v18, v19, v20, v21, v22, v23
    sub4x4x2_dct_dc  v1, v24, v25, v26, v27, v28, v29, v30, v31

    transpose   v2.2d,  v3.2d,  v0.2d,  v1.2d
    SUMSUB_AB   v0.8h,  v1.8h,  v2.8h,  v3.8h
    transpose   v2.2d,  v3.2d,  v0.2d,  v1.2d
    SUMSUB_AB   v0.8h,  v1.8h,  v2.8h,  v3.8h
    transpose   v2.2d,  v3.2d,  v0.2d,  v1.2d

    addp        v0.8h,  v2.8h,  v3.8h
    addp        v0.8h,  v0.8h,  v0.8h

    st1        {v0.4h}, [x0]
    ret
endfunc

function x264_sub8x16_dct_dc_neon, export=1
    mov             x3,  #FENC_STRIDE
    mov             x4,  #FDEC_STRIDE
    sub4x4x2_dct_dc  v0, v16, v17, v18, v19, v20, v21, v22, v23
    sub4x4x2_dct_dc  v1, v24, v25, v26, v27, v28, v29, v30, v31
    sub4x4x2_dct_dc  v2, v16, v17, v18, v19, v20, v21, v22, v23
    sub4x4x2_dct_dc  v3, v24, v25, v26, v27, v28, v29, v30, v31

    addp             v4.8h,  v0.8h,  v2.8h
    addp             v5.8h,  v1.8h,  v3.8h

    transpose   v2.4s,  v3.4s,  v4.4s,  v5.4s
    SUMSUB_AB   v0.8h,  v1.8h,  v2.8h,  v3.8h

    transpose   v2.4s,  v3.4s,  v0.4s,  v1.4s
    SUMSUB_AB   v0.8h,  v1.8h,  v2.8h,  v3.8h

    transpose   v2.2d,  v3.2d,  v0.2d,  v1.2d
    SUMSUB_AB   v0.8h,  v1.8h,  v2.8h,  v3.8h

    trn1        v2.2d,  v0.2d,  v1.2d
    trn2        v3.2d,  v1.2d,  v0.2d

    addp        v0.8h,  v2.8h,  v3.8h

    st1        {v0.8h}, [x0]
    ret
endfunc

function x264_zigzag_interleave_8x8_cavlc_neon, export=1
    mov        x3,  #7
    movi       v31.4s, #1
    ld4        {v0.8h,v1.8h,v2.8h,v3.8h}, [x1],  #64
    ld4        {v4.8h,v5.8h,v6.8h,v7.8h}, [x1],  #64
    umax       v16.8h, v0.8h,  v4.8h
    umax       v17.8h, v1.8h,  v5.8h
    umax       v18.8h, v2.8h,  v6.8h
    umax       v19.8h, v3.8h,  v7.8h
    st1        {v0.8h}, [x0],  #16
    st1        {v4.8h}, [x0],  #16
    umaxp      v16.8h, v16.8h, v17.8h
    umaxp      v18.8h, v18.8h, v19.8h
    st1        {v1.8h}, [x0],  #16
    st1        {v5.8h}, [x0],  #16
    umaxp      v16.8h, v16.8h, v18.8h
    st1        {v2.8h}, [x0],  #16
    st1        {v6.8h}, [x0],  #16
    cmhi       v16.4s, v16.4s, v31.4s
    st1        {v3.8h}, [x0],  #16
    and        v16.16b, v16.16b, v31.16b
    st1        {v7.8h}, [x0],  #16
    st1        {v16.b}[0],    [x2],  #1
    st1        {v16.b}[4],    [x2],  x3
    st1        {v16.b}[8],    [x2],  #1
    st1        {v16.b}[12],   [x2]
    ret
endfunc

function x264_zigzag_scan_4x4_frame_neon, export=1
    movrel      x2, scan4x4_frame
    ld1        {v0.16b,v1.16b}, [x1]
    ld1        {v16.16b,v17.16b}, [x2]
    tbl         v2.16b, {v0.16b,v1.16b}, v16.16b
    tbl         v3.16b, {v0.16b,v1.16b}, v17.16b
    st1        {v2.16b,v3.16b},   [x0]
    ret
endfunc

.macro zigzag_sub_4x4 f ac
function x264_zigzag_sub_4x4\ac\()_\f\()_neon, export=1
    mov         x9,  #FENC_STRIDE
    mov         x4,  #FDEC_STRIDE
    movrel      x5,  sub4x4_\f
    mov         x6,  x2
    ld1        {v0.s}[0], [x1], x9
    ld1        {v0.s}[1], [x1], x9
    ld1        {v0.s}[2], [x1], x9
    ld1        {v0.s}[3], [x1], x9
    ld1        {v16.16b}, [x5]
    ld1        {v1.s}[0], [x2], x4
    ld1        {v1.s}[1], [x2], x4
    ld1        {v1.s}[2], [x2], x4
    ld1        {v1.s}[3], [x2], x4
    tbl         v2.16b, {v0.16b}, v16.16b
    tbl         v3.16b, {v1.16b}, v16.16b
    st1        {v0.s}[0], [x6], x4
    usubl       v4.8h,  v2.8b,  v3.8b
.ifc \ac, ac
    dup         h7, v4.h[0]
    ins         v4.h[0], wzr
    fmov        w5,  s7
    strh        w5,  [x3]
.endif
    usubl2      v5.8h,  v2.16b, v3.16b
    st1        {v0.s}[1], [x6], x4
    umax        v6.8h,  v4.8h,  v5.8h
    umaxv       h6,  v6.8h
    st1        {v0.s}[2], [x6], x4
    fmov        w7,  s6
    st1        {v0.s}[3], [x6], x4
    cmp         w7, #0
    st1        {v4.8h,v5.8h},   [x0]
    cset        w0, ne
    ret
endfunc
.endm

zigzag_sub_4x4 field
zigzag_sub_4x4 field, ac
zigzag_sub_4x4 frame
zigzag_sub_4x4 frame, ac

function x264_zigzag_scan_4x4_field_neon, export=1
    movrel      x2, scan4x4_field
    ld1        {v0.8h,v1.8h},   [x1]
    ld1        {v16.16b},       [x2]
    tbl         v0.16b, {v0.16b}, v16.16b
    st1        {v0.8h,v1.8h},   [x0]
    ret
endfunc

function x264_zigzag_scan_8x8_frame_neon, export=1
    movrel      x2,  scan8x8_frame
    ld1        {v0.8h,v1.8h},   [x1], #32
    ld1        {v2.8h,v3.8h},   [x1], #32
    ld1        {v4.8h,v5.8h},   [x1], #32
    ld1        {v6.8h,v7.8h},   [x1]
    ld1        {v16.16b,v17.16b}, [x2], #32
    ld1        {v18.16b,v19.16b}, [x2], #32
    ld1        {v20.16b,v21.16b}, [x2], #32
    ld1        {v22.16b,v23.16b}, [x2], #32
    tbl         v24.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v16.16b
    tbl         v25.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v17.16b
    tbl         v26.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v18.16b
    tbl         v27.16b, {v3.16b,v4.16b,v5.16b,v6.16b}, v19.16b
    tbl         v28.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v20.16b
    tbl         v29.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v21.16b
    tbl         v30.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v22.16b
    tbl         v31.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v23.16b
    mov         v25.h[6], v4.h[0]
    mov         v25.h[7], v5.h[0]
    mov         v26.h[0], v4.h[1]
    mov         v27.h[4], v7.h[0]
    mov         v28.h[7], v4.h[4]
    mov         v29.h[7], v3.h[6]
    mov         v30.h[0], v2.h[7]
    mov         v30.h[1], v3.h[7]
    st1        {v24.8h,v25.8h}, [x0], #32
    st1        {v26.8h,v27.8h}, [x0], #32
    st1        {v28.8h,v29.8h}, [x0], #32
    st1        {v30.8h,v31.8h}, [x0]
    ret
endfunc

#define Z(z)   2*(z), 2*(z)+1
#define T(x,y) Z(x*8+y)
const scan8x8_frame, align=5
    .byte T(0,0), T(1,0), T(0,1), T(0,2)
    .byte T(1,1), T(2,0), T(3,0), T(2,1)
    .byte T(1,2), T(0,3), T(0,4), T(1,3)
    .byte T(2,2), T(3,1), T(4,0), T(5,0)
    .byte T(4,1), T(3,2), T(2,3), T(1,4)
    .byte T(0,5), T(0,6), T(1,5), T(2,4)
#undef T
#define T(x,y) Z((x-3)*8+y)
    .byte T(3,3), T(4,2), T(5,1), T(6,0)
    .byte T(7,0), T(6,1), T(5,2), T(4,3)
#undef T
#define T(x,y) Z((x-0)*8+y)
    .byte T(3,4), T(2,5), T(1,6), T(0,7)
    .byte T(1,7), T(2,6), T(3,5), T(4,4)
#undef T
#define T(x,y) Z((x-4)*8+y)
    .byte T(5,3), T(6,2), T(7,1), T(7,2)
    .byte T(6,3), T(5,4), T(4,5), T(3,6)
    .byte T(2,7), T(3,7), T(4,6), T(5,5)
    .byte T(6,4), T(7,3), T(7,4), T(6,5)
    .byte T(5,6), T(4,7), T(5,7), T(6,6)
    .byte T(7,5), T(7,6), T(6,7), T(7,7)
endconst

function x264_zigzag_scan_8x8_field_neon, export=1
    movrel      x2,  scan8x8_field
    ld1        {v0.8h,v1.8h},   [x1], #32
    ld1        {v2.8h,v3.8h},   [x1], #32
    ld1        {v4.8h,v5.8h},   [x1], #32
    ld1        {v6.8h,v7.8h},   [x1]
    ld1        {v16.16b,v17.16b}, [x2], #32
    ld1        {v18.16b,v19.16b}, [x2], #32
    ld1        {v20.16b,v21.16b}, [x2], #32
    ld1        {v22.16b}, [x2]
    ext         v31.16b, v7.16b, v7.16b, #4
    tbl         v24.16b, {v0.16b,v1.16b},               v16.16b
    tbl         v25.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v17.16b
    tbl         v26.16b, {v1.16b,v2.16b,v3.16b,v4.16b}, v18.16b
    tbl         v27.16b, {v2.16b,v3.16b,v4.16b,v5.16b}, v19.16b
    tbl         v28.16b, {v3.16b,v4.16b,v5.16b,v6.16b}, v20.16b
    tbl         v29.16b, {v4.16b,v5.16b,v6.16b},        v21.16b
    tbl         v30.16b, {v5.16b,v6.16b,v7.16b},        v22.16b
    ext         v31.16b, v6.16b, v31.16b, #12
    st1        {v24.8h,v25.8h}, [x0], #32
    st1        {v26.8h,v27.8h}, [x0], #32
    st1        {v28.8h,v29.8h}, [x0], #32
    st1        {v30.8h,v31.8h}, [x0]
    ret
endfunc

.macro zigzag_sub8x8 f
function x264_zigzag_sub_8x8_\f\()_neon, export=1
    movrel      x4,  sub8x8_\f
    mov         x5,  #FENC_STRIDE
    mov         x6,  #FDEC_STRIDE
    mov         x7,  x2
    ld1        {v0.d}[0], [x1], x5
    ld1        {v0.d}[1], [x1], x5
    ld1        {v1.d}[0], [x1], x5
    ld1        {v1.d}[1], [x1], x5
    ld1        {v2.d}[0], [x1], x5
    ld1        {v2.d}[1], [x1], x5
    ld1        {v3.d}[0], [x1], x5
    ld1        {v3.d}[1], [x1]
    ld1        {v4.d}[0], [x2], x6
    ld1        {v4.d}[1], [x2], x6
    ld1        {v5.d}[0], [x2], x6
    ld1        {v5.d}[1], [x2], x6
    ld1        {v6.d}[0], [x2], x6
    ld1        {v6.d}[1], [x2], x6
    ld1        {v7.d}[0], [x2], x6
    ld1        {v7.d}[1], [x2]
    ld1        {v16.16b,v17.16b}, [x4], #32
    ld1        {v18.16b,v19.16b}, [x4], #32
    tbl         v24.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v16.16b
    tbl         v25.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v17.16b
    tbl         v26.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v18.16b
    tbl         v27.16b, {v0.16b,v1.16b,v2.16b,v3.16b}, v19.16b
    tbl         v28.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v16.16b
    tbl         v29.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v17.16b
    tbl         v30.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v18.16b
    tbl         v31.16b, {v4.16b,v5.16b,v6.16b,v7.16b}, v19.16b
    usubl       v4.8h,  v24.8b,  v28.8b
    usubl2      v5.8h,  v24.16b, v28.16b
    usubl       v6.8h,  v25.8b,  v29.8b
    usubl2      v7.8h,  v25.16b, v29.16b
    usubl       v16.8h, v26.8b,  v30.8b
    usubl2      v17.8h, v26.16b, v30.16b
    usubl       v18.8h, v27.8b,  v31.8b
    usubl2      v19.8h, v27.16b, v31.16b
    umax        v20.8h, v4.8h,   v5.8h
    umax        v21.8h, v6.8h,   v7.8h
    umax        v22.8h, v16.8h,  v17.8h
    umax        v23.8h, v18.8h,  v19.8h
    umax        v20.8h, v20.8h,  v21.8h
    umax        v21.8h, v22.8h,  v23.8h
    umax        v20.8h, v20.8h,  v21.8h
    umaxv       h22,    v20.8h
    st1        {v0.d}[0], [x7], x6
    st1        {v0.d}[1], [x7], x6
    st1        {v1.d}[0], [x7], x6
    st1        {v1.d}[1], [x7], x6
    st1        {v2.d}[0], [x7], x6
    st1        {v2.d}[1], [x7], x6
    st1        {v3.d}[0], [x7], x6
    st1        {v3.d}[1], [x7]
    st1        {v4.8h,v5.8h},   [x0], #32
    st1        {v6.8h,v7.8h},   [x0], #32
    st1        {v16.8h,v17.8h}, [x0], #32
    st1        {v18.8h,v19.8h}, [x0]
    fmov        w9,  s22
    cmp         w9, #0
    cset        w0, ne
    ret
endfunc
.endm

zigzag_sub8x8 field
zigzag_sub8x8 frame

#undef T
#define T(x,y) Z(x*8+y)
const scan8x8_field, align=5
    .byte T(0,0), T(0,1), T(0,2), T(1,0)
    .byte T(1,1), T(0,3), T(0,4), T(1,2)
    .byte T(2,0), T(1,3), T(0,5), T(0,6)
    .byte T(0,7), T(1,4), T(2,1), T(3,0)
#undef T
#define T(x,y) Z((x-1)*8+y)
    .byte T(2,2), T(1,5), T(1,6), T(1,7)
    .byte T(2,3), T(3,1), T(4,0), T(3,2)
#undef T
#define T(x,y) Z((x-2)*8+y)
    .byte T(2,4), T(2,5), T(2,6), T(2,7)
    .byte T(3,3), T(4,1), T(5,0), T(4,2)
#undef T
#define T(x,y) Z((x-3)*8+y)
    .byte T(3,4), T(3,5), T(3,6), T(3,7)
    .byte T(4,3), T(5,1), T(6,0), T(5,2)
#undef T
#define T(x,y) Z((x-4)*8+y)
    .byte T(4,4), T(4,5), T(4,6), T(4,7)
    .byte T(5,3), T(6,1), T(6,2), T(5,4)
#undef T
#define T(x,y) Z((x-5)*8+y)
    .byte T(5,5), T(5,6), T(5,7), T(6,3)
    .byte T(7,0), T(7,1), T(6,4), T(6,5)
endconst


#undef T
#define T(y,x) x*8+y
const sub8x8_frame, align=5
    .byte T(0,0), T(1,0), T(0,1), T(0,2)
    .byte T(1,1), T(2,0), T(3,0), T(2,1)
    .byte T(1,2), T(0,3), T(0,4), T(1,3)
    .byte T(2,2), T(3,1), T(4,0), T(5,0)
    .byte T(4,1), T(3,2), T(2,3), T(1,4)
    .byte T(0,5), T(0,6), T(1,5), T(2,4)
    .byte T(3,3), T(4,2), T(5,1), T(6,0)
    .byte T(7,0), T(6,1), T(5,2), T(4,3)
    .byte T(3,4), T(2,5), T(1,6), T(0,7)
    .byte T(1,7), T(2,6), T(3,5), T(4,4)
    .byte T(5,3), T(6,2), T(7,1), T(7,2)
    .byte T(6,3), T(5,4), T(4,5), T(3,6)
    .byte T(2,7), T(3,7), T(4,6), T(5,5)
    .byte T(6,4), T(7,3), T(7,4), T(6,5)
    .byte T(5,6), T(4,7), T(5,7), T(6,6)
    .byte T(7,5), T(7,6), T(6,7), T(7,7)
endconst

const sub8x8_field, align=5
    .byte T(0,0), T(0,1), T(0,2), T(1,0)
    .byte T(1,1), T(0,3), T(0,4), T(1,2)
    .byte T(2,0), T(1,3), T(0,5), T(0,6)
    .byte T(0,7), T(1,4), T(2,1), T(3,0)
    .byte T(2,2), T(1,5), T(1,6), T(1,7)
    .byte T(2,3), T(3,1), T(4,0), T(3,2)
    .byte T(2,4), T(2,5), T(2,6), T(2,7)
    .byte T(3,3), T(4,1), T(5,0), T(4,2)
    .byte T(3,4), T(3,5), T(3,6), T(3,7)
    .byte T(4,3), T(5,1), T(6,0), T(5,2)
    .byte T(4,4), T(4,5), T(4,6), T(4,7)
    .byte T(5,3), T(6,1), T(6,2), T(5,4)
    .byte T(5,5), T(5,6), T(5,7), T(6,3)
    .byte T(7,0), T(7,1), T(6,4), T(6,5)
    .byte T(6,6), T(6,7), T(7,2), T(7,3)
    .byte T(7,4), T(7,5), T(7,6), T(7,7)
endconst

#endif 


