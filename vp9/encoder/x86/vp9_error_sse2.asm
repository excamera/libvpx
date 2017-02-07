;
;  Copyright (c) 2010 The WebM project authors. All Rights Reserved.
;
;  Use of this source code is governed by a BSD-style license
;  that can be found in the LICENSE file in the root of the source
;  tree. An additional intellectual property rights grant can be found
;  in the file PATENTS.  All contributing project authors may
;  be found in the AUTHORS file in the root of the source tree.
;

%define private_prefix vp9

%include "third_party/x86inc/x86inc.asm"
%include "vpx_dsp/x86/bitdepth_conversion_sse2.asm"

SECTION .text

%if CONFIG_VP9_HIGHBITDEPTH
%else
; int64_t vp9_block_error(int16_t *coeff, int16_t *dqcoeff, intptr_t block_size,
;                         int64_t *ssz)

INIT_XMM sse2
cglobal block_error, 3, 3, 8, uqc, dqc, size, ssz
  pxor      m4, m4                 ; sse accumulator
  pxor      m6, m6                 ; ssz accumulator
  pxor      m5, m5                 ; dedicated zero register
  lea     uqcq, [uqcq+sizeq*2]
  lea     dqcq, [dqcq+sizeq*2]
  neg    sizeq
.loop:
  mova      m2, [uqcq+sizeq*2]
  mova      m0, [dqcq+sizeq*2]
  mova      m3, [uqcq+sizeq*2+mmsize]
  mova      m1, [dqcq+sizeq*2+mmsize]
  psubw     m0, m2
  psubw     m1, m3
  ; individual errors are max. 15bit+sign, so squares are 30bit, and
  ; thus the sum of 2 should fit in a 31bit integer (+ unused sign bit)
  pmaddwd   m0, m0
  pmaddwd   m1, m1
  pmaddwd   m2, m2
  pmaddwd   m3, m3
  ; accumulate in 64bit
  punpckldq m7, m0, m5
  punpckhdq m0, m5
  paddq     m4, m7
  punpckldq m7, m1, m5
  paddq     m4, m0
  punpckhdq m1, m5
  paddq     m4, m7
  punpckldq m7, m2, m5
  paddq     m4, m1
  punpckhdq m2, m5
  paddq     m6, m7
  punpckldq m7, m3, m5
  paddq     m6, m2
  punpckhdq m3, m5
  paddq     m6, m7
  paddq     m6, m3
  add    sizeq, mmsize
  jl .loop

  ; accumulate horizontally and store in return value
  movhlps   m5, m4
  movhlps   m7, m6
  paddq     m4, m5
  paddq     m6, m7
%if ARCH_X86_64
  movq    rax, m4
  movq [sszq], m6
%else
  mov     eax, sszm
  pshufd   m5, m4, 0x1
  movq  [eax], m6
  movd    eax, m4
  movd    edx, m5
%endif
  RET
%endif  ; CONFIG_VP9_HIGHBITDEPTH

; Compute the sum of squared difference between two tran_low_t vectors.
; Vectors are converted (if necessary) to int16_t for calculations.
; int64_t vp9_block_error_fp(tran_low_t *coeff, tran_low_t *dqcoeff,
;                            intptr_t block_size)

INIT_XMM sse2
cglobal block_error_fp, 3, 3, 6, uqc, dqc, size
  pxor      m4, m4                 ; sse accumulator
  pxor      m5, m5                 ; dedicated zero register
.loop:
  LOAD_TRAN_LOW 2, uqcq, 0
  LOAD_TRAN_LOW 0, dqcq, 0
  LOAD_TRAN_LOW 3, uqcq, 1
  LOAD_TRAN_LOW 1, dqcq, 1
  INCREMENT_ELEMENTS_TRAN_LOW uqcq, 16
  INCREMENT_ELEMENTS_TRAN_LOW dqcq, 16
  sub    sizeq, 16
  psubw     m0, m2
  psubw     m1, m3
  ; individual errors are max. 15bit+sign, so squares are 30bit, and
  ; thus the sum of 2 should fit in a 31bit integer (+ unused sign bit)
  pmaddwd   m0, m0
  pmaddwd   m1, m1
  ; accumulate in 64bit
  punpckldq m3, m0, m5
  punpckhdq m0, m5
  paddq     m4, m3
  punpckldq m3, m1, m5
  paddq     m4, m0
  punpckhdq m1, m5
  paddq     m4, m3
  paddq     m4, m1
  jnz .loop

  ; accumulate horizontally and store in return value
  movhlps   m5, m4
  paddq     m4, m5
%if ARCH_X86_64
  movq    rax, m4
%else
  pshufd   m5, m4, 0x1
  movd    eax, m4
  movd    edx, m5
%endif
  RET
