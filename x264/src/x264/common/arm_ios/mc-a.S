/*****************************************************************************
 * mc.S: arm motion compensation
 **************************************************66***************************
 * Copyright (C) 2009-2015 x264 project
 *
 * Authors: David Conrad <lessen42@gmail.com>
 *          Mans Rullgard <mans@mansr.com>
 *          Stefan Groenroos <stefan.gronroos@gmail.com>
 *          Janne Grunau <janne-x264@jannau.net>
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

//.section .rodata
.const_data
.align 4
pw_0to15:
.short 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15

.text

// note: prefetch stuff assumes 64-byte cacheline, true for the Cortex-A8
// They also use nothing above armv5te, but we don't care about pre-armv6

// void prefetch_ref( uint8_t *pix, intptr_t stride, int parity )
function x264_prefetch_ref_arm
    sub         r2, r2, #1
    add         r0, r0, #64
    and         r2, r2, r1
    add         r0, r0, r2, lsl #3
    add         r2, r1, r1, lsl #1
    pld         [r0]
    pld         [r0, r1]
    pld         [r0, r1, lsl #1]
    add         r3, r0, r1, lsl #2
    pld         [r0, r2]
    pld         [r3]
    pld         [r3, r1]
    pld         [r3, r1, lsl #1]
    pld         [r3, r2]
    bx          lr
endfunc

// void prefetch_fenc( uint8_t *pix_y,  intptr_t stride_y,
//                     uint8_t *pix_uv, intptr_t stride_uv, int mb_x )
function x264_prefetch_fenc_arm
    ldr         ip, [sp]
    push        {lr}
    and         lr, ip, #3
    smulbb      lr, lr, r1      // note: this assumes stride_y is <= 16 bits signed
    and         ip, ip, #6
    smulbb      ip, ip, r3
    add         r0, r0, #64
    add         r2, r2, #64
    add         r0, r0, lr, lsl #2
    pld         [r0]
    add         lr, r0, r1, lsl #1
    pld         [r0, r1]
    pld         [lr]
    add         r2, r2, ip, lsl #2
    pld         [lr, r1]
    pld         [r2]
    add         ip, r2, r3, lsl #1
    pld         [r2, r3]
    pld         [ip]
    pld         [ip, r3]
    pop         {pc}
endfunc


// void *x264_memcpy_aligned( void *dst, const void *src, size_t n )
function x264_memcpy_aligned_neon
    orr         r3,  r0,  r1,  lsr #1
    movrel      ip,  memcpy_table
    and         r3,  r3,  #0xc
    ldr         pc,  [ip, r3]
endfunc

.macro MEMCPY_ALIGNED srcalign dstalign
//function memcpy_aligned_\dstalign\()_\srcalign\()_neon, export=0
function memcpy_aligned_\dstalign\()_\srcalign\()_neon,export=0
    mov         r3, r0
.if \srcalign == 8 && \dstalign == 8
    sub         r2, #16
    vld1.64     {d0}, [r1,:64]!
    vst1.64     {d0}, [r3,:64]!
    .set r1align, 128
    .set r3align, 128
.else
    .set r1align, \srcalign * 8
    .set r3align, \dstalign * 8
.endif
    tst         r2, #16
    beq         32f
    sub         r2, #16
    vld1.64     {d0-d1}, [r1,:r1align]!
    vst1.64     {d0-d1}, [r3,:r3align]!
32: // n is a multiple of 32
    tst         r2, #32
    beq         640f
    sub         r2, #32
    vld1.64     {d0-d3}, [r1,:r1align]!
    vst1.64     {d0-d3}, [r3,:r3align]!
640: // n is a multiple of 64
    cmp         r2, #0
    beq         1f
64:
    subs        r2, #64
    vld1.64     {d0-d3}, [r1,:r1align]!
    vld1.64     {d4-d7}, [r1,:r1align]!
    vst1.64     {d0-d3}, [r3,:r3align]!
    vst1.64     {d4-d7}, [r3,:r3align]!
    bgt         64b
1:   // end
.if \srcalign == 8 && \dstalign == 8
    vld1.64     {d0}, [r1,:64]!
    vst1.64     {d0}, [r3,:64]!
.endif
    bx          lr
endfunc
.endm

MEMCPY_ALIGNED 16, 16
MEMCPY_ALIGNED 16, 8
MEMCPY_ALIGNED  8, 16
MEMCPY_ALIGNED  8, 8

//.section .rodata
.const_data
memcpy_table:
.word memcpy_aligned_16_16_neon
.word memcpy_aligned_16_8_neon
.word memcpy_aligned_8_16_neon
.word memcpy_aligned_8_8_neon
.text

.ltorg

// void x264_memzero_aligned( void *dst, size_t n )
function x264_memzero_aligned_neon
    vmov.i8     q0, #0
    vmov.i8     q1, #0
memzero_loop:
    subs        r1, #128
.rept 4
    vst1.64     {d0-d3}, [r0,:128]!
.endr
    bgt         memzero_loop
    bx          lr
endfunc


// void pixel_avg( uint8_t *dst,  intptr_t dst_stride,
//                 uint8_t *src1, intptr_t src1_stride,
//                 uint8_t *src2, intptr_t src2_stride, int weight );
.macro AVGH w h
function x264_pixel_avg_\w\()x\h\()_neon
    ldr         ip, [sp, #8]
    push        {r4-r6,lr}
    cmp         ip, #32
    ldrd        r4, r5, [sp, #16]
    mov         lr, #\h
    beq         x264_pixel_avg_w\w\()_neon
    rsbs        r6,  ip,  #64
    blt         x264_pixel_avg_weight_w\w\()_add_sub_neon     // weight > 64
    cmp         ip,  #0
    bge         x264_pixel_avg_weight_w\w\()_add_add_neon
    b           x264_pixel_avg_weight_w\w\()_sub_add_neon     // weight < 0
endfunc
.endm

AVGH  4, 2
AVGH  4, 4
AVGH  4, 8
AVGH  4, 16
AVGH  8, 4
AVGH  8, 8
AVGH  8, 16
AVGH 16, 8
AVGH 16, 16

// 0 < weight < 64
.macro load_weights_add_add
    vdup.8      d30, ip
    vdup.8      d31, r6
.endm

.macro load_add_add d1 d2
    vld1.32     {\d1}, [r2], r3
    vld1.32     {\d2}, [r4], r5
.endm

.macro weight_add_add dst s1 s2
    vmull.u8    \dst, \s1, d30
    vmlal.u8    \dst, \s2, d31
.endm

// weight > 64
.macro load_weights_add_sub
    rsb         r6,  #0
    vdup.8      d30, ip
    vdup.8      d31, r6
.endm

.macro load_add_sub d1 d2
    vld1.32     {\d1}, [r2], r3
    vld1.32     {\d2}, [r4], r5
.endm

.macro weight_add_sub dst s1 s2
    vmull.u8    \dst, \s1, d30
    vmlsl.u8    \dst, \s2, d31
.endm

// weight < 0
.macro load_weights_sub_add
    rsb         ip,  #0
    vdup.8      d31, r6
    vdup.8      d30, ip
.endm

.macro load_sub_add d1 d2
    vld1.32     {\d2}, [r4], r5
    vld1.32     {\d1}, [r2], r3
.endm

.macro weight_sub_add dst s1 s2
    vmull.u8    \dst, \s2, d31
    vmlsl.u8    \dst, \s1, d30
.endm

.macro AVG_WEIGHT ext
function x264_pixel_avg_weight_w4_\ext\()_neon, export=0
    load_weights_\ext
1:  // height loop
    subs            lr,  lr,  #2
    load_\ext       d0[], d1[]
    weight_\ext     q8,  d0,  d1
    load_\ext       d2[], d3[]
    vqrshrun.s16    d0,  q8,  #6
    weight_\ext     q9,  d2,  d3
    vst1.32         {d0[0]}, [r0,:32], r1
    vqrshrun.s16    d1,  q9,  #6
    vst1.32         {d1[0]}, [r0,:32], r1
    bgt             1b
    pop             {r4-r6,pc}
endfunc

function x264_pixel_avg_weight_w8_\ext\()_neon, export=0
    load_weights_\ext
1:  // height loop
    subs            lr,  lr,  #4
    load_\ext       d0,  d1
    weight_\ext     q8,  d0,  d1
    load_\ext       d2,  d3
    weight_\ext     q9,  d2,  d3
    load_\ext       d4,  d5
    weight_\ext     q10, d4,  d5
    load_\ext       d6,  d7
    weight_\ext     q11, d6,  d7
    vqrshrun.s16    d0,  q8,  #6
    vqrshrun.s16    d1,  q9,  #6
    vqrshrun.s16    d2,  q10, #6
    vqrshrun.s16    d3,  q11, #6
    vst1.64         {d0}, [r0,:64], r1
    vst1.64         {d1}, [r0,:64], r1
    vst1.64         {d2}, [r0,:64], r1
    vst1.64         {d3}, [r0,:64], r1
    bgt             1b
    pop             {r4-r6,pc}
endfunc

function x264_pixel_avg_weight_w16_\ext\()_neon, export=0
    load_weights_\ext
1:  // height loop
    subs            lr,  lr,  #2
    load_\ext       d0-d1, d2-d3
    weight_\ext     q8,  d0,  d2
    weight_\ext     q9,  d1,  d3
    load_\ext       d4-d5, d6-d7
    weight_\ext     q10, d4,  d6
    weight_\ext     q11, d5,  d7
    vqrshrun.s16    d0,  q8,  #6
    vqrshrun.s16    d1,  q9,  #6
    vqrshrun.s16    d2,  q10, #6
    vqrshrun.s16    d3,  q11, #6
    vst1.64         {d0-d1}, [r0,:128], r1
    vst1.64         {d2-d3}, [r0,:128], r1
    bgt             1b
    pop             {r4-r6,pc}
endfunc
.endm

AVG_WEIGHT add_add
AVG_WEIGHT add_sub
AVG_WEIGHT sub_add

function x264_pixel_avg_w4_neon, export=0
    subs        lr,  lr,  #2
    vld1.32     {d0[]}, [r2], r3
    vld1.32     {d2[]}, [r4], r5
    vrhadd.u8   d0,  d0,  d2
    vld1.32     {d1[]}, [r2], r3
    vld1.32     {d3[]}, [r4], r5
    vrhadd.u8   d1,  d1,  d3
    vst1.32     {d0[0]}, [r0,:32], r1
    vst1.32     {d1[0]}, [r0,:32], r1
    bgt         x264_pixel_avg_w4_neon
    pop         {r4-r6,pc}
endfunc

function x264_pixel_avg_w8_neon, export=0
    subs        lr,  lr,  #4
    vld1.64     {d0}, [r2], r3
    vld1.64     {d2}, [r4], r5
    vrhadd.u8   d0,  d0,  d2
    vld1.64     {d1}, [r2], r3
    vld1.64     {d3}, [r4], r5
    vrhadd.u8   d1,  d1,  d3
    vst1.64     {d0}, [r0,:64], r1
    vld1.64     {d2}, [r2], r3
    vld1.64     {d4}, [r4], r5
    vrhadd.u8   d2,  d2,  d4
    vst1.64     {d1}, [r0,:64], r1
    vld1.64     {d3}, [r2], r3
    vld1.64     {d5}, [r4], r5
    vrhadd.u8   d3,  d3,  d5
    vst1.64     {d2}, [r0,:64], r1
    vst1.64     {d3}, [r0,:64], r1
    bgt         x264_pixel_avg_w8_neon
    pop         {r4-r6,pc}
endfunc

function x264_pixel_avg_w16_neon, export=0
    subs        lr,  lr,  #4
    vld1.64     {d0-d1}, [r2], r3
    vld1.64     {d2-d3}, [r4], r5
    vrhadd.u8   q0,  q0,  q1
    vld1.64     {d2-d3}, [r2], r3
    vld1.64     {d4-d5}, [r4], r5
    vrhadd.u8   q1,  q1,  q2
    vst1.64     {d0-d1}, [r0,:128], r1
    vld1.64     {d4-d5}, [r2], r3
    vld1.64     {d6-d7}, [r4], r5
    vrhadd.u8   q2,  q2,  q3
    vst1.64     {d2-d3}, [r0,:128], r1
    vld1.64     {d6-d7}, [r2], r3
    vld1.64     {d0-d1}, [r4], r5
    vrhadd.u8   q3,  q3,  q0
    vst1.64     {d4-d5}, [r0,:128], r1
    vst1.64     {d6-d7}, [r0,:128], r1
    bgt         x264_pixel_avg_w16_neon
    pop         {r4-r6,pc}
endfunc


function x264_pixel_avg2_w4_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    ldr         lr,  [sp, #4]
avg2_w4_loop:
    subs        ip,  ip,  #2
    vld1.32     {d0[]},  [r2], r3
    vld1.32     {d2[]},  [lr], r3
    vrhadd.u8   d0,  d0,  d2
    vld1.32     {d1[]},  [r2], r3
    vld1.32     {d3[]},  [lr], r3
    vrhadd.u8   d1,  d1,  d3
    vst1.32     {d0[0]}, [r0,:32], r1
    vst1.32     {d1[0]}, [r0,:32], r1
    bgt         avg2_w4_loop
    pop         {pc}
endfunc

function x264_pixel_avg2_w8_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    ldr         lr,  [sp, #4]
avg2_w8_loop:
    subs        ip,  ip,  #2
    vld1.64     {d0}, [r2], r3
    vld1.64     {d2}, [lr], r3
    vrhadd.u8   d0,  d0,  d2
    vld1.64     {d1}, [r2], r3
    vld1.64     {d3}, [lr], r3
    vrhadd.u8   d1,  d1,  d3
    vst1.64     {d0}, [r0,:64], r1
    vst1.64     {d1}, [r0,:64], r1
    bgt         avg2_w8_loop
    pop         {pc}
endfunc

function x264_pixel_avg2_w16_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    ldr         lr,  [sp, #4]
avg2_w16_loop:
    subs        ip,  ip,  #2
    vld1.64     {d0-d1}, [r2], r3
    vld1.64     {d2-d3}, [lr], r3
    vrhadd.u8   q0,  q0,  q1
    vld1.64     {d4-d5}, [r2], r3
    vld1.64     {d6-d7}, [lr], r3
    vrhadd.u8   q2,  q2,  q3
    vst1.64     {d0-d1}, [r0,:128], r1
    vst1.64     {d4-d5}, [r0,:128], r1
    bgt         avg2_w16_loop
    pop         {pc}
endfunc

function x264_pixel_avg2_w20_neon
    ldr         ip,  [sp, #4]
    push        {lr}
    sub         r1,  r1,  #16
    ldr         lr,  [sp, #4]
avg2_w20_loop:
    subs        ip,  ip,  #2
    vld1.64     {d0-d2},  [r2], r3
    vld1.64     {d4-d6},  [lr], r3
    vrhadd.u8   q0,  q0,  q2
    vrhadd.u8   d2,  d2,  d6
    vld1.64     {d4-d6},  [r2], r3
    vld1.64     {d16-d18},[lr], r3
    vrhadd.u8   q2,  q2,  q8
    vst1.64     {d0-d1},  [r0,:128]!
    vrhadd.u8   d6,  d6,  d18
    vst1.32     {d2[0]},  [r0,:32], r1
    vst1.64     {d4-d5},  [r0,:128]!
    vst1.32     {d6[0]},  [r0,:32], r1
    bgt         avg2_w20_loop
    pop         {pc}
endfunc


.macro weight_prologue type
    push        {r4-r5,lr}
    ldr         r4,  [sp, #4*3]     // weight_t
    ldr         ip,  [sp, #4*3+4]   // h
.ifc \type, full
    ldr         lr,  [r4, #32]      // denom
.endif
    ldrd        r4,  r5,  [r4, #32+4]    // scale, offset
    vdup.8      d0,  r4
    vdup.16     q1,  r5
.ifc \type, full
    rsb         lr,  lr,  #0
    vdup.16     q2,  lr
.endif
.endm

// void mc_weight( uint8_t *src, intptr_t src_stride, uint8_t *dst, intptr_t dst_stride,
//                 const x264_weight_t *weight, int height )
function x264_mc_weight_w20_neon
    weight_prologue full
    sub         r1, #16
weight20_loop:
    subs        ip,  #2
    vld1.8      {d17-d19}, [r2], r3
    vmull.u8    q10, d17, d0
    vmull.u8    q11, d18, d0
    vld1.8      {d16-d18}, [r2], r3
    vmull.u8    q12, d16, d0
    vmull.u8    q13, d17, d0
    vtrn.32     d19, d18
    vmull.u8    q14, d19, d0
    vrshl.s16   q10, q10, q2
    vrshl.s16   q11, q11, q2
    vrshl.s16   q12, q12, q2
    vrshl.s16   q13, q13, q2
    vrshl.s16   q14, q14, q2
    vadd.s16    q10, q10, q1
    vadd.s16    q11, q11, q1
    vadd.s16    q12, q12, q1
    vadd.s16    q13, q13, q1
    vadd.s16    q14, q14, q1
    vqmovun.s16 d16, q10
    vqmovun.s16 d17, q11
    vqmovun.s16 d18, q12
    vqmovun.s16 d19, q13
    vqmovun.s16 d20, q14
    vst1.8      {d16-d17}, [r0,:128]!
    vst1.32     {d20[0]},  [r0,:32], r1
    vst1.8      {d18-d19}, [r0,:128]!
    vst1.32     {d20[1]},  [r0,:32], r1
    bgt         weight20_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w16_neon
    weight_prologue full
weight16_loop:
    subs        ip,  #2
    vld1.8      {d16-d17}, [r2], r3
    vld1.8      {d18-d19}, [r2], r3
    vmull.u8    q10, d16, d0
    vmull.u8    q11, d17, d0
    vmull.u8    q12, d18, d0
    vmull.u8    q13, d19, d0
    vrshl.s16   q10, q10, q2
    vrshl.s16   q11, q11, q2
    vrshl.s16   q12, q12, q2
    vrshl.s16   q13, q13, q2
    vadd.s16    q10, q10, q1
    vadd.s16    q11, q11, q1
    vadd.s16    q12, q12, q1
    vadd.s16    q13, q13, q1
    vqmovun.s16 d16, q10
    vqmovun.s16 d17, q11
    vqmovun.s16 d18, q12
    vqmovun.s16 d19, q13
    vst1.8      {d16-d17}, [r0,:128], r1
    vst1.8      {d18-d19}, [r0,:128], r1
    bgt         weight16_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w8_neon
    weight_prologue full
weight8_loop:
    subs        ip,  #2
    vld1.8      {d16}, [r2], r3
    vld1.8      {d18}, [r2], r3
    vmull.u8    q8,  d16, d0
    vmull.u8    q9,  d18, d0
    vrshl.s16   q8,  q8,  q2
    vrshl.s16   q9,  q9,  q2
    vadd.s16    q8,  q8,  q1
    vadd.s16    q9,  q9,  q1
    vqmovun.s16 d16, q8
    vqmovun.s16 d18, q9
    vst1.8      {d16}, [r0,:64], r1
    vst1.8      {d18}, [r0,:64], r1
    bgt         weight8_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w4_neon
    weight_prologue full
weight4_loop:
    subs        ip,  #2
    vld1.32     {d16[0]}, [r2], r3
    vld1.32     {d16[1]}, [r2], r3
    vmull.u8    q8,  d16, d0
    vrshl.s16   q8,  q8,  q2
    vadd.s16    q8,  q8,  q1
    vqmovun.s16 d16, q8
    vst1.32     {d16[0]}, [r0], r1
    vst1.32     {d16[1]}, [r0], r1
    bgt         weight4_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w20_nodenom_neon
    weight_prologue nodenom
    sub         r1, #16
weight20_nodenom_loop:
    subs        ip,  #2
    vld1.8      {d26-d28}, [r2], r3
    vmov        q8,  q1
    vmov        q9,  q1
    vld1.8      {d29-d31}, [r2], r3
    vmov        q10, q1
    vmov        q11, q1
    vmov        q12, q1
    vtrn.32     d28, d31
    vmlal.u8    q8,  d26, d0
    vmlal.u8    q9,  d27, d0
    vmlal.u8    q10, d29, d0
    vmlal.u8    q11, d30, d0
    vmlal.u8    q12, d28, d0
    vqmovun.s16 d16, q8
    vqmovun.s16 d17, q9
    vqmovun.s16 d18, q10
    vqmovun.s16 d19, q11
    vqmovun.s16 d20, q12
    vst1.8      {d16-d17}, [r0,:128]!
    vst1.32     {d20[0]},  [r0,:32], r1
    vst1.8      {d18-d19}, [r0,:128]!
    vst1.32     {d20[1]},  [r0,:32], r1
    bgt         weight20_nodenom_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w16_nodenom_neon
    weight_prologue nodenom
weight16_nodenom_loop:
    subs        ip,  #2
    vld1.8      {d16-d17}, [r2], r3
    vld1.8      {d18-d19}, [r2], r3
    vmov        q12, q1
    vmov        q13, q1
    vmov        q14, q1
    vmov        q15, q1
    vmlal.u8    q12, d16, d0
    vmlal.u8    q13, d17, d0
    vmlal.u8    q14, d18, d0
    vmlal.u8    q15, d19, d0
    vqmovun.s16 d16, q12
    vqmovun.s16 d17, q13
    vqmovun.s16 d18, q14
    vqmovun.s16 d19, q15
    vst1.8      {d16-d17}, [r0,:128], r1
    vst1.8      {d18-d19}, [r0,:128], r1
    bgt         weight16_nodenom_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w8_nodenom_neon
    weight_prologue nodenom
weight8_nodenom_loop:
    subs        ip,  #2
    vld1.8      {d16}, [r2], r3
    vld1.8      {d18}, [r2], r3
    vmov        q10, q1
    vmov        q11, q1
    vmlal.u8    q10, d16, d0
    vmlal.u8    q11, d18, d0
    vqmovun.s16 d16, q10
    vqmovun.s16 d17, q11
    vst1.8      {d16}, [r0,:64], r1
    vst1.8      {d17}, [r0,:64], r1
    bgt         weight8_nodenom_loop
    pop         {r4-r5,pc}
endfunc

function x264_mc_weight_w4_nodenom_neon
    weight_prologue nodenom
weight4_nodenom_loop:
    subs        ip,  #2
    vld1.32     {d16[0]}, [r2], r3
    vld1.32     {d16[1]}, [r2], r3
    vmov        q10, q1
    vmlal.u8    q10, d16, d0
    vqmovun.s16 d16, q10
    vst1.32     {d16[0]}, [r0], r1
    vst1.32     {d16[1]}, [r0], r1
    bgt         weight4_nodenom_loop
    pop         {r4-r5,pc}
endfunc

.macro weight_simple_prologue
    push        {lr}
    ldr         lr,  [sp, #4]       // weight_t
    ldr         ip,  [sp, #8]       // h
    ldr         lr,  [lr]           // offset
    vdup.8      q1,  lr
.endm

.macro weight_simple name op
function x264_mc_weight_w20_\name\()_neon
    weight_simple_prologue
weight20_\name\()_loop:
    subs        ip,  #2
    vld1.8      {d16-d18}, [r2], r3
    vld1.8      {d19-d21}, [r2], r3
    \op         q8,  q8,  q1
    \op         q9,  q9,  q1
    \op         q10, q10, q1
    vst1.8      {d16-d18}, [r0,:64], r1
    vst1.8      {d19-d21}, [r0,:64], r1
    bgt         weight20_\name\()_loop
    pop         {pc}
endfunc

function x264_mc_weight_w16_\name\()_neon
    weight_simple_prologue
weight16_\name\()_loop:
    subs        ip,  #2
    vld1.8      {d16-d17}, [r2], r3
    vld1.8      {d18-d19}, [r2], r3
    \op         q8,  q8,  q1
    \op         q9,  q9,  q1
    vst1.8      {d16-d17}, [r0,:128], r1
    vst1.8      {d18-d19}, [r0,:128], r1
    bgt         weight16_\name\()_loop
    pop         {pc}
endfunc

function x264_mc_weight_w8_\name\()_neon
    weight_simple_prologue
weight8_\name\()_loop:
    subs        ip,  #2
    vld1.8      {d16}, [r2], r3
    vld1.8      {d17}, [r2], r3
    \op         q8,  q8,  q1
    vst1.8      {d16}, [r0,:64], r1
    vst1.8      {d17}, [r0,:64], r1
    bgt         weight8_\name\()_loop
    pop         {pc}
endfunc

function x264_mc_weight_w4_\name\()_neon
    weight_simple_prologue
weight4_\name\()_loop:
    subs        ip,  #2
    vld1.32     {d16[]}, [r2], r3
    vld1.32     {d17[]}, [r2], r3
    \op         q8,  q8,  q1
    vst1.32     {d16[0]}, [r0], r1
    vst1.32     {d17[0]}, [r0], r1
    bgt         weight4_\name\()_loop
    pop         {pc}
endfunc
.endm

weight_simple offsetadd, vqadd.u8
weight_simple offsetsub, vqsub.u8


// void mc_copy( uint8_t *dst, intptr_t dst_stride, uint8_t *src, intptr_t src_stride, int height )
function x264_mc_copy_w4_neon
    ldr         ip,  [sp]
copy_w4_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0[]},  [r2], r3
    vld1.32     {d1[]},  [r2], r3
    vld1.32     {d2[]},  [r2], r3
    vld1.32     {d3[]},  [r2], r3
    vst1.32     {d0[0]}, [r0,:32], r1
    vst1.32     {d1[0]}, [r0,:32], r1
    vst1.32     {d2[0]}, [r0,:32], r1
    vst1.32     {d3[0]}, [r0,:32], r1
    bgt         copy_w4_loop
    bx          lr
endfunc

function x264_mc_copy_w8_neon
    ldr         ip,  [sp]
copy_w8_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0}, [r2], r3
    vld1.32     {d1}, [r2], r3
    vld1.32     {d2}, [r2], r3
    vld1.32     {d3}, [r2], r3
    vst1.32     {d0}, [r0,:64], r1
    vst1.32     {d1}, [r0,:64], r1
    vst1.32     {d2}, [r0,:64], r1
    vst1.32     {d3}, [r0,:64], r1
    bgt         copy_w8_loop
    bx          lr
endfunc

function x264_mc_copy_w16_neon
    ldr         ip,  [sp]
copy_w16_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0-d1}, [r2], r3
    vld1.32     {d2-d3}, [r2], r3
    vld1.32     {d4-d5}, [r2], r3
    vld1.32     {d6-d7}, [r2], r3
    vst1.32     {d0-d1}, [r0,:128], r1
    vst1.32     {d2-d3}, [r0,:128], r1
    vst1.32     {d4-d5}, [r0,:128], r1
    vst1.32     {d6-d7}, [r0,:128], r1
    bgt         copy_w16_loop
    bx          lr
endfunc

function x264_mc_copy_w16_aligned_neon
    ldr         ip,  [sp]
copy_w16_aligned_loop:
    subs        ip,  ip,  #4
    vld1.32     {d0-d1}, [r2,:128], r3
    vld1.32     {d2-d3}, [r2,:128], r3
    vld1.32     {d4-d5}, [r2,:128], r3
    vld1.32     {d6-d7}, [r2,:128], r3
    vst1.32     {d0-d1}, [r0,:128], r1
    vst1.32     {d2-d3}, [r0,:128], r1
    vst1.32     {d4-d5}, [r0,:128], r1
    vst1.32     {d6-d7}, [r0,:128], r1
    bgt         copy_w16_aligned_loop
    bx          lr
endfunc


// void x264_mc_chroma_neon( uint8_t *dst, intptr_t i_dst_stride,
//                           uint8_t *src, intptr_t i_src_stride,
//                           int dx, int dy, int i_width, int i_height );

function x264_mc_chroma_neon
    push            {r4-r8, lr}
    vpush           {d8-d11}
    ldrd            r4, r5, [sp, #56]
    ldrd            r6, r7, [sp, #64]

    asr             lr, r6, #3
    mul             lr, r4, lr
    add             r3, r3, r5, asr #2
    cmp             r7, #4

    and             r5, r5, #7
    and             r6, r6, #7

    add             r3, r3, lr
    bic             r3, r3, #0x1

    pld             [r3]
    pld             [r3, r4]

    bgt             mc_chroma_w8
    beq             mc_chroma_w4

.macro CHROMA_MC_START r00, r01, r10, r11
    muls            lr, r5, r6
    rsb             r7, lr, r6, lsl #3
    rsb             ip, lr, r5, lsl #3
    sub             r5, lr, r5, lsl #3
    sub             r5, r5, r6, lsl #3
    add             r5, r5, #64

    beq             2f
    vld2.8          {\r00-\r01}, [r3], r4

    vdup.8          d0,    r5
    vdup.8          d1,    ip

    vdup.8          d2,    r7
    vld2.8          {\r10-\r11}, [r3], r4
    vdup.8          d3,    lr
    ldr             r5,    [sp, #72]
.endm

.macro CHROMA_MC width, align
mc_chroma_w\width:
    CHROMA_MC_START d4, d5,  d8, d9
    vext.8          d6,  d4,  d6,  #1
    vext.8          d7,  d5,  d7,  #1
    vext.8          d10, d8,  d10, #1
    vext.8          d11, d9,  d11, #1
// since the element size varies, there's a different index for the 2nd store
.if \width == 4
    .set st2, 1
.else
    .set st2, 2
.endif

    vtrn.32         d4, d6
    vtrn.32         d5, d7
    vtrn.32         d8, d10
    vtrn.32         d9, d11

    vtrn.32         d0, d1
    vtrn.32         d2, d3

1:  // height loop, interpolate xy

    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d8,  d2
    vmull.u8        q9,  d5,  d0
    vmlal.u8        q9,  d9,  d2

    vld2.8          {d4-d5},  [r3], r4

    vext.8          d6,  d4,  d6,  #1
    vext.8          d7,  d5,  d7,  #1

    vadd.i16        d16, d16, d17
    vadd.i16        d17, d18, d19

    vtrn.32         d4,  d6
    vtrn.32         d5,  d7

    vmull.u8        q10, d8,  d0
    vmlal.u8        q10, d4,  d2
    vmull.u8        q11, d9,  d0
    vmlal.u8        q11, d5,  d2

    vld2.8          {d8-d9},  [r3], r4

    vrshrn.u16      d16, q8,  #6

    vext.8          d10, d8,  d10,  #1
    vext.8          d11, d9,  d11,  #1

    vadd.i16        d18, d20, d21
    vadd.i16        d19, d22, d23

    vtrn.32         d8, d10
    vtrn.32         d9, d11

    vrshrn.u16      d18, q9,  #6

    subs            r5,  r5,  #2

    pld             [r3]
    pld             [r3, r4]

    vst1.\align     {d16[0]},   [r0,:\align], r2
    vst1.\align     {d16[st2]}, [r1,:\align], r2
    vst1.\align     {d18[0]},   [r0,:\align], r2
    vst1.\align     {d18[st2]}, [r1,:\align], r2
    bgt             1b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

2:  // dx or dy are 0
    tst             r7,  r7
    add             ip,  ip,  r7
    vdup.8          d0,  r5
    ldr             r5,  [sp, #72]
    vdup.8          d1,  ip

    beq             4f

    vld1.64          {d4}, [r3], r4
    vld1.64          {d6}, [r3], r4

3:  // vertical interpolation loop

    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d6,  d1
    vmull.u8        q9,  d6,  d0
    vld1.64         {d4}, [r3], r4
    vmlal.u8        q9,  d4,  d1
    vld1.64         {d6}, [r3], r4

    vrshrn.u16      d16, q8,  #6 // uvuvuvuv
    vrshrn.u16      d17, q9,  #6 // uvuvuvuv
    subs            r5,  r5,  #2
    vuzp.8          d16, d17 // d16=uuuu|uuuu, d17=vvvv|vvvv

    pld             [r3]
    pld             [r3, r4]

    vst1.\align     {d16[0]},   [r0,:\align], r2
    vst1.\align     {d16[st2]}, [r0,:\align], r2
    vst1.\align     {d17[0]},   [r1,:\align], r2
    vst1.\align     {d17[st2]}, [r1,:\align], r2
    bgt             3b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

4:  // dy is 0

    vld1.64         {d4-d5},  [r3], r4
    vld1.64         {d6-d7},  [r3], r4

    vext.8          d5,  d4,  d5,  #2
    vext.8          d7,  d6,  d7,  #2

5:  // horizontal interpolation loop

    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d5,  d1
    vmull.u8        q9,  d6,  d0
    vmlal.u8        q9,  d7,  d1

    subs            r5,  r5,  #2
    vld1.64         {d4-d5},  [r3], r4
    vld1.64         {d6-d7},  [r3], r4
    vext.8          d5,  d4,  d5,  #2
    vrshrn.u16      d16, q8,  #6
    vrshrn.u16      d17, q9,  #6
    vext.8          d7,  d6,  d7,  #2
    vuzp.8          d16, d17

    pld             [r3]
    pld             [r3, r4]

    vst1.\align     {d16[0]},   [r0,:\align], r2
    vst1.\align     {d16[st2]}, [r0,:\align], r2
    vst1.\align     {d17[0]},   [r1,:\align], r2
    vst1.\align     {d17[st2]}, [r1,:\align], r2
    bgt             5b

    vpop            {d8-d11}
    pop             {r4-r8, pc}
.endm

   CHROMA_MC 2, 16
   CHROMA_MC 4, 32

mc_chroma_w8:
    CHROMA_MC_START d4, d7, d8, d11
    vext.8          d5,  d4,  d5,  #1
    vext.8          d9,  d8,  d9,  #1
    vext.8          d7,  d6,  d7,  #1
    vext.8          d11, d10, d11,  #1

1:  // height loop, interpolate xy
    vmull.u8        q8,  d4,  d0
    vmlal.u8        q8,  d5,  d1
    vmlal.u8        q8,  d8,  d2
    vmlal.u8        q8,  d9,  d3

    vmull.u8        q9,  d6,  d0
    vmlal.u8        q9,  d7,  d1
    vmlal.u8        q9,  d10,  d2
    vmlal.u8        q9,  d11,  d3

    vld2.8          {d4-d7}, [r3], r4

    vext.8          d5,  d4,  d5,  #1
    vext.8          d7,  d6,  d7,  #1

    vmull.u8        q10, d8,   d0
    vmlal.u8        q10, d9,   d1
    vmlal.u8        q10, d4,   d2
    vmlal.u8        q10, d5,   d3

    vmull.u8        q11, d10,  d0
    vmlal.u8        q11, d11,  d1
    vmlal.u8        q11, d6,   d2
    vmlal.u8        q11, d7,   d3

    subs            r5,  r5,   #2
    vld2.8          {d8-d11}, [r3], r4

    vrshrn.u16      d16, q8,  #6
    vrshrn.u16      d17, q9,  #6
    vrshrn.u16      d18, q10, #6
    vext.8          d9,  d8,  d9,  #1
    vrshrn.u16      d19, q11, #6
    vext.8          d11, d10, d11,  #1

    pld             [r3]
    pld             [r3, r4]

    vst1.64         {d16}, [r0,:64], r2
    vst1.64         {d17}, [r1,:64], r2
    vst1.64         {d18}, [r0,:64], r2
    vst1.64         {d19}, [r1,:64], r2

    bgt             1b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

2:  // dx or dy are 0
    tst             r7,  r7
    add             ip,  ip,  r7
    vdup.8          d0,  r5
    ldr             r5,  [sp, #72]
    vdup.8          d1,  ip

    beq             4f

    vld2.8          {d4-d5}, [r3], r4
    vld2.8          {d6-d7}, [r3], r4

3:  // vertical interpolation loop
    vmull.u8        q8,  d4,  d0 //U
    vmlal.u8        q8,  d6,  d1
    vmull.u8        q9,  d5,  d0 //V
    vmlal.u8        q9,  d7,  d1

    vld2.8          {d4-d5}, [r3], r4

    vmull.u8        q10, d6,  d0
    vmlal.u8        q10, d4,  d1
    vmull.u8        q11, d7,  d0
    vmlal.u8        q11, d5,  d1

    vld2.8          {d6-d7}, [r3], r4

    vrshrn.u16      d16, q8,  #6
    vrshrn.u16      d17, q9,  #6
    vrshrn.u16      d18, q10, #6
    vrshrn.u16      d19, q11, #6
    subs            r5,  r5,  #2

    pld             [r3]
    pld             [r3, r4]

    vst1.64         {d16}, [r0,:64], r2
    vst1.64         {d17}, [r1,:64], r2
    vst1.64         {d18}, [r0,:64], r2
    vst1.64         {d19}, [r1,:64], r2

    bgt             3b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

4:  // dy is 0

    vld2.8          {d4-d7},  [r3], r4
    vld2.8          {d8-d11}, [r3], r4
    vext.8          d5,  d4,  d5,  #1
    vext.8          d7,  d6,  d7,  #1
    vext.8          d9,  d8,  d9,  #1
    vext.8          d11, d10, d11, #1

5:  // horizontal interpolation loop
    subs            r5,  r5,  #2
    vmull.u8        q8,  d4,  d0 //U
    vmlal.u8        q8,  d5,  d1
    vmull.u8        q9,  d6,  d0 //V
    vmlal.u8        q9,  d7,  d1

    vld2.8          {d4-d7}, [r3], r4

    vmull.u8        q10, d8,  d0
    vmlal.u8        q10, d9,  d1
    vmull.u8        q11, d10, d0
    vmlal.u8        q11, d11, d1

    vld2.8          {d8-d11}, [r3], r4

    vext.8          d5,  d4,  d5,  #1
    vrshrn.u16      d16, q8,  #6
    vext.8          d7,  d6,  d7,  #1
    vrshrn.u16      d17, q9,  #6
    vext.8          d9,  d8,  d9,  #1
    vrshrn.u16      d18, q10, #6
    vext.8          d11, d10, d11, #1
    vrshrn.u16      d19, q11, #6

    pld             [r3]
    pld             [r3, r4]

    vst1.64         {d16}, [r0,:64], r2
    vst1.64         {d17}, [r1,:64], r2
    vst1.64         {d18}, [r0,:64], r2
    vst1.64         {d19}, [r1,:64], r2
    bgt             5b

    vpop            {d8-d11}
    pop             {r4-r8, pc}

endfunc


// hpel_filter_v( uint8_t *dst, uint8_t *src, int16_t *buf, intptr_t stride, int width )
function x264_hpel_filter_v_neon
    ldr             ip,  [sp]
    sub             r1,  r1,  r3,  lsl #1
    push            {lr}
    add             lr,  r1,  ip
    vmov.u8         d30, #5
    vmov.u8         d31, #20

filter_v_loop:
    subs            ip,  ip,  #16
    vld1.64         {d0-d1},   [r1,:128], r3
    vld1.64         {d2-d3},   [r1,:128], r3
    vld1.64         {d4-d5},   [r1,:128], r3
    vld1.64         {d6-d7},   [r1,:128], r3
    vld1.64         {d16-d17}, [r1,:128], r3
    vld1.64         {d18-d19}, [r1,:128], r3
    sub             r1,  lr,  ip

    vaddl.u8        q10, d0,  d18
    vmlsl.u8        q10, d2,  d30
    vmlal.u8        q10, d4,  d31
    vmlal.u8        q10, d6,  d31
    vmlsl.u8        q10, d16, d30

    vaddl.u8        q11, d1,  d19
    vmlsl.u8        q11, d3,  d30
    vmlal.u8        q11, d5,  d31
    vmlal.u8        q11, d7,  d31
    vmlsl.u8        q11, d17, d30

    vqrshrun.s16    d0,  q10, #5
    vst1.64         {d20-d21}, [r2,:128]!
    vqrshrun.s16    d1,  q11, #5
    vst1.64         {d22-d23}, [r2,:128]!
    vst1.64         {d0-d1},   [r0,:128]!
    bgt             filter_v_loop
    pop             {pc}
endfunc

// hpel_filter_c( uint8_t *dst, int16_t *buf, int width );
function x264_hpel_filter_c_neon
    sub             r1,  #16
    vld1.64         {d0-d3}, [r1,:128]!

    // unrolled 2x: 4% faster
filter_c_loop:
    subs            r2,  r2,  #16
    vld1.64         {d4-d7}, [r1,:128]!
    vext.16         q8,  q0,  q1,  #6
    vext.16         q12, q1,  q2,  #3
    vadd.s16        q8,  q8,  q12
    vext.16         q9,  q0,  q1,  #7
    vext.16         q11, q1,  q2,  #2
    vadd.s16        q9,  q9,  q11
    vext.16         q10, q1,  q2,  #1
    vext.16         q11, q1,  q2,  #6
    vadd.s16        q10, q1,  q10
    vsub.s16        q8,  q8,  q9    // a-b
    vext.16         q15, q2,  q3,  #3
    vsub.s16        q9,  q9,  q10   // b-c

    vext.16         q12, q1,  q2,  #7
    vshr.s16        q8,  q8,  #2    // (a-b)/4
    vadd.s16        q11, q11, q15
    vext.16         q14, q2,  q3,  #2
    vsub.s16        q8,  q8,  q9    // (a-b)/4-b+c
    vadd.s16        q12, q12, q14
    vext.16         q13, q2,  q3,  #1

    vshr.s16        q8,  q8,  #2    // ((a-b)/4-b+c)/4
    vadd.s16        q13, q2,  q13
    vadd.s16        q8,  q8,  q10   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16
    vsub.s16        q11, q11, q12   // a-b
    vsub.s16        q12, q12, q13   // b-c
    vshr.s16        q11, q11, #2    // (a-b)/4
    vqrshrun.s16    d30, q8,  #6
    vsub.s16        q11, q11, q12   // (a-b)/4-b+c
    vshr.s16        q11, q11, #2    // ((a-b)/4-b+c)/4
    vld1.64         {d0-d3}, [r1,:128]!
    vadd.s16        q11, q11, q13   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16

    vext.16         q8,  q2,  q3,  #6
    vqrshrun.s16    d31, q11,  #6
    vext.16         q12, q3,  q0,  #3
    vadd.s16        q8,  q8,  q12
    vext.16         q9,  q2,  q3,  #7
    vst1.64         {d30-d31}, [r0,:128]!
    bxle            lr
    subs            r2,  r2,  #16

    vext.16         q11, q3,  q0,  #2
    vadd.s16        q9,  q9,  q11
    vext.16         q10, q3,  q0,  #1
    vext.16         q11, q3,  q0,  #6
    vadd.s16        q10, q3,  q10
    vsub.s16        q8,  q8,  q9    // a-b
    vext.16         q15, q0,  q1,  #3
    vsub.s16        q9,  q9,  q10   // b-c

    vext.16         q12, q3,  q0,  #7
    vshr.s16        q8,  q8,  #2    // (a-b)/4
    vadd.s16        q11, q11, q15
    vext.16         q14, q0,  q1,  #2
    vsub.s16        q8,  q8,  q9    // (a-b)/4-b+c
    vadd.s16        q12, q12, q14
    vext.16         q13, q0,  q1,  #1

    vshr.s16        q8,  q8,  #2    // ((a-b)/4-b+c)/4
    vadd.s16        q13, q0,  q13
    vadd.s16        q8,  q8,  q10   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16
    vsub.s16        q11, q11, q12   // a-b
    vsub.s16        q12, q12, q13   // b-c
    vshr.s16        q11, q11, #2    // (a-b)/4
    vqrshrun.s16    d30, q8,  #6
    vsub.s16        q11, q11, q12   // (a-b)/4-b+c
    vshr.s16        q11, q11, #2    // ((a-b)/4-b+c)/4
    vadd.s16        q11, q11, q13   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16

    vqrshrun.s16    d31, q11,  #6
    vst1.64         {d30-d31}, [r0,:128]!
    bgt             filter_c_loop
    bx              lr
endfunc

// hpel_filter_h( uint8_t *dst, uint8_t *src, int width );
function x264_hpel_filter_h_neon
    sub             r1,  #16
    vmov.u8         d30, #5
    vld1.64         {d0-d3}, [r1,:128]!
    vmov.u8         d31, #20

    // unrolled 3x because it's 5% faster, due to mitigating
    // the high latency of multiplication and vqrshrun
filter_h_loop:
    subs            r2,  r2,  #16
    vld1.64         {d4-d5}, [r1,:128]!
    vext.8          q8,  q0,  q1,  #14
    vext.8          q12, q1,  q2,  #3
    vaddl.u8        q13, d16, d24
    vext.8          q9,  q0,  q1,  #15
    vaddl.u8        q14, d17, d25

    vext.8          q10, q1,  q2,  #1
    vmlal.u8        q13, d2,  d31
    vmlsl.u8        q13, d18, d30
    vext.8          q11, q1,  q2,  #2
    vmlal.u8        q13, d20, d31
    vmlsl.u8        q13, d22, d30

    vmlsl.u8        q14, d19, d30
    vmlal.u8        q14, d3,  d31
    vmlal.u8        q14, d21, d31
    vmlsl.u8        q14, d23, d30
    vqrshrun.s16    d6,  q13, #5

    vld1.64         {d0-d1}, [r1,:128]!
    vext.8          q8,  q1,  q2,  #14
    vext.8          q12, q2,  q0,  #3
    vaddl.u8        q13, d16, d24
    vqrshrun.s16    d7,  q14, #5
    vext.8          q9,  q1,  q2,  #15
    vaddl.u8        q14, d17, d25

    vst1.64         {d6-d7}, [r0,:128]!
    bxle            lr
    subs            r2,  r2,  #16

    vext.8          q10, q2,  q0,  #1
    vmlal.u8        q13, d4,  d31
    vmlsl.u8        q13, d18, d30
    vext.8          q11, q2,  q0,  #2
    vmlal.u8        q13, d20, d31
    vmlsl.u8        q13, d22, d30

    vmlsl.u8        q14, d19, d30
    vmlal.u8        q14, d5,  d31
    vmlal.u8        q14, d21, d31
    vmlsl.u8        q14, d23, d30
    vqrshrun.s16    d6,  q13, #5

    vld1.64         {d2-d3}, [r1,:128]!
    vext.8          q8,  q2,  q0,  #14
    vext.8          q12, q0,  q1,  #3
    vaddl.u8        q13, d16, d24
    vqrshrun.s16    d7,  q14, #5
    vext.8          q9,  q2,  q0,  #15
    vaddl.u8        q14, d17, d25

    vst1.64         {d6-d7}, [r0,:128]!
    bxle            lr
    subs            r2,  r2,  #16

    vext.8          q10, q0,  q1,  #1
    vmlal.u8        q13, d0,  d31
    vmlsl.u8        q13, d18, d30
    vext.8          q11, q0,  q1,  #2
    vmlal.u8        q13, d20, d31
    vmlsl.u8        q13, d22, d30

    vmlsl.u8        q14, d19, d30
    vmlal.u8        q14, d1,  d31
    vmlal.u8        q14, d21, d31
    vmlsl.u8        q14, d23, d30

    vqrshrun.s16    d6, q13, #5
    vqrshrun.s16    d7, q14, #5
    vst1.64         {d6-d7}, [r0,:128]!
    bgt             filter_h_loop
    bx              lr
endfunc


// frame_init_lowres_core( uint8_t *src0, uint8_t *dst0, uint8_t *dsth, uint8_t *dstv,
//                         uint8_t *dstc, intptr_t src_stride, intptr_t dst_stride, int width,
//                         int height )
function x264_frame_init_lowres_core_neon
    push            {r4-r10,lr}
    vpush           {d8-d15}
    ldrd            r4,  r5,  [sp, #96]
    ldrd            r6,  r7,  [sp, #104]
    ldr             lr,  [sp, #112]
    sub             r10, r6,  r7            // dst_stride - width
    and             r10, r10, #~15

lowres_yloop:
    mov             ip,  r7                 // width
    mov             r6,  r0                 // src0
    add             r8,  r0,  r5            // src1 = src0 + src_stride
    add             r9,  r0,  r5,  lsl #1   // src2 = src1 + src_stride

    vld2.8          {d8, d10}, [r6,:128]!
    vld2.8          {d12,d14}, [r8,:128]!
    vld2.8          {d16,d18}, [r9,:128]!

lowres_xloop:
    subs            ip,  ip,  #16

    vld2.8          {d9, d11}, [r6,:128]!
    vld2.8          {d13,d15}, [r8,:128]!
    vrhadd.u8       q0,  q4,  q6
    vld2.8          {d17,d19}, [r9,:128]!
    vrhadd.u8       q5,  q5,  q7
    vld2.8          {d20,d22}, [r6,:128]!
    vrhadd.u8       q1,  q6,  q8
    vld2.8          {d24,d26}, [r8,:128]!
    vrhadd.u8       q7,  q7,  q9
    vext.8          q4,  q4,  q10, #1
    vrhadd.u8       q0,  q0,  q5
    vext.8          q6,  q6,  q12, #1
    vrhadd.u8       q1,  q1,  q7
    vld2.8          {d28,d30}, [r9,:128]!
    vrhadd.u8       q4,  q4,  q6
    vext.8          q8,  q8,  q14, #1
    vrhadd.u8       q6,  q6,  q8
    vst1.64         {d0-d1},   [r1,:128]!
    vrhadd.u8       q2,  q4,  q5
    vst1.64         {d2-d3},   [r3,:128]!
    vrhadd.u8       q3,  q6,  q7
    vst1.64         {d4-d5},   [r2,:128]!
    vst1.64         {d6-d7},   [r4,:128]!

    ble             lowres_xloop_end
    subs            ip,  ip,  #16

    vld2.8          {d21,d23}, [r6,:128]!
    vld2.8          {d25,d27}, [r8,:128]!
    vrhadd.u8       q0,  q10, q12
    vld2.8          {d29,d31}, [r9,:128]!
    vrhadd.u8       q11, q11, q13
    vld2.8          {d8, d10}, [r6,:128]!
    vrhadd.u8       q1,  q12, q14
    vld2.8          {d12,d14}, [r8,:128]!
    vrhadd.u8       q13, q13, q15
    vext.8          q10, q10, q4,  #1
    vrhadd.u8       q0,  q0,  q11
    vext.8          q12, q12, q6,  #1
    vrhadd.u8       q1,  q1,  q13
    vld2.8          {d16,d18}, [r9,:128]!
    vrhadd.u8       q10, q10, q12
    vext.8          q14, q14, q8,  #1
    vrhadd.u8       q12, q12, q14
    vst1.64         {d0-d1},   [r1,:128]!
    vrhadd.u8       q2,  q10, q11
    vst1.64         {d2-d3},   [r3,:128]!
    vrhadd.u8       q3,  q12, q13
    vst1.64         {d4-d5},   [r2,:128]!
    vst1.64         {d6-d7},   [r4,:128]!

    bgt             lowres_xloop

lowres_xloop_end:
    subs            lr,  lr,  #1
    add             r0,  r0,  r5,  lsl #1
    add             r1,  r1,  r10
    add             r2,  r2,  r10
    add             r3,  r3,  r10
    add             r4,  r4,  r10
    bgt             lowres_yloop

    vpop            {d8-d15}
    pop             {r4-r10,pc}
endfunc

function x264_load_deinterleave_chroma_fdec_neon
    mov             ip,  #FDEC_STRIDE/2
1:
    vld2.8          {d0-d1}, [r1,:128], r2
    subs            r3,  r3,  #1
    pld             [r1]
    vst1.8          {d0},    [r0,:64], ip
    vst1.8          {d1},    [r0,:64], ip
    bgt             1b

    bx              lr
endfunc

function x264_load_deinterleave_chroma_fenc_neon
    mov             ip,  #FENC_STRIDE/2
1:
    vld2.8          {d0-d1}, [r1,:128], r2
    subs            r3,  r3,  #1
    pld             [r1]
    vst1.8          {d0},    [r0,:64], ip
    vst1.8          {d1},    [r0,:64], ip
    bgt             1b

    bx              lr
endfunc

function x264_plane_copy_neon
    push            {r4,lr}
    ldr             r4,  [sp, #8]
    ldr             lr,  [sp, #12]
    add             r12, r4,  #15
    bic             r4,  r12, #15
    sub             r1,  r1,  r4
    sub             r3,  r3,  r4
1:
    mov             r12, r4
16:
    tst             r12, #16
    beq             32f
    subs            r12, r12, #16
    vld1.8          {q0}, [r2]!
    vst1.8          {q0}, [r0]!
    beq             0f
32:
    subs            r12, r12, #32
    vld1.8          {q0, q1}, [r2]!
    vst1.8          {q0, q1}, [r0]!
    bgt             32b
0:
    subs            lr,  lr,  #1
    add             r2,  r2,  r3
    add             r0,  r0,  r1
    bgt             1b

    pop             {r4,pc}
endfunc

function x264_plane_copy_deinterleave_neon
    push            {r4-r7, lr}
    ldrd            r6, r7, [sp, #28]
    ldrd            r4, r5, [sp, #20]
    add             lr,  r6,  #15
    bic             lr,  lr,  #15
    sub             r1,  r1,  lr
    sub             r3,  r3,  lr
    sub             r5,  r5,  lr, lsl #1
block:
    vld2.8          {d0-d3}, [r4,:128]!
    subs            lr,  lr,  #16
    vst1.8          {q0},    [r0]!
    vst1.8          {q1},    [r2]!
    bgt             block

    add             r4,  r4,  r5
    subs            r7,  r7,  #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    mov             lr,  r6
    bgt             block

    pop             {r4-r7, pc}
endfunc

function x264_plane_copy_deinterleave_rgb_neon
    push            {r4-r8, r10, r11, lr}
    ldrd            r4,  r5,  [sp, #32]
    ldrd            r6,  r7,  [sp, #40]
    ldr             r8,  [sp, #48]
    ldrd            r10, r11, [sp, #52]
    add             lr,  r10, #7
    subs            r8,  r8,  #3
    bic             lr,  lr,  #7
    sub             r7,  r7,  lr, lsl #1
    sub             r1,  r1,  lr
    sub             r3,  r3,  lr
    sub             r5,  r5,  lr
    subne           r7,  r7,  lr, lsl #1
    subeq           r7,  r7,  lr
    bne             block4
block3:
    vld3.8          {d0,d1,d2}, [r6]!
    subs            lr,  lr,  #8
    vst1.8          {d0},    [r0]!
    vst1.8          {d1},    [r2]!
    vst1.8          {d2},    [r4]!
    bgt             block3

    subs            r11, r11, #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    add             r4,  r4,  r5
    add             r6,  r6,  r7
    mov             lr,  r10
    bgt             block3

    pop             {r4-r8, r10, r11, pc}
block4:
    vld4.8          {d0,d1,d2,d3}, [r6]!
    subs            lr,  lr,  #8
    vst1.8          {d0},    [r0]!
    vst1.8          {d1},    [r2]!
    vst1.8          {d2},    [r4]!
    bgt             block4

    subs            r11, r11, #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    add             r4,  r4,  r5
    add             r6,  r6,  r7
    mov             lr,  r10
    bgt             block4

    pop             {r4-r8, r10, r11, pc}
endfunc

function x264_plane_copy_interleave_neon
    push            {r4-r7, lr}
    ldrd            r6, r7, [sp, #28]
    ldrd            r4, r5, [sp, #20]
    add             lr,  r6,  #15
    bic             lr,  lr,  #15
    sub             r1,  r1,  lr, lsl #1
    sub             r3,  r3,  lr
    sub             r5,  r5,  lr
blocki:
    vld1.8          {q0}, [r2]!
    vld1.8          {q1}, [r4]!
    subs            lr,  lr,  #16
    vst2.8          {d0,d2}, [r0]!
    vst2.8          {d1,d3}, [r0]!
    bgt             blocki

    subs            r7,  r7,  #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    add             r4,  r4,  r5
    mov             lr,  r6
    bgt             blocki

    pop             {r4-r7, pc}
endfunc

function x264_plane_copy_swap_neon
    push            {r4-r5, lr}
    ldrd            r4, r5, [sp, #12]
    add             lr,  r4,  #15
    bic             lr,  lr,  #15
    sub             r1,  r1,  lr, lsl #1
    sub             r3,  r3,  lr, lsl #1
1:
    vld1.8          {q0, q1}, [r2]!
    subs            lr,  lr,  #16
    vrev16.8        q0,  q0
    vrev16.8        q1,  q1
    vst1.8          {q0, q1}, [r0]!
    bgt             1b

    subs            r5,  r5,  #1
    add             r0,  r0,  r1
    add             r2,  r2,  r3
    mov             lr,  r4
    bgt             1b

    pop             {r4-r5, pc}
endfunc

function x264_store_interleave_chroma_neon
    push            {lr}
    ldr             lr,  [sp, #4]
    mov             ip,  #FDEC_STRIDE
1:
    vld1.8          {d0}, [r2], ip
    vld1.8          {d1}, [r3], ip
    subs            lr,  lr,  #1
    vst2.8          {d0,d1}, [r0,:128], r1
    bgt             1b

    pop             {pc}
endfunc

.macro integral4h p1, p2
    vext.8          d1,  \p1, \p2,  #1
    vext.8          d2,  \p1, \p2,  #2
    vext.8          d3,  \p1, \p2,  #3
    vaddl.u8        q0,  \p1, d1
    vaddl.u8        q1,  d2,  d3
    vadd.u16        q0,  q0,  q1
    vadd.u16        q0,  q0,  q2
.endm

function integral_init4h_neon
    sub             r3,  r0,  r2, lsl #1
    vld1.8          {d6, d7}, [r1, :128]!
1:
    subs            r2,  r2,  #16
    vld1.16         {q2},  [r3, :128]!
    integral4h      d6, d7
    vld1.8          {d6},  [r1, :64]!
    vld1.16         {q2},  [r3, :128]!
    vst1.16         {q0},  [r0, :128]!
    integral4h      d7, d6
    vld1.8          {d7},  [r1, :64]!
    vst1.16         {q0},  [r0, :128]!
    bgt             1b
    bx              lr
endfunc

.macro integral8h p1, p2, s
    vext.8          d1,  \p1,  \p2,  #1
    vext.8          d2,  \p1,  \p2,  #2
    vext.8          d3,  \p1,  \p2,  #3
    vext.8          d4,  \p1,  \p2,  #4
    vext.8          d5,  \p1,  \p2,  #5
    vext.8          d6,  \p1,  \p2,  #6
    vext.8          d7,  \p1,  \p2,  #7
    vaddl.u8        q0,  \p1,  d1
    vaddl.u8        q1,  d2,   d3
    vaddl.u8        q2,  d4,   d5
    vaddl.u8        q3,  d6,   d7
    vadd.u16        q0,  q0,   q1
    vadd.u16        q2,  q2,   q3
    vadd.u16        q0,  q0,   q2
    vadd.u16        q0,  q0,   \s
.endm

function integral_init8h_neon
    sub             r3,  r0,  r2, lsl #1
    vld1.8          {d16, d17}, [r1, :128]!
1:
    subs            r2,  r2,  #16
    vld1.16         {q9},  [r3, :128]!
    integral8h      d16, d17, q9
    vld1.8          {d16}, [r1, :64]!
    vld1.16         {q9},  [r3, :128]!
    vst1.16         {q0},  [r0, :128]!
    integral8h      d17, d16, q9
    vld1.8          {d17}, [r1, :64]!
    vst1.16         {q0},  [r0, :128]!
    bgt             1b
    bx              lr
endfunc

function integral_init4v_neon
    push            {r4-r5}
    mov             r3,   r0
    add             r4,   r0,   r2,  lsl #3
    add             r5,   r0,   r2,  lsl #4
    sub             r2,   r2,   #8
    vld1.16         {q11, q12}, [r3]!
    vld1.16         {q8,  q9},  [r5]!
    vld1.16         {q13}, [r3]!
    vld1.16         {q10}, [r5]!
1:
    subs            r2,   r2,   #16
    vld1.16         {q14, q15}, [r4]!
    vext.8          q0,   q11,  q12, #8
    vext.8          q1,   q12,  q13, #8
    vext.8          q2,   q8,   q9,  #8
    vext.8          q3,   q9,   q10, #8
    vsub.u16        q14,  q14,  q11
    vsub.u16        q15,  q15,  q12
    vadd.u16        q0,   q0,   q11
    vadd.u16        q1,   q1,   q12
    vadd.u16        q2,   q2,   q8
    vadd.u16        q3,   q3,   q9
    vst1.16         {q14},  [r1]!
    vst1.16         {q15},  [r1]!
    vmov            q11,  q13
    vmov            q8,   q10
    vsub.u16        q0,   q2,   q0
    vsub.u16        q1,   q3,   q1
    vld1.16         {q12, q13}, [r3]!
    vld1.16         {q9,  q10}, [r5]!
    vst1.16         {q0}, [r0]!
    vst1.16         {q1}, [r0]!
    bgt             1b
2:
    pop             {r4-r5}
    bx              lr
endfunc

function integral_init8v_neon
    add             r2,  r0,  r1,  lsl #4
    sub             r1,  r1,  #8
    ands            r3,  r1,  #16 - 1
    beq             1f
    subs            r1,  r1,  #8
    vld1.16         {q0}, [r0]
    vld1.16         {q2}, [r2]!
    vsub.u16        q8,  q2,  q0
    vst1.16         {q8}, [r0]!
    ble             2f
1:
    subs            r1,  r1,  #16
    vld1.16         {q0, q1}, [r0]
    vld1.16         {q2, q3}, [r2]!
    vsub.u16        q8,  q2,  q0
    vsub.u16        q9,  q3,  q1
    vst1.16         {q8},  [r0]!
    vst1.16         {q9},  [r0]!
    bgt             1b
2:
    bx              lr
endfunc

function x264_mbtree_propagate_cost_neon
    push            {r4-r5,lr}
    ldrd            r4, r5, [sp, #12]
    ldr             lr, [sp, #20]
    vld1.32         {d6[], d7[]},  [r5]
8:
    subs            lr,  lr,  #8
    vld1.16         {q8},  [r1]!
    vld1.16         {q9},  [r2]!
    vld1.16         {q10}, [r3]!
    vld1.16         {q11}, [r4]!
    vbic.u16        q10, #0xc000
    vmin.u16        q10, q9,  q10
    vmull.u16       q12, d18, d22           @ propagate_intra
    vmull.u16       q13, d19, d23           @ propagate_intra
    vsubl.u16       q14, d18, d20           @ propagate_num
    vsubl.u16       q15, d19, d21           @ propagate_num
    vmovl.u16       q10, d18                @ propagate_denom
    vmovl.u16       q11, d19                @ propagate_denom
    vmovl.u16       q9,  d17
    vmovl.u16       q8,  d16
    vcvt.f32.s32    q12, q12
    vcvt.f32.s32    q13, q13
    vcvt.f32.s32    q14, q14
    vcvt.f32.s32    q15, q15
    vcvt.f32.s32    q10, q10
    vcvt.f32.s32    q11, q11
    vrecpe.f32      q0,  q10
    vrecpe.f32      q1,  q11
    vcvt.f32.s32    q8,  q8
    vcvt.f32.s32    q9,  q9
    vrecps.f32      q10, q0,  q10
    vrecps.f32      q11, q1,  q11
    vmla.f32        q8,  q12, q3            @ propagate_amount
    vmla.f32        q9,  q13, q3            @ propagate_amount
    vmul.f32        q0,  q0,  q10
    vmul.f32        q1,  q1,  q11
    vmul.f32        q8,  q8,  q14
    vmul.f32        q9,  q9,  q15
    vmul.f32        q0,  q8,  q0
    vmul.f32        q1,  q9,  q1
    vcvt.s32.f32    q0,  q0
    vcvt.s32.f32    q1,  q1
    vqmovn.s32      d0,  q0
    vqmovn.s32      d1,  q1
    vst1.16         {q0},  [r0]!
    bgt             8b
    pop             {r4-r5,pc}
endfunc

function x264_mbtree_propagate_list_internal_neon
    vld2.16         {d4[], d5[]}, [sp]      @ bipred_weight, mb_y
    movrel          r12, pw_0to15
    vmov.u16        q10, #0xc000
    vld1.16         {q0},  [r12, :128]      @h->mb.i_mb_x,h->mb.i_mb_y
    vmov.u32        q11, #4
    vmov.u8         q3,  #32
    vdup.u16        q8,  d5[0]              @ mb_y
    vzip.u16        q0,  q8
    ldr             r12, [sp, #8]
8:
    subs            r12, r12,  #8
    vld1.16         {q14},  [r1, :128]!      @ propagate_amount
    vld1.16         {q15},  [r2, :128]!      @ lowres_cost
    vld1.16         {q8, q9},  [r0, :128]!
    vand            q15, q15, q10
    vceq.u16        q1,  q15, q10
    vmull.u16       q12, d28, d4
    vmull.u16       q13, d29, d4
    vrshrn.u32      d30, q12, #6
    vrshrn.u32      d31, q13, #6
    vbsl            q1,  q15, q14           @ if( lists_used == 3 )
    @ propagate_amount = (propagate_amount * bipred_weight + 32) >> 6
    vshr.s16        q12, q8,  #5
    vshr.s16        q13, q9,  #5
    vuzp.16         q8,  q9                 @ x & 31, y & 31
    vadd.s16        q12, q12, q0
    vadd.s16        q0,  q0,  q11
    vmovn.i16       d16, q8
    vmovn.i16       d17, q9
    vadd.s16        q13, q13, q0
    vbic.i16        q8,  #128+64+32
    vadd.s16        q0,  q0,  q11
    vbic.i16        q8,  #(128+64+32)<<8
    vst1.16         {q12, q13},  [r3, :128]!
    vsub.i8         q9,  q3,  q8
    vmull.u8        q12, d17, d16           @ idx3weight = y*x
    vmull.u8        q14, d19, d16           @ idx1weight = (32-y)*x
    vmull.u8        q15, d19, d18           @ idx0weight = (32-y)*(32-x)
    vmull.u8        q13, d17, d18           @ idx2weight = y*(32-x)
    vmull.u16       q9,  d28, d2            @ idx1weight
    vmull.u16       q8,  d29, d3
    vmull.u16       q14, d30, d2            @ idx0weight
    vmull.u16       q15, d31, d3
    vrshrn.u32      d18, q9,  #10           @ idx1weight
    vrshrn.u32      d19, q8,  #10
    vrshrn.u32      d16, q14, #10           @ idx0weight
    vrshrn.u32      d17, q15, #10
    vmull.u16       q14, d24, d2            @ idx3weight
    vmull.u16       q15, d25, d3
    vzip.16         q8,  q9
    vmull.u16       q12, d26, d2            @ idx2weight
    vmull.u16       q13, d27, d3
    vst1.16         {q8, q9},   [r3, :128]!
    vrshrn.u32      d19, q15, #10           @ idx3weight
    vrshrn.u32      d18, q14, #10
    vrshrn.u32      d16, q12, #10           @ idx2weight
    vrshrn.u32      d17, q13, #10
    vzip.16         q8,  q9
    vst1.16         {q8, q9},   [r3, :128]!
    bge             8b
    bx              lr
endfunc



#elif defined(__arm64__)


// note: prefetch stuff assumes 64-byte cacheline

// void prefetch_ref( uint8_t *pix, intptr_t stride, int parity )
function x264_prefetch_ref_aarch64, export=1
    cmp         w2,  #1
    csel        x2,  xzr, x1, eq
    add         x0,  x0,  #64
    add         x0,  x0,  x2,  lsl #3

    lsl         x2,  x1,  #1
    add         x3,  x1,  x1,  lsl #1
    add         x4,  x0,  x1,  lsl #2

    prfm        pldl1strm, [x0]
    prfm        pldl1strm, [x0,  x1]
    prfm        pldl1strm, [x0,  x2]
    prfm        pldl1strm, [x0,  x3]
    prfm        pldl1strm, [x4]
    prfm        pldl1strm, [x4,  x1]
    prfm        pldl1strm, [x4,  x2]
    prfm        pldl1strm, [x4,  x3]
    ret
endfunc

// void prefetch_fenc( uint8_t *pix_y,  intptr_t stride_y,
//                     uint8_t *pix_uv, intptr_t stride_uv, int mb_x )
.macro x264_prefetch_fenc sub
function x264_prefetch_fenc_\sub\()_aarch64, export=1
    and         w6,  w5,  #3
    and         w7,  w5,  #3
    mul         x6,  x6,  x1
    mul         x7,  x7,  x3
    add         x0,  x0,  #64
    add         x2,  x2,  #64

    add         x0,  x0,  x6,  lsl #2
    add         x6,  x0,  x1,  lsl #1
    prfm        pldl1strm, [x0]
    prfm        pldl1strm, [x0,  x1]
    prfm        pldl1strm, [x6]
    prfm        pldl1strm, [x6, x1]

    add         x2,  x2,  x7,  lsl #1
    prfm        pldl1strm, [x2]
    prfm        pldl1strm, [x2,  x3]
.ifc \sub, 422
    add         x7,  x2,  x3,  lsl #1
    prfm        pldl1strm, [x7]
    prfm        pldl1strm, [x7,  x3]
.endif
    ret
endfunc
.endm

x264_prefetch_fenc 420
x264_prefetch_fenc 422

// void pixel_avg( uint8_t *dst,  intptr_t dst_stride,
//                 uint8_t *src1, intptr_t src1_stride,
//                 uint8_t *src2, intptr_t src2_stride, int weight );
.macro AVGH w h
function x264_pixel_avg_\w\()x\h\()_neon, export=1
    mov         w10, #64
    cmp         w6,  #32
    mov         w9, #\h
    b.eq        pixel_avg_w\w\()_neon
    subs        w7,  w10,  w6
    b.lt        pixel_avg_weight_w\w\()_add_sub_neon     // weight > 64
    cmp         w6,  #0
    b.ge        pixel_avg_weight_w\w\()_add_add_neon
    b           pixel_avg_weight_w\w\()_sub_add_neon     // weight < 0
endfunc
.endm

AVGH  4, 2
AVGH  4, 4
AVGH  4, 8
AVGH  4, 16
AVGH  8, 4
AVGH  8, 8
AVGH  8, 16
AVGH 16, 8
AVGH 16, 16

// 0 < weight < 64
.macro load_weights_add_add
    mov         w6,  w6
.endm
.macro weight_add_add dst, s1, s2, h=
.ifc \h, 2
    umull2      \dst, \s1, v30.16b
    umlal2      \dst, \s2, v31.16b
.else
    umull       \dst, \s1, v30.8b
    umlal       \dst, \s2, v31.8b
.endif
.endm

// weight > 64
.macro load_weights_add_sub
    neg         w7,  w7
.endm
.macro weight_add_sub dst, s1, s2, h=
.ifc \h, 2
    umull2      \dst, \s1, v30.16b
    umlsl2      \dst, \s2, v31.16b
.else
    umull       \dst, \s1, v30.8b
    umlsl       \dst, \s2, v31.8b
.endif
.endm

// weight < 0
.macro load_weights_sub_add
    neg         w6,  w6
.endm
.macro weight_sub_add dst, s1, s2, h=
.ifc \h, 2
    umull2      \dst, \s2, v31.16b
    umlsl2      \dst, \s1, v30.16b
.else
    umull       \dst, \s2, v31.8b
    umlsl       \dst, \s1, v30.8b
.endif
.endm

.macro AVG_WEIGHT ext
function pixel_avg_weight_w4_\ext\()_neon
    load_weights_\ext
    dup         v30.8b, w6
    dup         v31.8b, w7
1:  // height loop
    subs        w9,  w9,  #2
    ld1        {v0.s}[0], [x2], x3
    ld1        {v1.s}[0], [x4], x5
    weight_\ext v4.8h,  v0.8b,  v1.8b
    ld1        {v2.s}[0], [x2], x3
    ld1        {v3.s}[0], [x4], x5
    sqrshrun    v0.8b,  v4.8h,  #6
    weight_\ext v5.8h,  v2.8b,  v3.8b
    st1        {v0.s}[0], [x0], x1
    sqrshrun    v1.8b,  v5.8h,  #6
    st1        {v1.s}[0], [x0], x1
    b.gt        1b
    ret
endfunc

function pixel_avg_weight_w8_\ext\()_neon
    load_weights_\ext
    dup         v30.8b, w6
    dup         v31.8b, w7
1:  // height loop
    subs        w9,  w9,  #4
    ld1        {v0.8b}, [x2], x3
    ld1        {v1.8b}, [x4], x5
    weight_\ext v16.8h, v0.8b,  v1.8b
    ld1        {v2.8b}, [x2], x3
    ld1        {v3.8b}, [x4], x5
    weight_\ext v17.8h, v2.8b,  v3.8b
    ld1        {v4.8b}, [x2], x3
    ld1        {v5.8b}, [x4], x5
    weight_\ext v18.8h, v4.8b,  v5.8b
    ld1        {v6.8b}, [x2], x3
    ld1        {v7.8b}, [x4], x5
    weight_\ext v19.8h, v6.8b,  v7.8b
    sqrshrun    v0.8b,  v16.8h, #6
    sqrshrun    v1.8b,  v17.8h, #6
    sqrshrun    v2.8b,  v18.8h, #6
    sqrshrun    v3.8b,  v19.8h, #6
    st1        {v0.8b}, [x0], x1
    st1        {v1.8b}, [x0], x1
    st1        {v2.8b}, [x0], x1
    st1        {v3.8b}, [x0], x1
    b.gt        1b
    ret
endfunc

function pixel_avg_weight_w16_\ext\()_neon
    load_weights_\ext
    dup         v30.16b, w6
    dup         v31.16b, w7
1:  // height loop
    subs        w9,  w9,  #2
    ld1        {v0.16b}, [x2], x3
    ld1        {v1.16b}, [x4], x5
    weight_\ext v16.8h, v0.8b,  v1.8b
    weight_\ext v17.8h, v0.16b, v1.16b, 2
    ld1        {v2.16b}, [x2], x3
    ld1        {v3.16b}, [x4], x5
    weight_\ext v18.8h, v2.8b,  v3.8b
    weight_\ext v19.8h, v2.16b, v3.16b, 2
    sqrshrun    v0.8b,  v16.8h, #6
    sqrshrun    v1.8b,  v18.8h, #6
    sqrshrun2   v0.16b, v17.8h, #6
    sqrshrun2   v1.16b, v19.8h, #6
    st1        {v0.16b}, [x0], x1
    st1        {v1.16b}, [x0], x1
    b.gt        1b
    ret
endfunc
.endm

AVG_WEIGHT add_add
AVG_WEIGHT add_sub
AVG_WEIGHT sub_add

function pixel_avg_w4_neon
1:  subs        w9,  w9,  #2
    ld1        {v0.s}[0], [x2], x3
    ld1        {v2.s}[0], [x4], x5
    urhadd      v0.8b,  v0.8b,  v2.8b
    ld1        {v1.s}[0], [x2], x3
    ld1        {v3.s}[0], [x4], x5
    urhadd      v1.8b,  v1.8b,  v3.8b
    st1        {v0.s}[0], [x0], x1
    st1        {v1.s}[0], [x0], x1
    b.gt        1b
    ret
endfunc

function pixel_avg_w8_neon
1:  subs        w9,  w9,  #4
    ld1        {v0.8b}, [x2], x3
    ld1        {v1.8b}, [x4], x5
    ld1        {v2.8b}, [x2], x3
    urhadd      v0.8b,  v0.8b,  v1.8b
    ld1        {v3.8b}, [x4], x5
    st1        {v0.8b}, [x0], x1
    ld1        {v4.8b}, [x2], x3
    urhadd      v1.8b,  v2.8b,  v3.8b
    ld1        {v5.8b}, [x4], x5
    st1        {v1.8b}, [x0], x1
    ld1        {v6.8b}, [x2], x3
    ld1        {v7.8b}, [x4], x5
    urhadd      v2.8b,  v4.8b,  v5.8b
    urhadd      v3.8b,  v6.8b,  v7.8b
    st1        {v2.8b}, [x0], x1
    st1        {v3.8b}, [x0], x1
    b.gt        1b
    ret
endfunc

function pixel_avg_w16_neon
1:  subs        w9,  w9,  #4
    ld1        {v0.16b}, [x2], x3
    ld1        {v1.16b}, [x4], x5
    ld1        {v2.16b}, [x2], x3
    urhadd      v0.16b, v0.16b, v1.16b
    ld1        {v3.16b}, [x4], x5
    st1        {v0.16b}, [x0], x1
    ld1        {v4.16b}, [x2], x3
    urhadd      v1.16b, v2.16b, v3.16b
    ld1        {v5.16b}, [x4], x5
    st1        {v1.16b}, [x0], x1
    ld1        {v6.16b}, [x2], x3
    ld1        {v7.16b}, [x4], x5
    urhadd      v2.16b, v4.16b, v5.16b
    urhadd      v3.16b, v6.16b, v7.16b
    st1        {v2.16b}, [x0], x1
    st1        {v3.16b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_pixel_avg2_w4_neon, export=1
1:
    subs        w5,  w5,  #2
    ld1        {v0.s}[0],  [x2], x3
    ld1        {v2.s}[0],  [x4], x3
    urhadd      v0.8b,  v0.8b,  v2.8b
    ld1        {v1.s}[0],  [x2], x3
    ld1        {v3.s}[0],  [x4], x3
    urhadd      v1.8b,  v1.8b,  v3.8b
    st1        {v0.s}[0], [x0], x1
    st1        {v1.s}[0], [x0], x1
    b.gt        1b
    ret
endfunc

function x264_pixel_avg2_w8_neon, export=1
1:
    subs        w5,  w5,  #2
    ld1        {v0.8b}, [x2], x3
    ld1        {v2.8b}, [x4], x3
    urhadd      v0.8b,  v0.8b,  v2.8b
    ld1        {v1.8b}, [x2], x3
    ld1        {v3.8b}, [x4], x3
    urhadd      v1.8b,  v1.8b,  v3.8b
    st1        {v0.8b}, [x0], x1
    st1        {v1.8b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_pixel_avg2_w16_neon, export=1
1:
    subs        w5,  w5,  #2
    ld1        {v0.16b}, [x2], x3
    ld1        {v2.16b}, [x4], x3
    urhadd      v0.16b, v0.16b, v2.16b
    ld1        {v1.16b}, [x2], x3
    ld1        {v3.16b}, [x4], x3
    urhadd      v1.16b, v1.16b, v3.16b
    st1        {v0.16b}, [x0], x1
    st1        {v1.16b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_pixel_avg2_w20_neon, export=1
    sub         x1,  x1,  #16
1:
    subs        w5,  w5,  #2
    ld1        {v0.16b,v1.16b}, [x2], x3
    ld1        {v2.16b,v3.16b}, [x4], x3
    urhadd      v0.16b, v0.16b, v2.16b
    urhadd      v1.8b,  v1.8b,  v3.8b
    ld1        {v4.16b,v5.16b}, [x2], x3
    ld1        {v6.16b,v7.16b}, [x4], x3
    urhadd      v4.16b, v4.16b, v6.16b
    urhadd      v5.8b,  v5.8b,  v7.8b
    st1        {v0.16b},  [x0], #16
    st1        {v1.s}[0], [x0], x1
    st1        {v4.16b},  [x0], #16
    st1        {v5.s}[0], [x0], x1
    b.gt        1b
    ret
endfunc

.macro weight_prologue type
    mov         w9,  w5                 // height
.ifc \type, full
    ldr         w12, [x4, #32]          // denom
.endif
    ldp         w4,  w5,  [x4, #32+4]   // scale, offset
    dup         v0.16b, w4
    dup         v1.8h,  w5
.ifc \type, full
    neg         w12, w12
    dup         v2.8h,  w12
.endif
.endm

// void mc_weight( uint8_t *src, intptr_t src_stride, uint8_t *dst,
//                 intptr_t dst_stride, const x264_weight_t *weight, int h )
function x264_mc_weight_w20_neon, export=1
    weight_prologue full
    sub         x1,  x1,  #16
1:
    subs        w9,  w9,  #2
    ld1        {v16.8b,v17.8b,v18.8b}, [x2], x3
    ld1        {v19.8b,v20.8b,v21.8b}, [x2], x3
    umull       v22.8h, v16.8b, v0.8b
    umull       v23.8h, v17.8b, v0.8b
    zip1        v18.2s, v18.2s, v21.2s
    umull       v25.8h, v19.8b, v0.8b
    umull       v26.8h, v20.8b, v0.8b
    umull       v24.8h, v18.8b, v0.8b
    srshl       v22.8h, v22.8h, v2.8h
    srshl       v23.8h, v23.8h, v2.8h
    srshl       v24.8h, v24.8h, v2.8h
    srshl       v25.8h, v25.8h, v2.8h
    srshl       v26.8h, v26.8h, v2.8h
    add         v22.8h, v22.8h, v1.8h
    add         v23.8h, v23.8h, v1.8h
    add         v24.8h, v24.8h, v1.8h
    add         v25.8h, v25.8h, v1.8h
    add         v26.8h, v26.8h, v1.8h
    sqxtun      v4.8b,  v22.8h
    sqxtun2     v4.16b, v23.8h
    sqxtun      v6.8b,  v24.8h
    sqxtun      v5.8b,  v25.8h
    sqxtun2     v5.16b, v26.8h
    st1        {v4.16b},  [x0], #16
    st1        {v6.s}[0], [x0], x1
    st1        {v5.16b},  [x0], #16
    st1        {v6.s}[1], [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w16_neon, export=1
    weight_prologue full
weight16_loop:
1:
    subs        w9,  w9,  #2
    ld1        {v4.16b}, [x2], x3
    ld1        {v5.16b}, [x2], x3
    umull       v22.8h, v4.8b,  v0.8b
    umull2      v23.8h, v4.16b, v0.16b
    umull       v24.8h, v5.8b,  v0.8b
    umull2      v25.8h, v5.16b, v0.16b
    srshl       v22.8h, v22.8h, v2.8h
    srshl       v23.8h, v23.8h, v2.8h
    srshl       v24.8h, v24.8h, v2.8h
    srshl       v25.8h, v25.8h, v2.8h
    add         v22.8h, v22.8h, v1.8h
    add         v23.8h, v23.8h, v1.8h
    add         v24.8h, v24.8h, v1.8h
    add         v25.8h, v25.8h, v1.8h
    sqxtun      v4.8b,  v22.8h
    sqxtun2     v4.16b, v23.8h
    sqxtun      v5.8b,  v24.8h
    sqxtun2     v5.16b, v25.8h
    st1        {v4.16b}, [x0], x1
    st1        {v5.16b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w8_neon, export=1
    weight_prologue full
1:
    subs        w9,  w9,  #2
    ld1        {v16.8b}, [x2], x3
    ld1        {v17.8b}, [x2], x3
    umull       v4.8h,  v16.8b, v0.8b
    umull       v5.8h,  v17.8b, v0.8b
    srshl       v4.8h,  v4.8h,  v2.8h
    srshl       v5.8h,  v5.8h,  v2.8h
    add         v4.8h,  v4.8h,  v1.8h
    add         v5.8h,  v5.8h,  v1.8h
    sqxtun      v16.8b, v4.8h
    sqxtun      v17.8b, v5.8h
    st1        {v16.8b}, [x0], x1
    st1        {v17.8b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w4_neon, export=1
    weight_prologue full
1:
    subs        w9,  w9,  #2
    ld1        {v16.s}[0], [x2], x3
    ld1        {v16.s}[1], [x2], x3
    umull       v4.8h,  v16.8b, v0.8b
    srshl       v4.8h,  v4.8h,  v2.8h
    add         v4.8h,  v4.8h,  v1.8h
    sqxtun      v16.8b, v4.8h
    st1        {v16.s}[0], [x0], x1
    st1        {v16.s}[1], [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w20_nodenom_neon, export=1
    weight_prologue nodenom
    sub         x1,  x1,  #16
1:
    subs        w9,  w9,  #2
    ld1        {v16.8b,v17.8b,v18.8b}, [x2], x3
    mov         v27.16b, v1.16b
    mov         v28.16b, v1.16b
    ld1        {v19.8b,v20.8b,v21.8b}, [x2], x3
    mov         v31.16b, v1.16b
    mov         v29.16b, v1.16b
    mov         v30.16b, v1.16b
    zip1        v18.2s, v18.2s, v21.2s
    umlal       v27.8h, v16.8b, v0.8b
    umlal       v28.8h, v17.8b, v0.8b
    umlal       v31.8h, v18.8b, v0.8b
    umlal       v29.8h, v19.8b, v0.8b
    umlal       v30.8h, v20.8b, v0.8b
    sqxtun      v4.8b,  v27.8h
    sqxtun2     v4.16b, v28.8h
    sqxtun      v5.8b,  v29.8h
    sqxtun2     v5.16b, v30.8h
    sqxtun      v6.8b,  v31.8h
    st1        {v4.16b},  [x0], #16
    st1        {v6.s}[0], [x0], x1
    st1        {v5.16b},  [x0], #16
    st1        {v6.s}[1], [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w16_nodenom_neon, export=1
    weight_prologue nodenom
1:
    subs        w9,  w9,  #2
    ld1        {v6.16b},  [x2], x3
    mov         v27.16b, v1.16b
    mov         v28.16b, v1.16b
    ld1        {v7.16b},  [x2], x3
    mov         v29.16b, v1.16b
    mov         v30.16b, v1.16b
    umlal       v27.8h, v6.8b,  v0.8b
    umlal2      v28.8h, v6.16b, v0.16b
    umlal       v29.8h, v7.8b,  v0.8b
    umlal2      v30.8h, v7.16b, v0.16b
    sqxtun      v4.8b,  v27.8h
    sqxtun2     v4.16b, v28.8h
    sqxtun      v5.8b,  v29.8h
    sqxtun2     v5.16b, v30.8h
    st1        {v4.16b},  [x0], x1
    st1        {v5.16b},  [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w8_nodenom_neon, export=1
    weight_prologue nodenom
1:
    subs        w9,  w9,  #2
    ld1        {v16.8b}, [x2], x3
    mov         v27.16b, v1.16b
    ld1        {v17.8b}, [x2], x3
    mov         v29.16b, v1.16b
    umlal       v27.8h, v16.8b, v0.8b
    umlal       v29.8h, v17.8b, v0.8b
    sqxtun      v4.8b,  v27.8h
    sqxtun      v5.8b,  v29.8h
    st1        {v4.8b},  [x0], x1
    st1        {v5.8b},  [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w4_nodenom_neon, export=1
    weight_prologue nodenom
1:
    subs        w9,  w9,  #2
    ld1        {v16.s}[0], [x2], x3
    ld1        {v16.s}[1], [x2], x3
    mov         v27.16b, v1.16b
    umlal       v27.8h, v16.8b, v0.8b
    sqxtun      v4.8b,  v27.8h
    st1        {v4.s}[0],  [x0], x1
    st1        {v4.s}[1],  [x0], x1
    b.gt        1b
    ret
endfunc

.macro weight_simple_prologue
    ldr         w6,  [x4]               // offset
    dup         v1.16b,  w6
.endm

.macro weight_simple name op
function x264_mc_weight_w20_\name\()_neon, export=1
    weight_simple_prologue
1:
    subs        w5,  w5,  #2
    ldr         s18, [x2, #16]
    ld1        {v16.16b}, [x2], x3
    ldr         s19, [x2, #16]
    ld1        {v17.16b}, [x2], x3
    \op         v18.8b,  v18.8b,  v1.8b
    \op         v16.16b, v16.16b, v1.16b
    \op         v19.8b,  v19.8b,  v1.8b
    \op         v17.16b, v17.16b, v1.16b
    str         s18, [x0, #16]
    st1        {v16.16b}, [x0], x1
    str         s19, [x0, #16]
    st1        {v17.16b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w16_\name\()_neon, export=1
    weight_simple_prologue
1:
    subs        w5,  w5,  #2
    ld1        {v16.16b}, [x2], x3
    ld1        {v17.16b}, [x2], x3
    \op         v16.16b, v16.16b, v1.16b
    \op         v17.16b, v17.16b, v1.16b
    st1        {v16.16b}, [x0], x1
    st1        {v17.16b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w8_\name\()_neon, export=1
    weight_simple_prologue
1:
    subs        w5,  w5,  #2
    ld1        {v16.8b}, [x2], x3
    ld1        {v17.8b}, [x2], x3
    \op         v16.8b, v16.8b, v1.8b
    \op         v17.8b, v17.8b, v1.8b
    st1        {v16.8b}, [x0], x1
    st1        {v17.8b}, [x0], x1
    b.gt        1b
    ret
endfunc

function x264_mc_weight_w4_\name\()_neon, export=1
    weight_simple_prologue
1:
    subs        w5,  w5,  #2
    ld1        {v16.s}[0], [x2], x3
    ld1        {v16.s}[1], [x2], x3
    \op         v16.8b, v16.8b, v1.8b
    st1        {v16.s}[0], [x0], x1
    st1        {v16.s}[1], [x0], x1
    b.gt        1b
    ret
endfunc
.endm

weight_simple offsetadd, uqadd
weight_simple offsetsub, uqsub


// void mc_copy( uint8_t *dst, intptr_t dst_stride, uint8_t *src, intptr_t src_stride, int height )
function x264_mc_copy_w4_neon, export=1
1:
    subs        w4,  w4,  #4
    ld1        {v0.s}[0],  [x2],  x3
    ld1        {v1.s}[0],  [x2],  x3
    ld1        {v2.s}[0],  [x2],  x3
    ld1        {v3.s}[0],  [x2],  x3
    st1        {v0.s}[0],  [x0],  x1
    st1        {v1.s}[0],  [x0],  x1
    st1        {v2.s}[0],  [x0],  x1
    st1        {v3.s}[0],  [x0],  x1
    b.gt        1b
    ret
endfunc

function x264_mc_copy_w8_neon, export=1
1:  subs        w4,  w4,  #4
    ld1        {v0.8b},  [x2],  x3
    ld1        {v1.8b},  [x2],  x3
    ld1        {v2.8b},  [x2],  x3
    ld1        {v3.8b},  [x2],  x3
    st1        {v0.8b},  [x0],  x1
    st1        {v1.8b},  [x0],  x1
    st1        {v2.8b},  [x0],  x1
    st1        {v3.8b},  [x0],  x1
    b.gt        1b
    ret
endfunc

function x264_mc_copy_w16_neon, export=1
1:  subs        w4,  w4,  #4
    ld1        {v0.16b}, [x2],  x3
    ld1        {v1.16b}, [x2],  x3
    ld1        {v2.16b}, [x2],  x3
    ld1        {v3.16b}, [x2],  x3
    st1        {v0.16b}, [x0],  x1
    st1        {v1.16b}, [x0],  x1
    st1        {v2.16b}, [x0],  x1
    st1        {v3.16b}, [x0],  x1
    b.gt        1b
    ret
endfunc

// void x264_mc_chroma_neon( uint8_t *dst_u, uint8_t *dst_v,
//                           intptr_t i_dst_stride,
//                           uint8_t *src, intptr_t i_src_stride,
//                           int dx, int dy, int i_width, int i_height );
function x264_mc_chroma_neon, export=1
    ldr         w15, [sp]               // height
    sbfx        x12, x6,  #3,  #29      // asr(3) and sign extend
    sbfx        x11, x5,  #3,  #29      // asr(3) and sign extend
    cmp         w7,  #4
    mul         x12, x12, x4
    add         x3,  x3,  x11, lsl #1

    and         w5,  w5,  #7
    and         w6,  w6,  #7

    add         x3,  x3,  x12

    //pld             [x3]
    //pld             [x3, x4]

    b.gt        mc_chroma_w8_neon
    b.eq        mc_chroma_w4_neon
endfunc

.macro CHROMA_MC_START r00, r01, r10, r11
    mul         w12, w5,  w6            // cD = d8x    *d8y
    lsl         w13, w5,  #3
    add         w9,  w12,  #64
    lsl         w14, w6,  #3
    tst         w12, w12
    sub         w9,  w9,  w13
    sub         w10, w13, w12           // cB = d8x    *(8-d8y);
    sub         w11, w14, w12           // cC = (8-d8x)*d8y
    sub         w9,  w9,  w14           // cA = (8-d8x)*(8-d8y);
.endm

.macro CHROMA_MC width, vsize
function mc_chroma_w\width\()_neon
// since the element size varies, there's a different index for the 2nd store
.if \width == 4
    .set st2, 1
.else
    .set st2, 2
.endif
    CHROMA_MC_START
    b.eq        2f

    ld2        {v28.8b,v29.8b}, [x3], x4
    dup         v0.8b,  w9               // cA
    dup         v1.8b,  w10              // cB

    ext         v6.8b, v28.8b, v6.8b,  #1
    ext         v7.8b, v29.8b, v7.8b,  #1

    ld2        {v30.8b,v31.8b}, [x3], x4
    dup         v2.8b,  w11              // cC
    dup         v3.8b,  w12              // cD

    ext         v22.8b, v30.8b, v22.8b,  #1
    ext         v23.8b, v31.8b, v23.8b,  #1

    trn1        v0.2s,  v0.2s,  v1.2s
    trn1        v2.2s,  v2.2s,  v3.2s

    trn1        v4.2s,  v28.2s, v6.2s
    trn1        v5.2s,  v29.2s, v7.2s
    trn1        v20.2s, v30.2s, v22.2s
    trn1        v21.2s, v31.2s, v23.2s
1:  // height loop, interpolate xy
    subs        w15, w15, #2
    umull       v16.8h, v4.8b,  v0.8b
    umlal       v16.8h, v20.8b, v2.8b
    umull       v17.8h, v5.8b,  v0.8b
    umlal       v17.8h, v21.8b, v2.8b

    ld2        {v28.8b,v29.8b}, [x3], x4
    transpose   v24.2d, v25.2d, v16.2d, v17.2d

    ext         v6.8b, v28.8b, v6.8b,  #1
    ext         v7.8b, v29.8b, v7.8b,  #1

    trn1        v4.2s,  v28.2s, v6.2s
    trn1        v5.2s,  v29.2s, v7.2s

    add         v16.8h, v24.8h, v25.8h

    umull       v18.8h, v20.8b, v0.8b
    umlal       v18.8h, v4.8b,  v2.8b
    umull       v19.8h, v21.8b, v0.8b
    umlal       v19.8h, v5.8b,  v2.8b

    ld2        {v30.8b,v31.8b}, [x3], x4
    transpose   v26.2d, v27.2d, v18.2d, v19.2d

    ext         v22.8b, v30.8b, v22.8b,  #1
    ext         v23.8b, v31.8b, v23.8b,  #1
    trn1        v20.2s, v30.2s, v22.2s
    trn1        v21.2s, v31.2s, v23.2s

    add         v17.8h, v26.8h, v27.8h

    rshrn       v16.8b, v16.8h, #6
    rshrn       v17.8b, v17.8h, #6

    //pld         [x3]
    //pld         [x3, x4]

    st1        {v16.\vsize}[0],   [x0], x2
    st1        {v16.\vsize}[st2], [x1], x2
    st1        {v17.\vsize}[0],   [x0], x2
    st1        {v17.\vsize}[st2], [x1], x2
    b.gt        1b

    ret
2:  // dx or dy are 0
    tst         w11, w11
    add         w10, w10,  w11
    dup         v0.8b,  w9
    dup         v1.8b,  w10

    b.eq        4f

    ld1        {v4.8b}, [x3], x4
    ld1        {v6.8b}, [x3], x4
3:  // vertical interpolation loop
    subs        w15, w15, #2
    umull       v16.8h, v4.8b,  v0.8b
    ld1        {v4.8b}, [x3], x4
    umlal       v16.8h, v6.8b,  v1.8b
    umull       v17.8h, v6.8b,  v0.8b
    ld1        {v6.8b}, [x3], x4
    umlal       v17.8h, v4.8b,  v1.8b

    rshrn       v20.8b, v16.8h, #6      // uvuvuvuv
    rshrn       v21.8b, v17.8h, #6      // uvuvuvuv

    uzp1        v16.8b, v20.8b, v21.8b  // d16=uuuu|uuuu, d17=vvvv|vvvv
    uzp2        v17.8b, v20.8b, v21.8b  // d16=uuuu|uuuu, d17=vvvv|vvvv

    //pld         [x3]
    //pld         [x3, x4]

    st1        {v16.\vsize}[0],   [x0], x2
    st1        {v16.\vsize}[st2], [x0], x2
    st1        {v17.\vsize}[0],   [x1], x2
    st1        {v17.\vsize}[st2], [x1], x2
    b.gt        3b

    ret

4:  // dy is 0
    ld1        {v4.8b,v5.8b}, [x3], x4
    ld1        {v6.8b,v7.8b}, [x3], x4

    ext         v5.8b,  v4.8b,  v5.8b,  #2
    ext         v7.8b,  v6.8b,  v7.8b,  #2
5:  // horizontal interpolation loop
    subs        w15, w15, #2
    umull       v16.8h, v4.8b,  v0.8b
    umlal       v16.8h, v5.8b,  v1.8b
    umull       v17.8h, v6.8b,  v0.8b
    umlal       v17.8h, v7.8b,  v1.8b

    ld1        {v4.8b,v5.8b}, [x3], x4
    ld1        {v6.8b,v7.8b}, [x3], x4
    rshrn       v20.8b, v16.8h, #6
    rshrn       v21.8b, v17.8h, #6
    ext         v5.8b,  v4.8b,  v5.8b,  #2
    ext         v7.8b,  v6.8b,  v7.8b,  #2
    uzp1        v16.8b, v20.8b, v21.8b  // d16=uuuu|uuuu, d17=vvvv|vvvv
    uzp2        v17.8b, v20.8b, v21.8b  // d16=uuuu|uuuu, d17=vvvv|vvvv

    //pld         [x3]
    //pld         [x3, x4]

    st1        {v16.\vsize}[0],   [x0], x2
    st1        {v16.\vsize}[st2], [x0], x2
    st1        {v17.\vsize}[0],   [x1], x2
    st1        {v17.\vsize}[st2], [x1], x2
    b.gt        5b

    ret
endfunc
.endm

    CHROMA_MC 2, h
    CHROMA_MC 4, s

function mc_chroma_w8_neon
    CHROMA_MC_START
    b.eq        2f
    ld2        {v4.16b,v5.16b}, [x3], x4
    ld2        {v20.16b,v21.16b}, [x3], x4
    dup         v0.8b, w9               // cA
    dup         v1.8b, w10              // cB

    ext         v6.16b, v4.16b, v4.16b, #1
    ext         v7.16b, v5.16b, v5.16b, #1

    dup         v2.8b, w11              // cC
    dup         v3.8b, w12              // cD

    ext         v22.16b, v20.16b, v20.16b, #1
    ext         v23.16b, v21.16b, v21.16b, #1

1:  // height loop, interpolate xy
    subs        w15, w15, #2
    umull       v16.8h, v4.8b,  v0.8b
    umlal       v16.8h, v6.8b,  v1.8b
    umlal       v16.8h, v20.8b, v2.8b
    umlal       v16.8h, v22.8b, v3.8b

    umull       v17.8h, v5.8b,  v0.8b
    umlal       v17.8h, v7.8b,  v1.8b
    umlal       v17.8h, v21.8b, v2.8b
    umlal       v17.8h, v23.8b, v3.8b

    ld2        {v4.16b,v5.16b}, [x3], x4

    ext         v6.16b, v4.16b, v4.16b, #1
    ext         v7.16b, v5.16b, v5.16b, #1

    umull       v18.8h, v20.8b, v0.8b
    umlal       v18.8h, v22.8b, v1.8b
    umlal       v18.8h, v4.8b,  v2.8b
    umlal       v18.8h, v6.8b,  v3.8b

    umull       v19.8h, v21.8b, v0.8b
    umlal       v19.8h, v23.8b, v1.8b
    umlal       v19.8h, v5.8b,  v2.8b
    umlal       v19.8h, v7.8b,  v3.8b

    ld2        {v20.16b,v21.16b}, [x3], x4

    rshrn       v16.8b, v16.8h, #6
    rshrn       v17.8b, v17.8h, #6
    rshrn       v18.8b, v18.8h, #6
    rshrn       v19.8b, v19.8h, #6

    ext         v22.16b, v20.16b, v20.16b, #1
    ext         v23.16b, v21.16b, v21.16b, #1

    //pld         [x3]
    //pld         [x3, x4]

    st1        {v16.8b}, [x0], x2
    st1        {v17.8b}, [x1], x2
    st1        {v18.8b}, [x0], x2
    st1        {v19.8b}, [x1], x2
    b.gt        1b

    ret
2:  // dx or dy are 0
    tst         w11, w11
    add         w10, w10, w11
    dup         v0.8b, w9
    dup         v1.8b, w10

    b.eq        4f

    ld2        {v4.8b,v5.8b}, [x3], x4
    ld2        {v6.8b,v7.8b}, [x3], x4
3:  // vertical interpolation loop
    subs        w15, w15, #2
    umull       v16.8h, v4.8b,  v0.8b //U
    umlal       v16.8h, v6.8b,  v1.8b
    umull       v17.8h, v5.8b,  v0.8b //V
    umlal       v17.8h, v7.8b,  v1.8b

    ld2        {v4.8b,v5.8b}, [x3], x4

    umull       v18.8h, v6.8b,  v0.8b
    umlal       v18.8h, v4.8b,  v1.8b
    umull       v19.8h, v7.8b,  v0.8b
    umlal       v19.8h, v5.8b,  v1.8b

    ld2        {v6.8b,v7.8b}, [x3], x4

    rshrn       v16.8b, v16.8h, #6
    rshrn       v17.8b, v17.8h, #6
    rshrn       v18.8b, v18.8h, #6
    rshrn       v19.8b, v19.8h, #6

    //pld         [x3]
    //pld         [x3, x4]

    st1        {v16.8b}, [x0], x2
    st1        {v17.8b}, [x1], x2
    st1        {v18.8b}, [x0], x2
    st1        {v19.8b}, [x1], x2
    b.gt        3b

    ret
4:  // dy is 0
    ld2        {v4.16b,v5.16b}, [x3], x4
    ext         v6.16b, v4.16b, v4.16b, #1
    ext         v7.16b, v5.16b, v5.16b, #1
    ld2        {v20.16b,v21.16b}, [x3], x4
    ext         v22.16b, v20.16b, v20.16b, #1
    ext         v23.16b, v21.16b, v21.16b, #1
5:  // horizontal interpolation loop
    subs        w15, w15, #2
    umull       v16.8h, v4.8b,  v0.8b //U
    umlal       v16.8h, v6.8b,  v1.8b
    umull       v17.8h, v5.8b,  v0.8b //V
    umlal       v17.8h, v7.8b,  v1.8b

    ld2        {v4.16b,v5.16b}, [x3], x4

    umull       v18.8h, v20.8b, v0.8b
    umlal       v18.8h, v22.8b, v1.8b
    umull       v19.8h, v21.8b, v0.8b
    umlal       v19.8h, v23.8b, v1.8b

    ld2        {v20.16b,v21.16b}, [x3], x4

    rshrn       v16.8b, v16.8h, #6
    rshrn       v17.8b, v17.8h, #6
    rshrn       v18.8b, v18.8h, #6
    rshrn       v19.8b, v19.8h, #6

    ext         v6.16b, v4.16b, v4.16b, #1
    ext         v7.16b, v5.16b, v5.16b, #1
    ext         v22.16b, v20.16b, v20.16b, #1
    ext         v23.16b, v21.16b, v21.16b, #1

    //pld         [x3]
    //pld         [x3, x4]

    st1        {v16.8b}, [x0], x2
    st1        {v17.8b}, [x1], x2
    st1        {v18.8b}, [x0], x2
    st1        {v19.8b}, [x1], x2
    b.gt        5b

    ret
endfunc

//void hpel_filter( pixel *dsth, pixel *dstv, pixel *dstc, pixel *src,
//                  intptr_t stride, int width, int height, int16_t *buf )
function x264_hpel_filter_neon, export=1
    ubfm        x9,  x3,  #0,  #3
    add         w15, w5,  w9
    sub         x13, x3,  x9            // align src
    sub         x10, x0,  x9
    sub         x11, x1,  x9
    sub         x12, x2,  x9
    movi        v30.16b,  #5
    movi        v31.16b,  #20
1:  // line start
    mov         x3,  x13
    mov         x2,  x12
    mov         x1,  x11
    mov         x0,  x10
    add         x7,  x3,  #16           // src pointer next 16b for horiz filter
    mov         x5,  x15                // restore width
    sub         x3,  x3,  x4,  lsl #1   // src - 2*stride
    ld1        {v28.16b}, [x7], #16     // src[16:31]

    add         x9,  x3,  x5            // holds src - 2*stride + width

    ld1        {v16.16b}, [x3], x4      // src-2*stride[0:15]
    ld1        {v17.16b}, [x3], x4      // src-1*stride[0:15]
    ld1        {v18.16b}, [x3], x4      // src+0*stride[0:15]
    ld1        {v19.16b}, [x3], x4      // src+1*stride[0:15]
    ld1        {v20.16b}, [x3], x4      // src+2*stride[0:15]
    ld1        {v21.16b}, [x3], x4      // src+3*stride[0:15]

    ext         v22.16b, v7.16b,  v18.16b, #14
    uaddl       v1.8h,   v16.8b,  v21.8b
    ext         v26.16b, v18.16b, v28.16b, #3
    umlsl       v1.8h,   v17.8b,  v30.8b
    ext         v23.16b, v7.16b,  v18.16b, #15
    umlal       v1.8h,   v18.8b,  v31.8b
    ext         v24.16b, v18.16b, v28.16b, #1
    umlal       v1.8h,   v19.8b,  v31.8b
    ext         v25.16b, v18.16b, v28.16b, #2
    umlsl       v1.8h,   v20.8b,  v30.8b
2:  // next 16 pixel of line
    subs        x5,  x5,  #16
    sub         x3,  x9,  x5            // src - 2*stride += 16

    uaddl       v4.8h,  v22.8b,  v26.8b
    uaddl2      v5.8h,  v22.16b, v26.16b
    sqrshrun    v6.8b,  v1.8h,   #5
    umlsl       v4.8h,  v23.8b,  v30.8b
    umlsl2      v5.8h,  v23.16b, v30.16b
    umlal       v4.8h,  v18.8b,  v31.8b
    umlal2      v5.8h,  v18.16b, v31.16b
    umlal       v4.8h,  v24.8b,  v31.8b
    umlal2      v5.8h,  v24.16b, v31.16b
    umlsl       v4.8h,  v25.8b,  v30.8b
    umlsl2      v5.8h,  v25.16b, v30.16b

    uaddl2      v2.8h,  v16.16b, v21.16b
    sqrshrun    v4.8b,  v4.8h,   #5
    mov         v7.16b, v18.16b
    sqrshrun2   v4.16b, v5.8h,   #5

    umlsl2      v2.8h,  v17.16b, v30.16b
    ld1        {v16.16b}, [x3],  x4      // src-2*stride[0:15]
    umlal2      v2.8h,  v18.16b, v31.16b
    ld1        {v17.16b}, [x3],  x4      // src-1*stride[0:15]
    umlal2      v2.8h,  v19.16b, v31.16b
    ld1        {v18.16b}, [x3],  x4      // src+0*stride[0:15]
    umlsl2      v2.8h,  v20.16b, v30.16b
    ld1        {v19.16b}, [x3],  x4      // src+1*stride[0:15]
    st1        {v4.16b},  [x0],  #16
    sqrshrun2   v6.16b, v2.8h,   #5
    ld1        {v20.16b}, [x3],  x4      // src+2*stride[0:15]
    ld1        {v21.16b}, [x3],  x4      // src+3*stride[0:15]

    ext         v22.16b, v0.16b, v1.16b, #12
    ext         v26.16b, v1.16b, v2.16b, #6
    ext         v23.16b, v0.16b, v1.16b, #14
    st1        {v6.16b},  [x1],  #16
    uaddl       v3.8h,   v16.8b, v21.8b
    ext         v25.16b, v1.16b, v2.16b, #4
    umlsl       v3.8h,   v17.8b, v30.8b
    ext         v24.16b, v1.16b, v2.16b, #2

    umlal       v3.8h,  v18.8b, v31.8b
    add         v4.8h,  v22.8h, v26.8h
    umlal       v3.8h,  v19.8b, v31.8b
    add         v5.8h,  v23.8h, v25.8h
    umlsl       v3.8h,  v20.8b, v30.8b
    add         v6.8h,  v24.8h, v1.8h

    ext         v22.16b, v1.16b, v2.16b, #12
    ext         v26.16b, v2.16b, v3.16b, #6
    ext         v23.16b, v1.16b, v2.16b, #14
    ext         v25.16b, v2.16b, v3.16b, #4
    ext         v24.16b, v2.16b, v3.16b, #2

    add         v22.8h, v22.8h, v26.8h
    add         v23.8h, v23.8h, v25.8h
    add         v24.8h, v24.8h, v2.8h

    sub         v4.8h,  v4.8h,  v5.8h   // a-b
    sub         v5.8h,  v5.8h,  v6.8h   // b-c

    sub         v22.8h, v22.8h, v23.8h  // a-b
    sub         v23.8h, v23.8h, v24.8h  // b-c

    sshr        v4.8h,  v4.8h,  #2      // (a-b)/4
    sshr        v22.8h, v22.8h, #2      // (a-b)/4
    sub         v4.8h,  v4.8h,  v5.8h   // (a-b)/4-b+c
    sub         v22.8h, v22.8h, v23.8h  // (a-b)/4-b+c
    sshr        v4.8h,  v4.8h,  #2      // ((a-b)/4-b+c)/4
    sshr        v22.8h, v22.8h, #2      // ((a-b)/4-b+c)/4
    add         v4.8h,  v4.8h,  v6.8h   // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16
    add         v22.8h, v22.8h, v24.8h  // ((a-b)/4-b+c)/4+c = (a-5*b+20*c)/16

    sqrshrun    v4.8b,   v4.8h,   #6
    ld1        {v28.16b}, [x7],   #16   // src[16:31]
    mov         v0.16b,  v2.16b
    ext         v23.16b, v7.16b,  v18.16b, #15
    sqrshrun2   v4.16b,  v22.8h,  #6
    mov         v1.16b,  v3.16b
    ext         v22.16b, v7.16b,  v18.16b, #14
    ext         v24.16b, v18.16b, v28.16b, #1
    ext         v25.16b, v18.16b, v28.16b, #2
    ext         v26.16b, v18.16b, v28.16b, #3

    st1        {v4.16b}, [x2], #16
    b.gt        2b

    subs        w6,  w6,  #1
    add         x10,  x10,  x4
    add         x11,  x11,  x4
    add         x12,  x12,  x4
    add         x13,  x13,  x4
    b.gt        1b

    ret
endfunc

// frame_init_lowres_core( uint8_t *src0, uint8_t *dst0, uint8_t *dsth,
//                         uint8_t *dstv, uint8_t *dstc, intptr_t src_stride,
//                         intptr_t dst_stride, int width, int height )
function x264_frame_init_lowres_core_neon, export=1
    ldr         w8,  [sp]
    sub         x10, x6,  w7, uxtw      // dst_stride - width
    and         x10, x10, #~15

1:
    mov         w9,  w7                 // width
    mov         x11, x0                 // src0
    add         x12, x0,  x5            // src1 = src0 + src_stride
    add         x13, x0,  x5,  lsl #1   // src2 = src1 + src_stride

    ld2        {v0.16b,v1.16b}, [x11], #32
    ld2        {v2.16b,v3.16b}, [x12], #32
    ld2        {v4.16b,v5.16b}, [x13], #32

    urhadd      v20.16b, v0.16b,  v2.16b    // s0[2x]   + s1[2x]
    urhadd      v22.16b, v2.16b,  v4.16b    // s1[2x]   + s2[2x]
2:
    subs        w9,  w9,  #16
    urhadd      v21.16b, v1.16b,  v3.16b    // s0[2x+1] + s1[2x+1]
    urhadd      v23.16b, v3.16b,  v5.16b    // s1[2x+1] + s2[2x+1]

    ld2        {v0.16b,v1.16b}, [x11], #32
    ld2        {v2.16b,v3.16b}, [x12], #32
    ld2        {v4.16b,v5.16b}, [x13], #32
    urhadd      v30.16b, v0.16b,  v2.16b    // loop: s0[2x]   + s1[2x]
    urhadd      v31.16b, v2.16b,  v4.16b    // loop: s1[2x]   + s2[2x]
    ext         v24.16b, v20.16b, v30.16b, #1   // s0[2x+2] + s1[2x+2]
    ext         v25.16b, v22.16b, v31.16b, #1   // s1[2x+2] + s2[2x+2]

    urhadd      v16.16b, v20.16b, v21.16b
    urhadd      v18.16b, v22.16b, v23.16b
    urhadd      v17.16b, v21.16b, v24.16b
    urhadd      v19.16b, v23.16b, v25.16b

    st1        {v16.16b},   [x1],  #16
    st1        {v18.16b},   [x3],  #16
    st1        {v17.16b},   [x2],  #16
    st1        {v19.16b},   [x4],  #16
    b.le        3f

    subs        w9,  w9,  #16
    urhadd      v21.16b, v1.16b,  v3.16b    // s0[2x+1] + s1[2x+1]
    urhadd      v23.16b, v3.16b,  v5.16b    // s1[2x+1] + s2[2x+1]

    ld2        {v0.16b,v1.16b}, [x11], #32
    ld2        {v2.16b,v3.16b}, [x12], #32
    ld2        {v4.16b,v5.16b}, [x13], #32
    urhadd      v20.16b, v0.16b,  v2.16b    // loop: s0[2x]   + s1[2x]
    urhadd      v22.16b, v2.16b,  v4.16b    // loop: s1[2x]   + s2[2x]
    ext         v24.16b, v30.16b, v20.16b, #1   // s0[2x+2] + s1[2x+2]
    ext         v25.16b, v31.16b, v22.16b, #1   // s1[2x+2] + s2[2x+2]

    urhadd      v16.16b, v30.16b, v21.16b
    urhadd      v18.16b, v31.16b, v23.16b
    urhadd      v17.16b, v21.16b, v24.16b
    urhadd      v19.16b, v23.16b, v25.16b

    st1        {v16.16b},   [x1],  #16
    st1        {v18.16b},   [x3],  #16
    st1        {v17.16b},   [x2],  #16
    st1        {v19.16b},   [x4],  #16
    b.gt        2b
3:
    subs        w8,  w8,  #1
    add         x0,  x0,  x5,  lsl #1
    add         x1,  x1,  x10
    add         x2,  x2,  x10
    add         x3,  x3,  x10
    add         x4,  x4,  x10
    b.gt        1b

    ret
endfunc

function x264_load_deinterleave_chroma_fenc_neon, export=1
    mov         x4,  #FENC_STRIDE/2
    b           load_deinterleave_chroma
endfunc

function x264_load_deinterleave_chroma_fdec_neon, export=1
    mov         x4,  #FDEC_STRIDE/2
load_deinterleave_chroma:
    ld2        {v0.8b,v1.8b}, [x1], x2
    ld2        {v2.8b,v3.8b}, [x1], x2
    subs        w3,  w3,  #2
    st1        {v0.8b}, [x0], x4
    st1        {v1.8b}, [x0], x4
    st1        {v2.8b}, [x0], x4
    st1        {v3.8b}, [x0], x4
    b.gt        load_deinterleave_chroma

    ret
endfunc

function x264_plane_copy_neon, export=1
    add         x8,  x4,  #15
    and         x4,  x8,  #~15
    sub         x1,  x1,  x4
    sub         x3,  x3,  x4
1:
    mov         w8,  w4
16:
    tst         w8,  #16
    b.eq        32f
    subs        w8,  w8,  #16
    ldr         q0,  [x2], #16
    str         q0,  [x0], #16
    b.eq        0f
32:
    subs        w8,  w8,  #32
    ldp         q0,  q1,  [x2], #32
    stp         q0,  q1,  [x0], #32
    b.gt        32b
0:
    subs        w5,  w5,  #1
    add         x2,  x2,  x3
    add         x0,  x0,  x1
    b.gt        1b

    ret
endfunc

function x264_plane_copy_deinterleave_neon, export=1
    add         w9,  w6,  #15
    and         w9,  w9,  #0xfffffff0
    sub         x1,  x1,  x9
    sub         x3,  x3,  x9
    sub         x5,  x5,  x9, lsl #1
1:
    ld2        {v0.16b,v1.16b}, [x4], #32
    subs        w9,  w9,  #16
    st1        {v0.16b}, [x0],  #16
    st1        {v1.16b}, [x2],  #16
    b.gt        1b

    add         x4,  x4,  x5
    subs        w7,  w7,  #1
    add         x0,  x0,  x1
    add         x2,  x2,  x3
    mov         w9,  w6
    b.gt       1b

    ret
endfunc

.macro deinterleave_rgb
    subs            x11, x11, #8
    st1            {v0.8b},    [x0], #8
    st1            {v1.8b},    [x2], #8
    st1            {v2.8b},    [x4], #8
    b.gt            1b

    subs            w10, w10, #1
    add             x0,  x0,  x1
    add             x2,  x2,  x3
    add             x4,  x4,  x5
    add             x6,  x6,  x7
    mov             x11, x9
    b.gt            1b
.endm

function x264_plane_copy_deinterleave_rgb_neon, export=1
#if SYS_MACOSX
    ldr             w8,  [sp]
    ldp             w9,  w10, [sp, #4]
#else
    ldr             x8,  [sp]
    ldp             x9,  x10, [sp, #8]
#endif
    cmp             w8,  #3
    uxtw            x9,  w9
    add             x11, x9,  #7
    and             x11, x11, #~7
    sub             x1,  x1,  x11
    sub             x3,  x3,  x11
    sub             x5,  x5,  x11
    b.ne            4f
    sub             x7,  x7,  x11, lsl #1
    sub             x7,  x7,  x11
1:
    ld3            {v0.8b,v1.8b,v2.8b}, [x6], #24
    deinterleave_rgb

    ret
4:
    sub             x7,  x7,  x11, lsl #2
1:
    ld4            {v0.8b,v1.8b,v2.8b,v3.8b}, [x6], #32
    deinterleave_rgb

    ret
endfunc

function x264_plane_copy_interleave_neon, export=1
    add         w9,  w6,  #15
    and         w9,  w9,  #0xfffffff0
    sub         x1,  x1,  x9,  lsl #1
    sub         x3,  x3,  x9
    sub         x5,  x5,  x9
1:
    ld1        {v0.16b}, [x2],  #16
    ld1        {v1.16b}, [x4],  #16
    subs        w9,  w9,  #16
    st2        {v0.16b,v1.16b}, [x0],  #32
    b.gt        1b

    subs        w7,  w7,  #1
    add         x0,  x0,  x1
    add         x2,  x2,  x3
    add         x4,  x4,  x5
    mov         w9,  w6
    b.gt        1b

    ret
endfunc

function x264_store_interleave_chroma_neon, export=1
    mov             x5,  #FDEC_STRIDE
1:
    ld1        {v0.8b}, [x2], x5
    ld1        {v1.8b}, [x3], x5
    ld1        {v2.8b}, [x2], x5
    ld1        {v3.8b}, [x3], x5
    subs        w4,  w4,  #2
    zip1        v4.16b,  v0.16b,  v1.16b
    zip1        v5.16b,  v2.16b,  v3.16b
    st1        {v4.16b}, [x0], x1
    st1        {v5.16b}, [x0], x1
    b.gt        1b

    ret
endfunc

.macro integral4h p1, p2
    ext         v1.8b,  \p1\().8b,  \p2\().8b,  #1
    ext         v2.8b,  \p1\().8b,  \p2\().8b,  #2
    ext         v3.8b,  \p1\().8b,  \p2\().8b,  #3
    uaddl       v0.8h,  \p1\().8b,  v1.8b
    uaddl       v4.8h,  v2.8b,  v3.8b
    add         v0.8h,  v0.8h,  v4.8h
    add         v0.8h,  v0.8h,  v5.8h
.endm

function integral_init4h_neon, export=1
    sub         x3,  x0,  x2, lsl #1
    ld1        {v6.8b,v7.8b}, [x1], #16
1:
    subs        x2,  x2,  #16
    ld1        {v5.8h},  [x3], #16
    integral4h  v6, v7
    ld1        {v6.8b},  [x1], #8
    ld1        {v5.8h},  [x3], #16
    st1        {v0.8h},  [x0], #16
    integral4h  v7, v6
    ld1        {v7.8b},  [x1], #8
    st1        {v0.8h},  [x0], #16
    b.gt        1b
    ret
endfunc

.macro integral8h p1, p2, s
    ext         v1.8b,  \p1\().8b,  \p2\().8b,  #1
    ext         v2.8b,  \p1\().8b,  \p2\().8b,  #2
    ext         v3.8b,  \p1\().8b,  \p2\().8b,  #3
    ext         v4.8b,  \p1\().8b,  \p2\().8b,  #4
    ext         v5.8b,  \p1\().8b,  \p2\().8b,  #5
    ext         v6.8b,  \p1\().8b,  \p2\().8b,  #6
    ext         v7.8b,  \p1\().8b,  \p2\().8b,  #7
    uaddl       v0.8h,  \p1\().8b,  v1.8b
    uaddl       v2.8h,  v2.8b,  v3.8b
    uaddl       v4.8h,  v4.8b,  v5.8b
    uaddl       v6.8h,  v6.8b,  v7.8b
    add         v0.8h,  v0.8h,  v2.8h
    add         v4.8h,  v4.8h,  v6.8h
    add         v0.8h,  v0.8h,  v4.8h
    add         v0.8h,  v0.8h,  \s\().8h
.endm

function integral_init8h_neon, export=1
    sub         x3,  x0,  x2, lsl #1
    ld1        {v16.8b,v17.8b}, [x1], #16
1:
    subs        x2,  x2,  #16
    ld1        {v18.8h}, [x3], #16
    integral8h  v16, v17, v18
    ld1        {v16.8b}, [x1], #8
    ld1        {v18.8h}, [x3], #16
    st1        {v0.8h},  [x0], #16
    integral8h  v17, v16, v18
    ld1        {v17.8b}, [x1], #8
    st1        {v0.8h},  [x0], #16
    b.gt        1b
    ret
endfunc

function integral_init4v_neon, export=1
    mov         x3,  x0
    add         x4,  x0,  x2,  lsl #3
    add         x8,  x0,  x2,  lsl #4
    sub         x2,  x2,  #8
    ld1        {v20.8h,v21.8h,v22.8h}, [x3], #48
    ld1        {v16.8h,v17.8h,v18.8h}, [x8], #48
1:
    subs        x2,  x2,  #16
    ld1        {v24.8h,v25.8h}, [x4], #32
    ext         v0.16b,  v20.16b, v21.16b, #8
    ext         v1.16b,  v21.16b, v22.16b, #8
    ext         v2.16b,  v16.16b, v17.16b, #8
    ext         v3.16b,  v17.16b, v18.16b, #8
    sub         v24.8h,  v24.8h,  v20.8h
    sub         v25.8h,  v25.8h,  v21.8h
    add         v0.8h,   v0.8h,   v20.8h
    add         v1.8h,   v1.8h,   v21.8h
    add         v2.8h,   v2.8h,   v16.8h
    add         v3.8h,   v3.8h,   v17.8h
    st1        {v24.8h},  [x1], #16
    st1        {v25.8h},  [x1], #16
    mov         v20.16b,  v22.16b
    mov         v16.16b,  v18.16b
    sub         v0.8h,   v2.8h,   v0.8h
    sub         v1.8h,   v3.8h,   v1.8h
    ld1        {v21.8h,v22.8h}, [x3], #32
    ld1        {v17.8h,v18.8h}, [x8], #32
    st1        {v0.8h},  [x0], #16
    st1        {v1.8h},  [x0], #16
    b.gt        1b
2:
    ret
endfunc

function integral_init8v_neon, export=1
    add         x2,  x0,  x1,  lsl #4
    sub         x1,  x1,  #8
    ands        x3,  x1,  #16 - 1
    b.eq        1f
    subs        x1,  x1,  #8
    ld1        {v0.8h}, [x0]
    ld1        {v2.8h}, [x2], #16
    sub         v4.8h,  v2.8h,  v0.8h
    st1        {v4.8h},  [x0], #16
    b.le        2f
1:
    subs        x1,  x1,  #16
    ld1        {v0.8h,v1.8h}, [x0]
    ld1        {v2.8h,v3.8h}, [x2], #32
    sub         v4.8h,  v2.8h,  v0.8h
    sub         v5.8h,  v3.8h,  v1.8h
    st1        {v4.8h},  [x0], #16
    st1        {v5.8h},  [x0], #16
    b.gt        1b
2:
    ret
endfunc

function x264_mbtree_propagate_cost_neon, export=1
    ld1r        {v5.4s},  [x5]
8:
    subs        w6,  w6,  #8
    ld1         {v1.8h},  [x1], #16
    ld1         {v2.8h},  [x2], #16
    ld1         {v3.8h},  [x3], #16
    ld1         {v4.8h},  [x4], #16
    bic         v3.8h,  #0xc0, lsl #8
    umin        v3.8h,  v2.8h,  v3.8h
    umull       v20.4s, v2.4h,  v4.4h   // propagate_intra
    umull2      v21.4s, v2.8h,  v4.8h   // propagate_intra
    usubl       v22.4s, v2.4h,  v3.4h   // propagate_num
    usubl2      v23.4s, v2.8h,  v3.8h   // propagate_num
    uxtl        v26.4s, v2.4h           // propagate_denom
    uxtl2       v27.4s, v2.8h           // propagate_denom
    uxtl        v24.4s, v1.4h
    uxtl2       v25.4s, v1.8h
    ucvtf       v20.4s, v20.4s
    ucvtf       v21.4s, v21.4s
    ucvtf       v26.4s, v26.4s
    ucvtf       v27.4s, v27.4s
    ucvtf       v22.4s, v22.4s
    ucvtf       v23.4s, v23.4s
    frecpe      v28.4s, v26.4s
    frecpe      v29.4s, v27.4s
    ucvtf       v24.4s, v24.4s
    ucvtf       v25.4s, v25.4s
    frecps      v30.4s, v28.4s, v26.4s
    frecps      v31.4s, v29.4s, v27.4s
    fmla        v24.4s, v20.4s, v5.4s   // propagate_amount
    fmla        v25.4s, v21.4s, v5.4s   // propagate_amount
    fmul        v28.4s, v28.4s, v30.4s
    fmul        v29.4s, v29.4s, v31.4s
    fmul        v16.4s, v24.4s, v22.4s
    fmul        v17.4s, v25.4s, v23.4s
    fmul        v18.4s, v16.4s, v28.4s
    fmul        v19.4s, v17.4s, v29.4s
    fcvtns      v20.4s, v18.4s
    fcvtns      v21.4s, v19.4s
    sqxtn       v0.4h,  v20.4s
    sqxtn2      v0.8h,  v21.4s
    st1         {v0.8h},  [x0], #16
    b.gt        8b
    ret
endfunc

const pw_0to15, align=5
    .short 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
endconst

function x264_mbtree_propagate_list_internal_neon, export=1
    movrel      x11,  pw_0to15
    dup         v31.8h,  w4             // bipred_weight
    movi        v30.8h,  #0xc0, lsl #8
    ld1         {v29.8h},  [x11] //h->mb.i_mb_x,h->mb.i_mb_y
    movi        v28.4s,  #4
    movi        v27.8h,  #31
    movi        v26.8h,  #32
    dup         v24.8h,  w5             // mb_y
    zip1        v29.8h,  v29.8h, v24.8h
8:
    subs        w6,  w6,  #8
    ld1         {v1.8h},  [x1], #16     // propagate_amount
    ld1         {v2.8h},  [x2], #16     // lowres_cost
    and         v2.16b, v2.16b, v30.16b
    cmeq        v25.8h, v2.8h,  v30.8h
    umull       v16.4s, v1.4h,  v31.4h
    umull2      v17.4s, v1.8h,  v31.8h
    rshrn       v16.4h, v16.4s, #6
    rshrn2      v16.8h, v17.4s, #6
    bsl         v25.16b, v16.16b, v1.16b // if( lists_used == 3 )
    //          propagate_amount = (propagate_amount * bipred_weight + 32) >> 6
    ld1         {v4.8h,v5.8h},  [x0],  #32
    sshr        v6.8h,  v4.8h,  #5
    sshr        v7.8h,  v5.8h,  #5
    add         v6.8h,  v6.8h,  v29.8h
    add         v29.8h, v29.8h, v28.8h
    add         v7.8h,  v7.8h,  v29.8h
    add         v29.8h, v29.8h, v28.8h
    st1         {v6.8h,v7.8h},  [x3],  #32
    and         v4.16b, v4.16b, v27.16b
    and         v5.16b, v5.16b, v27.16b
    uzp1        v6.8h,  v4.8h,  v5.8h   // x & 31
    uzp2        v7.8h,  v4.8h,  v5.8h   // y & 31
    sub         v4.8h,  v26.8h, v6.8h   // 32 - (x & 31)
    sub         v5.8h,  v26.8h, v7.8h   // 32 - (y & 31)
    mul         v19.8h, v6.8h,  v7.8h   // idx3weight = y*x;
    mul         v18.8h, v4.8h,  v7.8h   // idx2weight = y*(32-x);
    mul         v17.8h, v6.8h,  v5.8h   // idx1weight = (32-y)*x;
    mul         v16.8h, v4.8h,  v5.8h   // idx0weight = (32-y)*(32-x) ;
    umull       v6.4s,  v19.4h, v25.4h
    umull2      v7.4s,  v19.8h, v25.8h
    umull       v4.4s,  v18.4h, v25.4h
    umull2      v5.4s,  v18.8h, v25.8h
    umull       v2.4s,  v17.4h, v25.4h
    umull2      v3.4s,  v17.8h, v25.8h
    umull       v0.4s,  v16.4h, v25.4h
    umull2      v1.4s,  v16.8h, v25.8h
    rshrn       v19.4h, v6.4s,  #10
    rshrn2      v19.8h, v7.4s,  #10
    rshrn       v18.4h, v4.4s,  #10
    rshrn2      v18.8h, v5.4s,  #10
    rshrn       v17.4h, v2.4s,  #10
    rshrn2      v17.8h, v3.4s,  #10
    rshrn       v16.4h, v0.4s,  #10
    rshrn2      v16.8h, v1.4s,  #10
    zip1        v0.8h,  v16.8h, v17.8h
    zip2        v1.8h,  v16.8h, v17.8h
    zip1        v2.8h,  v18.8h, v19.8h
    zip2        v3.8h,  v18.8h, v19.8h
    st1         {v0.8h,v1.8h},  [x3], #32
    st1         {v2.8h,v3.8h},  [x3], #32
    b.ge        8b
    ret
endfunc

function x264_memcpy_aligned_neon, export=1
    tst         x2,  #16
    b.eq        32f
    sub         x2,  x2,  #16
    ldr         q0,  [x1], #16
    str         q0,  [x0], #16
32:
    tst         x2,  #32
    b.eq        640f
    sub         x2,  x2,  #32
    ldp         q0,  q1,  [x1], #32
    stp         q0,  q1,  [x0], #32
640:
    cbz         x2,  1f
64:
    subs        x2,  x2,  #64
    ldp         q0,  q1,  [x1, #32]
    ldp         q2,  q3,  [x1], #64
    stp         q0,  q1,  [x0, #32]
    stp         q2,  q3,  [x0], #64
    b.gt        64b
1:
    ret
endfunc

function x264_memzero_aligned_neon, export=1
    movi        v0.16b,  #0
    movi        v1.16b,  #0
1:
    subs        x1,  x1,  #128
    stp         q0,  q1,  [x0, #96]
    stp         q0,  q1,  [x0, #64]
    stp         q0,  q1,  [x0, #32]
    stp         q0,  q1,  [x0], 128
    b.gt        1b
    ret
endfunc


#endif 


