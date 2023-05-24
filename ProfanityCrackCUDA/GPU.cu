/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>
#include <stdio.h>


#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda.h>
#include <GPU.h>

  // TODO: Add OpenCL kernel code here.
 #define printf(...)


#define MP_NWORDS 8

typedef uint32_t uint32_t;

typedef union {
	uint8_t b[200];
	uint64_t q[25];
	uint32_t d[50];
} ethhash;

__device__
static uint64_t rotate64(uint64_t x, uint32_t i)
{
	uint64_t a = x << i;
	uint64_t b = x >> (64 - i);
	return a | b;
}

//__device__
//static uint32_t rotate32(uint32_t x, uint32_t i)
//{
//	uint32_t a = x << i;
//	uint32_t b = x >> (32 - i);
//	return a | b;
//}

__device__
static uint32_t mul_hi(uint32_t a, uint32_t b)
{
	uint64_t res = (uint64_t)a * (uint64_t)b;
	res = res >> 32;
	return (uint32_t)res;
}

#define TH_ELT(t, c0, c1, c2, c3, c4, d0, d1, d2, d3, d4) \
{ \
    t = rotate64((uint64_t)(d0 ^ d1 ^ d2 ^ d3 ^ d4), (uint64_t)1) ^ (c0 ^ c1 ^ c2 ^ c3 ^ c4); \
}

#define THETA(s00, s01, s02, s03, s04, \
              s10, s11, s12, s13, s14, \
              s20, s21, s22, s23, s24, \
              s30, s31, s32, s33, s34, \
              s40, s41, s42, s43, s44) \
{ \
    TH_ELT(t0, s40, s41, s42, s43, s44, s10, s11, s12, s13, s14); \
    TH_ELT(t1, s00, s01, s02, s03, s04, s20, s21, s22, s23, s24); \
    TH_ELT(t2, s10, s11, s12, s13, s14, s30, s31, s32, s33, s34); \
    TH_ELT(t3, s20, s21, s22, s23, s24, s40, s41, s42, s43, s44); \
    TH_ELT(t4, s30, s31, s32, s33, s34, s00, s01, s02, s03, s04); \
    s00 ^= t0; s01 ^= t0; s02 ^= t0; s03 ^= t0; s04 ^= t0; \
    s10 ^= t1; s11 ^= t1; s12 ^= t1; s13 ^= t1; s14 ^= t1; \
    s20 ^= t2; s21 ^= t2; s22 ^= t2; s23 ^= t2; s24 ^= t2; \
    s30 ^= t3; s31 ^= t3; s32 ^= t3; s33 ^= t3; s34 ^= t3; \
    s40 ^= t4; s41 ^= t4; s42 ^= t4; s43 ^= t4; s44 ^= t4; \
}

#define RHOPI(s00, s01, s02, s03, s04, \
              s10, s11, s12, s13, s14, \
              s20, s21, s22, s23, s24, \
              s30, s31, s32, s33, s34, \
              s40, s41, s42, s43, s44) \
{ \
	t0  = rotate64(s10, (uint64_t) 1);  \
	s10 = rotate64(s11, (uint64_t)44); \
	s11 = rotate64(s41, (uint64_t)20); \
	s41 = rotate64(s24, (uint64_t)61); \
	s24 = rotate64(s42, (uint64_t)39); \
	s42 = rotate64(s04, (uint64_t)18); \
	s04 = rotate64(s20, (uint64_t)62); \
	s20 = rotate64(s22, (uint64_t)43); \
	s22 = rotate64(s32, (uint64_t)25); \
	s32 = rotate64(s43, (uint64_t) 8); \
	s43 = rotate64(s34, (uint64_t)56); \
	s34 = rotate64(s03, (uint64_t)41); \
	s03 = rotate64(s40, (uint64_t)27); \
	s40 = rotate64(s44, (uint64_t)14); \
	s44 = rotate64(s14, (uint64_t) 2); \
	s14 = rotate64(s31, (uint64_t)55); \
	s31 = rotate64(s13, (uint64_t)45); \
	s13 = rotate64(s01, (uint64_t)36); \
	s01 = rotate64(s30, (uint64_t)28); \
	s30 = rotate64(s33, (uint64_t)21); \
	s33 = rotate64(s23, (uint64_t)15); \
	s23 = rotate64(s12, (uint64_t)10); \
	s12 = rotate64(s21, (uint64_t) 6); \
	s21 = rotate64(s02, (uint64_t) 3); \
	s02 = t0; \
}

#define KHI(s00, s01, s02, s03, s04, \
            s10, s11, s12, s13, s14, \
            s20, s21, s22, s23, s24, \
            s30, s31, s32, s33, s34, \
            s40, s41, s42, s43, s44) \
{ \
    t0 = s00 ^ (~s10 &  s20); \
    t1 = s10 ^ (~s20 &  s30); \
    t2 = s20 ^ (~s30 &  s40); \
    t3 = s30 ^ (~s40 &  s00); \
    t4 = s40 ^ (~s00 &  s10); \
    s00 = t0; s10 = t1; s20 = t2; s30 = t3; s40 = t4; \
    \
    t0 = s01 ^ (~s11 &  s21); \
    t1 = s11 ^ (~s21 &  s31); \
    t2 = s21 ^ (~s31 &  s41); \
    t3 = s31 ^ (~s41 &  s01); \
    t4 = s41 ^ (~s01 &  s11); \
    s01 = t0; s11 = t1; s21 = t2; s31 = t3; s41 = t4; \
    \
    t0 = s02 ^ (~s12 &  s22); \
    t1 = s12 ^ (~s22 &  s32); \
    t2 = s22 ^ (~s32 &  s42); \
    t3 = s32 ^ (~s42 &  s02); \
    t4 = s42 ^ (~s02 &  s12); \
    s02 = t0; s12 = t1; s22 = t2; s32 = t3; s42 = t4; \
    \
    t0 = s03 ^ (~s13 &  s23); \
    t1 = s13 ^ (~s23 &  s33); \
    t2 = s23 ^ (~s33 &  s43); \
    t3 = s33 ^ (~s43 &  s03); \
    t4 = s43 ^ (~s03 &  s13); \
    s03 = t0; s13 = t1; s23 = t2; s33 = t3; s43 = t4; \
    \
    t0 = s04 ^ (~s14 &  s24); \
    t1 = s14 ^ (~s24 &  s34); \
    t2 = s24 ^ (~s34 &  s44); \
    t3 = s34 ^ (~s44 &  s04); \
    t4 = s44 ^ (~s04 &  s14); \
    s04 = t0; s14 = t1; s24 = t2; s34 = t3; s44 = t4; \
}

#define IOTA(s00, r) { s00 ^= r; }

__constant__ uint64_t keccakf_rndc[24] = {
	0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
	0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
	0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
	0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
	0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
	0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
	0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
	0x8000000000008080, 0x0000000080000001, 0x8000000080008008
};

// Barely a bottleneck. No need to tinker more.
__device__
void sha3_keccakf(ethhash* const h)
{
	uint64_t* const st = (uint64_t* const)&h->q;
	h->d[33] ^= 0x80000000;
	uint64_t t0, t1, t2, t3, t4;

	// Unrolling and removing PI stage gave negligable performance on GTX 1070.
	for (int i = 0; i < 24; ++i) {
		THETA(st[0], st[5], st[10], st[15], st[20], st[1], st[6], st[11], st[16], st[21], st[2], st[7], st[12], st[17], st[22], st[3], st[8], st[13], st[18], st[23], st[4], st[9], st[14], st[19], st[24]);
		RHOPI(st[0], st[5], st[10], st[15], st[20], st[1], st[6], st[11], st[16], st[21], st[2], st[7], st[12], st[17], st[22], st[3], st[8], st[13], st[18], st[23], st[4], st[9], st[14], st[19], st[24]);
		KHI(st[0], st[5], st[10], st[15], st[20], st[1], st[6], st[11], st[16], st[21], st[2], st[7], st[12], st[17], st[22], st[3], st[8], st[13], st[18], st[23], st[4], st[9], st[14], st[19], st[24]);
		IOTA(st[0], keccakf_rndc[i]);
	}
}

/* ------------------------------------------------------------------------ */
/* Multiprecision functions                                                 */
/* ------------------------------------------------------------------------ */
#define MP_WORDS 8
#define MP_BITS 32
#define bswap32(n) (rotate32(n & 0x00FF00FF, 24U)|(rotate32(n, 8U) & 0x00FF00FF))

// mod              = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f
__constant__ const mp_number mod = { {0xfffffc2f, 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff} };

// Multiprecision subtraction. Underflow signalled via return value.
__device__
uint32_t mp_sub(mp_number* const r, const mp_number* const a, const mp_number* const b) {
	uint32_t t, c = 0;

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		t = a->d[i] - b->d[i] - c;
		c = t > a->d[i] ? 1 : (t == a->d[i] ? c : 0);

		r->d[i] = t;
	}

	return c;
}

// Multiprecision subtraction of the modulus saved in mod. Underflow signalled via return value.
__device__
uint32_t mp_sub_mod(mp_number* const r) {
	mp_number mod = { {0xfffffc2f, 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff} };

	uint32_t t, c = 0;

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		t = r->d[i] - mod.d[i] - c;
		c = t > r->d[i] ? 1 : (t == r->d[i] ? c : 0);

		r->d[i] = t;
	}

	return c;
}

// Multiprecision subtraction modulo M, M = mod.
// This function is often also used for additions by subtracting a negative number. I've chosen
// to do this because:
//   1. It's easier to re-use an already existing function
//   2. A modular addition would have more overhead since it has to determine if the result of
//      the addition (r) is in the gap M <= r < 2^256. This overhead doesn't exist in a
//      subtraction. We immediately know at the end of a subtraction if we had underflow
//      or not by inspecting the carry value. M refers to the modulus saved in variable mod.
__device__
void mp_mod_sub(mp_number* const r, const mp_number* const a, const mp_number* const b) {
	uint32_t i, t, c = 0;

	for (i = 0; i < MP_WORDS; ++i) {
		t = a->d[i] - b->d[i] - c;
		c = t < a->d[i] ? 0 : (t == a->d[i] ? c : 1);

		r->d[i] = t;
	}

	if (c) {
		c = 0;
		for (i = 0; i < MP_WORDS; ++i) {
			r->d[i] += mod.d[i] + c;
			c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
		}
	}
}

// Multiprecision subtraction modulo M from a constant number.
// I made this in the belief that using constant address space instead of private address space for any
// constant numbers would lead to increase in performance. Judges are still out on this one.
__device__
void mp_mod_sub_const(mp_number* const r, const mp_number* const a, const mp_number* const b) {
	uint32_t i, t, c = 0;

	for (i = 0; i < MP_WORDS; ++i) {
		t = a->d[i] - b->d[i] - c;
		c = t < a->d[i] ? 0 : (t == a->d[i] ? c : 1);

		r->d[i] = t;
	}

	if (c) {
		c = 0;
		for (i = 0; i < MP_WORDS; ++i) {
			r->d[i] += mod.d[i] + c;
			c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
		}
	}
}

// Multiprecision subtraction modulo M of G_x from a number.
// Specialization of mp_mod_sub in hope of performance gain.
__device__
void mp_mod_sub_gx(mp_number* const r, const mp_number* const a) {
	uint32_t i, t, c = 0;

	t = a->d[0] - 0x16f81798; c = t < a->d[0] ? 0 : (t == a->d[0] ? c : 1); r->d[0] = t;
	t = a->d[1] - 0x59f2815b - c; c = t < a->d[1] ? 0 : (t == a->d[1] ? c : 1); r->d[1] = t;
	t = a->d[2] - 0x2dce28d9 - c; c = t < a->d[2] ? 0 : (t == a->d[2] ? c : 1); r->d[2] = t;
	t = a->d[3] - 0x029bfcdb - c; c = t < a->d[3] ? 0 : (t == a->d[3] ? c : 1); r->d[3] = t;
	t = a->d[4] - 0xce870b07 - c; c = t < a->d[4] ? 0 : (t == a->d[4] ? c : 1); r->d[4] = t;
	t = a->d[5] - 0x55a06295 - c; c = t < a->d[5] ? 0 : (t == a->d[5] ? c : 1); r->d[5] = t;
	t = a->d[6] - 0xf9dcbbac - c; c = t < a->d[6] ? 0 : (t == a->d[6] ? c : 1); r->d[6] = t;
	t = a->d[7] - 0x79be667e - c; c = t < a->d[7] ? 0 : (t == a->d[7] ? c : 1); r->d[7] = t;

	if (c) {
		c = 0;
		for (i = 0; i < MP_WORDS; ++i) {
			r->d[i] += mod.d[i] + c;
			c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
		}
	}
}

//__device__
//void mp_mod_sub_gx(mp_number* const r, const mp_number* const a) {
//	uint32_t i, t, c = 0;
//
//	t = a->d[0] - 0xe907e497; c = t < a->d[0] ? 0 : (t == a->d[0] ? c : 1); r->d[0] = t;
//	t = a->d[1] - 0xa60d7ea3 - c; c = t < a->d[1] ? 0 : (t == a->d[1] ? c : 1); r->d[1] = t;
//	t = a->d[2] - 0xd231d726 - c; c = t < a->d[2] ? 0 : (t == a->d[2] ? c : 1); r->d[2] = t;
//	t = a->d[3] - 0xfd640324 - c; c = t < a->d[3] ? 0 : (t == a->d[3] ? c : 1); r->d[3] = t;
//	t = a->d[4] - 0x3178f4f8 - c; c = t < a->d[4] ? 0 : (t == a->d[4] ? c : 1); r->d[4] = t;
//	t = a->d[5] - 0xaa5f9d6a - c; c = t < a->d[5] ? 0 : (t == a->d[5] ? c : 1); r->d[5] = t;
//	t = a->d[6] - 0x06234453 - c; c = t < a->d[6] ? 0 : (t == a->d[6] ? c : 1); r->d[6] = t;
//	t = a->d[7] - 0x86419981 - c; c = t < a->d[7] ? 0 : (t == a->d[7] ? c : 1); r->d[7] = t;
//
//	if (c) {
//		c = 0;
//		for (i = 0; i < MP_WORDS; ++i) {
//			r->d[i] += mod.d[i] + c;
//			c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
//		}
//	}
//}

// Multiprecision subtraction modulo M of G_y from a number.
// Specialization of mp_mod_sub in hope of performance gain.
//__device__
//void mp_mod_sub_gy(mp_number* const r, const mp_number* const a) {
//	uint32_t i, t, c = 0;
//
//	t = a->d[0] - 0xfb10d4b8; c = t < a->d[0] ? 0 : (t == a->d[0] ? c : 1); r->d[0] = t;
//	t = a->d[1] - 0x9c47d08f - c; c = t < a->d[1] ? 0 : (t == a->d[1] ? c : 1); r->d[1] = t;
//	t = a->d[2] - 0xa6855419 - c; c = t < a->d[2] ? 0 : (t == a->d[2] ? c : 1); r->d[2] = t;
//	t = a->d[3] - 0xfd17b448 - c; c = t < a->d[3] ? 0 : (t == a->d[3] ? c : 1); r->d[3] = t;
//	t = a->d[4] - 0x0e1108a8 - c; c = t < a->d[4] ? 0 : (t == a->d[4] ? c : 1); r->d[4] = t;
//	t = a->d[5] - 0x5da4fbfc - c; c = t < a->d[5] ? 0 : (t == a->d[5] ? c : 1); r->d[5] = t;
//	t = a->d[6] - 0x26a3c465 - c; c = t < a->d[6] ? 0 : (t == a->d[6] ? c : 1); r->d[6] = t;
//	t = a->d[7] - 0x483ada77 - c; c = t < a->d[7] ? 0 : (t == a->d[7] ? c : 1); r->d[7] = t;
//
//	if (c) {
//		c = 0;
//		for (i = 0; i < MP_WORDS; ++i) {
//			r->d[i] += mod.d[i] + c;
//			c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
//		}
//	}
//}

__device__
void mp_mod_sub_gy(mp_number* const r, const mp_number* const a) {
	uint32_t i, t, c = 0;

	t = a->d[0] - 0x04ef2777; c = t < a->d[0] ? 0 : (t == a->d[0] ? c : 1); r->d[0] = t;
	t = a->d[1] - 0x63b82f6f - c; c = t < a->d[1] ? 0 : (t == a->d[1] ? c : 1); r->d[1] = t;
	t = a->d[2] - 0x597aabe6 - c; c = t < a->d[2] ? 0 : (t == a->d[2] ? c : 1); r->d[2] = t;
	t = a->d[3] - 0x02e84bb7 - c; c = t < a->d[3] ? 0 : (t == a->d[3] ? c : 1); r->d[3] = t;
	t = a->d[4] - 0xf1eef757 - c; c = t < a->d[4] ? 0 : (t == a->d[4] ? c : 1); r->d[4] = t;
	t = a->d[5] - 0xa25b0403 - c; c = t < a->d[5] ? 0 : (t == a->d[5] ? c : 1); r->d[5] = t;
	t = a->d[6] - 0xd95c3b9a - c; c = t < a->d[6] ? 0 : (t == a->d[6] ? c : 1); r->d[6] = t;
	t = a->d[7] - 0xb7c52588 - c; c = t < a->d[7] ? 0 : (t == a->d[7] ? c : 1); r->d[7] = t;

	if (c) {
		c = 0;
		for (i = 0; i < MP_WORDS; ++i) {
			r->d[i] += mod.d[i] + c;
			c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
		}
	}
}




// Multiprecision addition. Overflow signalled via return value.
__device__
uint32_t mp_add(mp_number* const r, const mp_number* const a) {
	uint32_t c = 0;

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		r->d[i] += a->d[i] + c;
		c = r->d[i] < a->d[i] ? 1 : (r->d[i] == a->d[i] ? c : 0);
	}

	return c;
}

// Multiprecision addition. Overflow signalled via return value.
__device__
uint32_t mp_add_size(mp_number* const r, const uint32_t a) {
	uint32_t c = 0;
	r->d[0] += a;
	c = r->d[0] < a ? 1 : (r->d[0] == a ? c : 0);
	for (uint32_t i = 1; i < MP_WORDS; ++i) {
		r->d[i] += c;
		c = r->d[i] == 0 ? 1 : 0;
		if (c == 0) break;
	}

	return c;
}


// Multiprecision addition of the modulus saved in mod. Overflow signalled via return value.
__device__
uint32_t mp_add_mod(mp_number* const r) {
	uint32_t c = 0;

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		r->d[i] += mod.d[i] + c;
		c = r->d[i] < mod.d[i] ? 1 : (r->d[i] == mod.d[i] ? c : 0);
	}

	return c;
}


__device__
uint32_t mp_mod_add(mp_number* const r, const mp_number* const a) {
	uint32_t c = 0;
	c = mp_add(r, a);
	if (c) {
		mp_sub_mod(r);
	}
	return c;
}

// Multiprecision addition of two numbers with one extra word each. Overflow signalled via return value.
__device__
uint32_t mp_add_more(mp_number* const r, uint32_t* const extraR, const mp_number* const a, const uint32_t* const extraA) {
	const uint32_t c = mp_add(r, a);
	*extraR += *extraA + c;
	return *extraR < *extraA ? 1 : (*extraR == *extraA ? c : 0);
}

// Multiprecision greater than or equal (>=) operator
__device__
uint32_t mp_gte(const mp_number* const a, const mp_number* const b) {
	uint32_t l = 0, g = 0;

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		if (a->d[i] < b->d[i]) l |= (1 << i);
		if (a->d[i] > b->d[i]) g |= (1 << i);
	}

	return g >= l;
}

// Bit shifts a number with an extra word to the right one step
__device__
void mp_shr_extra(mp_number* const r, uint32_t* const e) {
	r->d[0] = (r->d[1] << 31) | (r->d[0] >> 1);
	r->d[1] = (r->d[2] << 31) | (r->d[1] >> 1);
	r->d[2] = (r->d[3] << 31) | (r->d[2] >> 1);
	r->d[3] = (r->d[4] << 31) | (r->d[3] >> 1);
	r->d[4] = (r->d[5] << 31) | (r->d[4] >> 1);
	r->d[5] = (r->d[6] << 31) | (r->d[5] >> 1);
	r->d[6] = (r->d[7] << 31) | (r->d[6] >> 1);
	r->d[7] = (*e << 31) | (r->d[7] >> 1);
	*e >>= 1;
}

// Bit shifts a number to the right one step
__device__
void mp_shr(mp_number* const r) {
	r->d[0] = (r->d[1] << 31) | (r->d[0] >> 1);
	r->d[1] = (r->d[2] << 31) | (r->d[1] >> 1);
	r->d[2] = (r->d[3] << 31) | (r->d[2] >> 1);
	r->d[3] = (r->d[4] << 31) | (r->d[3] >> 1);
	r->d[4] = (r->d[5] << 31) | (r->d[4] >> 1);
	r->d[5] = (r->d[6] << 31) | (r->d[5] >> 1);
	r->d[6] = (r->d[7] << 31) | (r->d[6] >> 1);
	r->d[7] >>= 1;
}

// Multiplies a number with a word and adds it to an existing number with an extra word, overflow of the extra word is signalled in return value
// This is a special function only used for modular multiplication
__device__
uint32_t mp_mul_word_add_extra(mp_number* const r, const mp_number* const a, const uint32_t w, uint32_t* const extra) {
	uint32_t cM = 0; // Carry for multiplication
	uint32_t cA = 0; // Carry for addition
	uint32_t tM = 0; // Temporary storage for multiplication

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		tM = (a->d[i] * w + cM);
		cM = mul_hi(a->d[i], w) + (tM < cM);

		r->d[i] += tM + cA;
		cA = r->d[i] < tM ? 1 : (r->d[i] == tM ? cA : 0);
	}

	*extra += cM + cA;
	return *extra < cM ? 1 : (*extra == cM ? cA : 0);
}

// Multiplies a number with a word, potentially adds modhigher to it, and then subtracts it from en existing number, no extra words, no overflow
// This is a special function only used for modular multiplication
__device__
void mp_mul_mod_word_sub(mp_number* const r, const uint32_t w, const bool withModHigher) {
	// Having these numbers declared here instead of using the global values in __constant__ address space seems to lead
	// to better optimizations by the compiler on my GTX 1070.
	mp_number mod = { { 0xfffffc2f, 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff} };
	mp_number modhigher = { {0x00000000, 0xfffffc2f, 0xfffffffe, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff} };

	uint32_t cM = 0; // Carry for multiplication
	uint32_t cS = 0; // Carry for subtraction
	uint32_t tS = 0; // Temporary storage for subtraction
	uint32_t tM = 0; // Temporary storage for multiplication
	uint32_t cA = 0; // Carry for addition of modhigher

	for (uint32_t i = 0; i < MP_WORDS; ++i) {
		tM = (mod.d[i] * w + cM);
		cM = mul_hi(mod.d[i], w) + (tM < cM);

		tM += (withModHigher ? modhigher.d[i] : 0) + cA;
		cA = tM < (withModHigher ? modhigher.d[i] : 0) ? 1 : (tM == (withModHigher ? modhigher.d[i] : 0) ? cA : 0);

		tS = r->d[i] - tM - cS;
		cS = tS > r->d[i] ? 1 : (tS == r->d[i] ? cS : 0);

		r->d[i] = tS;
	}
}

// Modular multiplication. Based on Algorithm 3 (and a series of hunches) from this article:
// https://www.esat.kuleuven.be/cosic/publications/article-1191.pdf
// When I first implemented it I never encountered a situation where the additional end steps
// of adding or subtracting the modulo was necessary. Maybe it's not for the particular modulo
// used in secp256k1, maybe the overflow bit can be skipped in to avoid 8 subtractions and
// trade it for the final steps? Maybe the final steps are necessary but seldom needed?
// I have no idea, for the time being I'll leave it like this, also see the comments at the
// beginning of this document under the title "Cutting corners".
__device__
void mp_mod_mul(mp_number* const r, const mp_number* const X, const mp_number* const Y) {
	mp_number Z = { {0} };
	uint32_t extraWord;

	for (int i = MP_WORDS - 1; i >= 0; --i) {
		// Z = Z * 2^32
		extraWord = Z.d[7]; Z.d[7] = Z.d[6]; Z.d[6] = Z.d[5]; Z.d[5] = Z.d[4]; Z.d[4] = Z.d[3]; Z.d[3] = Z.d[2]; Z.d[2] = Z.d[1]; Z.d[1] = Z.d[0]; Z.d[0] = 0;

		// Z = Z + X * Y_i
		bool overflow = mp_mul_word_add_extra(&Z, X, Y->d[i], &extraWord);

		// Z = Z - qM
		mp_mul_mod_word_sub(&Z, extraWord, overflow);
	}

	*r = Z;
}


// Modular inversion of a number. 
__device__
void mp_mod_inverse(mp_number* const r) {
	mp_number A = { { 1 } };
	mp_number C = { { 0 } };
	mp_number v = mod;

	uint32_t extraA = 0;
	uint32_t extraC = 0;

	while (r->d[0] || r->d[1] || r->d[2] || r->d[3] || r->d[4] || r->d[5] || r->d[6] || r->d[7]) {
		while (!(r->d[0] & 1)) {
			mp_shr(r);
			if (A.d[0] & 1) {
				extraA += mp_add_mod(&A);
			}

			mp_shr_extra(&A, &extraA);
		}

		while (!(v.d[0] & 1)) {
			mp_shr(&v);
			if (C.d[0] & 1) {
				extraC += mp_add_mod(&C);
			}

			mp_shr_extra(&C, &extraC);
		}

		if (mp_gte(r, &v)) {
			mp_sub(r, r, &v);
			mp_add_more(&A, &extraA, &C, &extraC);
		}
		else {
			mp_sub(&v, &v, r);
			mp_add_more(&C, &extraC, &A, &extraA);
		}
	}

	while (extraC) {
		extraC -= mp_sub_mod(&C);
	}

	v = mod;
	mp_sub(r, &v, &C);
}

__device__
void mp_mod_div(mp_number* const r, const mp_number* const X, const mp_number* const Y) {
	mp_number inverse;
	inverse.d[0] = Y->d[0];
	inverse.d[1] = Y->d[1];
	inverse.d[2] = Y->d[2];
	inverse.d[3] = Y->d[3];
	inverse.d[4] = Y->d[4];
	inverse.d[5] = Y->d[5];
	inverse.d[6] = Y->d[6];
	inverse.d[7] = Y->d[7];
	mp_mod_inverse(&inverse);
	mp_mod_mul(r, X, &inverse);
}
/* ------------------------------------------------------------------------ */
/* Elliptic point and addition (with caveats).                              */
/* ------------------------------------------------------------------------ */

// Elliptical point addition
// Does not handle points sharing X coordinate, this is a deliberate design choice.
// For more information on this choice see the beginning of this file.
__device__
void point_add(point* const r, point* const p, point* const o) {
	mp_number tmp;
	mp_number newX;
	mp_number newY;

	mp_mod_sub(&tmp, &o->x, &p->x);

	mp_mod_inverse(&tmp);

	mp_mod_sub(&newX, &o->y, &p->y);
	mp_mod_mul(&tmp, &tmp, &newX);

	mp_mod_mul(&newX, &tmp, &tmp);
	mp_mod_sub(&newX, &newX, &p->x);
	mp_mod_sub(&newX, &newX, &o->x);

	mp_mod_sub(&newY, &p->x, &newX);
	mp_mod_mul(&newY, &newY, &tmp);
	mp_mod_sub(&newY, &newY, &p->y);

	r->x = newX;
	r->y = newY;
}



__device__
void printMpNumber(mp_number* x) {
	printf("%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x\n",
		x->d[7],
		x->d[6],
		x->d[5],
		x->d[4],
		x->d[3],
		x->d[2],
		x->d[1],
		x->d[0]);
}

__device__
void printPoint(point* p) {
	printf("X: %.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x\nY: %.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x\n",
		p->x.d[7],
		p->x.d[6],
		p->x.d[5],
		p->x.d[4],
		p->x.d[3],
		p->x.d[2],
		p->x.d[1],
		p->x.d[0],
		p->y.d[7],
		p->y.d[6],
		p->y.d[5],
		p->y.d[4],
		p->y.d[3],
		p->y.d[2],
		p->y.d[1],
		p->y.d[0]);
}


__device__
void mul_G(const point* const precomp, point* const p, const size_t precompOffset, const uint64_t k) {
	point o;
	bool bIsFirst = true;
	for (uint8_t i = 0; i < 8; ++i) {
		const uint8_t shift = i * 8;
		const uint8_t byte = (k >> shift) & 0xFF;

		if (byte) {
			o = precomp[precompOffset + i * 255 + byte - 1];
			if (bIsFirst) {
				*p = o;
				bIsFirst = false;
			}
			else {
				point_add(p, p, &o);
			}
		}
	}
}

__global__ void dev_crack_init(const point* const precomp, point* const extensionPublicKey, point* publicKey) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	point pubKey; //public key = publicKey - G*2^192*id
	point g2192; //G*2^192
	for (int i = 0; i < 8; i++)
	{
		pubKey.x.d[i] = publicKey->x.d[i];
		pubKey.y.d[i] = publicKey->y.d[i];
	}
	if (idx != 0) {
		uint32_t num = idx;
		mul_G(precomp, &g2192, 8 * 255 * 3, num); //calculate G*2^192*id
		//-G*2^192*id
		mp_number zero = { {0} };
		mp_mod_sub(&g2192.y, &zero, &g2192.y); //calculate negative y coordinate
		point_add(&pubKey, &pubKey, &g2192); //publicKey + (-G*2^192*id)
	}
	for (int ii = 0; ii < 8; ii++)
	{
		extensionPublicKey[idx].x.d[ii] = pubKey.x.d[ii];
		extensionPublicKey[idx].y.d[ii] = pubKey.y.d[ii];
	}
}





/* Four of six logical functions used in SHA-384 and SHA-512: */
#define REVERSE32_FOR_HASH(w,x)	{ \
	uint32_t tmp = (w); \
	tmp = (tmp >> 16) | (tmp << 16); \
	(x) = ((tmp & 0xff00ff00UL) >> 8) | ((tmp & 0x00ff00ffUL) << 8); \
}
#define REVERSE64_FOR_HASH(w,x)	{ \
	uint64_t tmp = (w); \
	tmp = (tmp >> 32) | (tmp << 32); \
	tmp = ((tmp & 0xff00ff00ff00ff00UL) >> 8) | \
	      ((tmp & 0x00ff00ff00ff00ffUL) << 8); \
	(x) = ((tmp & 0xffff0000ffff0000UL) >> 16) | \
	      ((tmp & 0x0000ffff0000ffffUL) << 16); \
}

int comp_key_test(const point* const key, const uint32_t bytes_y_from_table) {
	const uint32_t bytes_y = key->x.d[7];
	//const uint64_t bytes_y = 1;
	if (bytes_y < bytes_y_from_table)
	{
		return -1;
	}
	else if (bytes_y > bytes_y_from_table)
	{
		return 1;
	}
	return 0;
}


__device__
int comp_key(const point* const key, const uint64_t bytes_y_from_table) {
	uint64_t bytes_y = *(const uint64_t*)&key->x.d[6];
	uint64_t bytes_x_from_table = bytes_y_from_table;

	if (bytes_y < bytes_x_from_table)
	{
		return -1;
	}
	else if (bytes_y > bytes_x_from_table)
	{
		return 1;
	}
	return 0;
}


__constant__ const mp_number tripleNegativeGx = { {0xbb17b196, 0xf2287bec, 0x76958573, 0xf82c096e, 0x946adeea, 0xff1ed83e, 0x1269ccfa, 0x92c4cc83 } };
__constant__ mp_number negativeDoubleGy = { { 0xf621a970, 0x388fa11f, 0x4d0aa833, 0xfa2f6891, 0x1c221151, 0xbb49f7f8, 0x4d4788ca, 0x9075b4ee } };
__constant__ const mp_number negativeGy = { {0xfb10d4b8, 0x9c47d08f, 0xa6855419, 0xfd17b448, 0x0e1108a8, 0x5da4fbfc, 0x26a3c465, 0x483ada77 } };
__constant__ mp_number negativeGx = { {0xe907e497, 0xa60d7ea3, 0xd231d726, 0xfd640324, 0x3178f4f8, 0xaa5f9d6a, 0x06234453, 0x86419981 } };
__constant__ point negativeG = { { 0x16f81798, 0x59f2815b, 0x2dce28d9, 0x029bfcdb, 0xce870b07, 0x55a06295, 0xf9dcbbac, 0x79be667e },{0x04ef2777, 0x63b82f6f, 0x597aabe6, 0x02e84bb7, 0xf1eef757, 0xa25b0403, 0xd95c3b9a, 0xb7c52588 } };



__device__
int find_in_table_8_bytes(const point* const key, const tableStruct* table, uint64_t* line_in_table_find) {
	int find = 0;
	bool search_state = true;
	uint64_t line_cnt = table->size / 8;
	uint64_t interval = line_cnt / 3;

	uint64_t num_line_next = 0;
	uint64_t num_line_last = 0;

	while (num_line_next < line_cnt) {
		num_line_last = num_line_next;
		uint64_t bytes_from_table;


		if (interval == 0) {
			search_state = false;
		}
		if (search_state) {
			num_line_next += interval;

			if (num_line_next >= line_cnt) {
				num_line_next = num_line_last;
				interval = interval / 2;
				continue;
			}
			bytes_from_table = table->table[num_line_next];
			*line_in_table_find = num_line_next;
		}
		else {
			bytes_from_table = table->table[num_line_next];
			*line_in_table_find = num_line_next;
			num_line_next += 1;
		}
		int cmp = comp_key(key, bytes_from_table);
		//REVERSE32_FOR_HASH(bytes_from_table, bytes_from_table);
		//int cmp = comp_key_test(key, bytes_from_table);
		if (search_state) {
			if (cmp < 0) {
				if (interval < 20) {
					search_state = false;
				}
				else
				{
					interval = interval / 2;
				}
				num_line_next = num_line_last;
				continue;
			}
			else if (cmp == 0) {
				search_state = false;
			}
			else {
				continue;
			}
		}


		if (cmp <= 0) {
			if (cmp == 0)
				find = 1;
			break;
		}
	}

	if (find == 1) {
		return 1;
	}
	return 0;
}

__global__ void dev_crack_init(const point* const precomp, mp_number* const pDeltaX, mp_number* const pPrevLambda, point* publicKey) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	mp_number tmp1, tmp2;
	//point tmp3;

	point pubKey; //public key = publicKey - G*2^192*id
	point g2192; //G*2^192
	for (int i = 0; i < 8; i++)
	{
		pubKey.x.d[i] = publicKey->x.d[i];
		pubKey.y.d[i] = publicKey->y.d[i];
	}
	if (idx != 0) {
		uint32_t num = idx;
		mul_G(precomp, &g2192, 8 * 255 * 3, num); //calculate G*2^192*id
		//-G*2^192*id
		mp_number zero = { {0} };
		mp_mod_sub(&g2192.y, &zero, &g2192.y); //calculate negative y coordinate
		point_add(&pubKey, &pubKey, &g2192); //publicKey + (-G*2^192*id)
	}

	// Calculate current lambda in this point
	mp_mod_sub_gx(&tmp1, &pubKey.x);
	mp_mod_inverse(&tmp1);

	mp_mod_sub_gy(&tmp2, &pubKey.y);
	mp_mod_mul(&tmp1, &tmp1, &tmp2);

	// Jump to next point (precomp[0] is the generator point G)
	//tmp3 = precomp[0];
	point_add(&pubKey, &negativeG, &pubKey);
	// pDeltaX should contain the delta (x - G_x)
	mp_mod_sub_gx(&pubKey.x, &pubKey.x);

	pDeltaX[idx] = pubKey.x;
	pPrevLambda[idx] = tmp1;

}

__global__ void profanity_inverse(const mp_number* const pDeltaX, mp_number* const pInverse) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	const size_t id = idx * PROFANITY_INVERSE_SIZE;

	mp_number copy1, copy2;
	mp_number buffer[PROFANITY_INVERSE_SIZE];
	mp_number buffer2[PROFANITY_INVERSE_SIZE];

	// We initialize buffer and buffer2 such that:
	// buffer[i] = pDeltaX[id] * pDeltaX[id + 1] * pDeltaX[id + 2] * ... * pDeltaX[id + i]
	// buffer2[i] = pDeltaX[id + i]
	buffer[0] = pDeltaX[id];
	for (uint32_t i = 1; i < PROFANITY_INVERSE_SIZE; ++i) {
		buffer2[i] = pDeltaX[id + i];
		mp_mod_mul(&buffer[i], &buffer2[i], &buffer[i - 1]);
	}

	// Take the inverse of all x-values combined
	copy1 = buffer[PROFANITY_INVERSE_SIZE - 1];
	mp_mod_inverse(&copy1);

	// We multiply in -2G_y together with the inverse so that we have:
	//            - 2 * G_y
	//  ----------------------------
	//  x_0 * x_1 * x_2 * x_3 * ...
	mp_mod_mul(&copy1, &copy1, &negativeDoubleGy);

	// Multiply out each individual inverse using the buffers
	for (uint32_t i = PROFANITY_INVERSE_SIZE - 1; i > 0; --i) {
		mp_mod_mul(&copy2, &copy1, &buffer[i - 1]);
		mp_mod_mul(&copy1, &copy1, &buffer2[i]);
		pInverse[id + i] = copy2;
	}

	pInverse[id] = copy1;
}

__global__ void dev_crack_search_only_gpu(mp_number* const pDeltaX, mp_number* const pInverse, mp_number* const pPrevLambda, const tableStruct* __restrict__ tables, resultFound* __restrict__ m_memResult) {
	const size_t idx = blockIdx.x * blockDim.x + threadIdx.x;;

	mp_number dX = pDeltaX[idx];
	mp_number tmp = pInverse[idx];
	mp_number lambda = pPrevLambda[idx];

	// λ' = - (2G_y) / d' - λ <=> lambda := pInversedNegativeDoubleGy[id] - pPrevLambda[id]
	mp_mod_sub(&lambda, &tmp, &lambda);

	// λ² = λ * λ <=> tmp := lambda * lambda = λ²
	mp_mod_mul(&tmp, &lambda, &lambda);

	// d' = λ² - d - 3g = (-3g) - (d - λ²) <=> x := tripleNegativeGx - (x - tmp)
	mp_mod_sub(&dX, &dX, &tmp);
	mp_mod_sub_const(&dX, &tripleNegativeGx, &dX);

	pDeltaX[idx] = dX;
	pPrevLambda[idx] = lambda;

	// Calculate y from dX and lambda
	// y' = (-G_Y) - λ * d' <=> p.y := negativeGy - (p.y * p.x)
	mp_mod_mul(&tmp, &lambda, &dX);
	mp_mod_sub_const(&tmp, &negativeGy, &tmp);

	// Restore X coordinate from delta value
	mp_mod_sub(&dX, &dX, &negativeGx);
	point pubKey;
	pubKey.x.d[0] = dX.d[0];
	pubKey.x.d[1] = dX.d[1];
	pubKey.x.d[2] = dX.d[2];
	pubKey.x.d[3] = dX.d[3];
	pubKey.x.d[4] = dX.d[4];
	pubKey.x.d[5] = dX.d[5];
	pubKey.x.d[6] = dX.d[6];
	pubKey.x.d[7] = dX.d[7];
	pubKey.y.d[0] = tmp.d[0];
	pubKey.y.d[1] = tmp.d[1];
	pubKey.y.d[2] = tmp.d[2];
	pubKey.y.d[3] = tmp.d[3];
	pubKey.y.d[4] = tmp.d[4];
	pubKey.y.d[5] = tmp.d[5];
	pubKey.y.d[6] = tmp.d[6];
	pubKey.y.d[7] = tmp.d[7];



	uint8_t num_table = *(uint8_t*)((uint8_t*)&pubKey.x.d[7] + 3);
	int ret = 0;
	uint64_t line_in_table_find;
	if (tables[num_table].size != 0)
	{
		ret = find_in_table_8_bytes(&pubKey, &tables[num_table], &line_in_table_find);
	}
	if (ret == 1)
	{
		m_memResult->score++;
		if (m_memResult->score >= NUM_RESULT_FOUND_KEYS)
		{
			m_memResult->score = 0;
		}
		uint32_t score = m_memResult->score;
		for (int ii = 0; ii < 8; ii++)
		{
			m_memResult->pub_key[score].x.d[ii] = pubKey.x.d[ii];
			m_memResult->pub_key[score].y.d[ii] = pubKey.y.d[ii];
		}
		m_memResult->line_in_tables[score] = line_in_table_find;
		m_memResult->id[score] = idx;
	}
}
__global__ void dev_crack_search_only_cpu(mp_number* const pDeltaX, mp_number* const pInverse, mp_number* const pPrevLambda, point* __restrict__ m_memResult) {
	const size_t idx = blockIdx.x * blockDim.x + threadIdx.x;;

	mp_number dX = pDeltaX[idx];
	mp_number tmp = pInverse[idx];
	mp_number lambda = pPrevLambda[idx];

	// λ' = - (2G_y) / d' - λ <=> lambda := pInversedNegativeDoubleGy[id] - pPrevLambda[id]
	mp_mod_sub(&lambda, &tmp, &lambda);

	// λ² = λ * λ <=> tmp := lambda * lambda = λ²
	mp_mod_mul(&tmp, &lambda, &lambda);

	// d' = λ² - d - 3g = (-3g) - (d - λ²) <=> x := tripleNegativeGx - (x - tmp)
	mp_mod_sub(&dX, &dX, &tmp);
	mp_mod_sub_const(&dX, &tripleNegativeGx, &dX);

	pDeltaX[idx] = dX;
	pPrevLambda[idx] = lambda;

	// Calculate y from dX and lambda
	// y' = (-G_Y) - λ * d' <=> p.y := negativeGy - (p.y * p.x)
	mp_mod_mul(&tmp, &lambda, &dX);
	mp_mod_sub_const(&tmp, &negativeGy, &tmp);

	// Restore X coordinate from delta value
	mp_mod_sub(&dX, &dX, &negativeGx);
	m_memResult[idx].x.d[0] = dX.d[0];
	m_memResult[idx].x.d[1] = dX.d[1];
	m_memResult[idx].x.d[2] = dX.d[2];
	m_memResult[idx].x.d[3] = dX.d[3];
	m_memResult[idx].x.d[4] = dX.d[4];
	m_memResult[idx].x.d[5] = dX.d[5];
	m_memResult[idx].x.d[6] = dX.d[6];
	m_memResult[idx].x.d[7] = dX.d[7];
	m_memResult[idx].y.d[0] = tmp.d[0];
	m_memResult[idx].y.d[1] = tmp.d[1];
	m_memResult[idx].y.d[2] = tmp.d[2];
	m_memResult[idx].y.d[3] = tmp.d[3];
	m_memResult[idx].y.d[4] = tmp.d[4];
	m_memResult[idx].y.d[5] = tmp.d[5];
	m_memResult[idx].y.d[6] = tmp.d[6];
	m_memResult[idx].y.d[7] = tmp.d[7];
}

__global__ void dev_crack_search_gpu_cpu(mp_number* const pDeltaX, mp_number* const pInverse, mp_number* const pPrevLambda, const tableStruct* __restrict__ tables, point* __restrict__ m_memResultKeys, resultFound* __restrict__ m_memResult) {
	const size_t idx = blockIdx.x * blockDim.x + threadIdx.x;;

	mp_number dX = pDeltaX[idx];
	mp_number tmp = pInverse[idx];
	mp_number lambda = pPrevLambda[idx];

	// λ' = - (2G_y) / d' - λ <=> lambda := pInversedNegativeDoubleGy[id] - pPrevLambda[id]
	mp_mod_sub(&lambda, &tmp, &lambda);

	// λ² = λ * λ <=> tmp := lambda * lambda = λ²
	mp_mod_mul(&tmp, &lambda, &lambda);

	// d' = λ² - d - 3g = (-3g) - (d - λ²) <=> x := tripleNegativeGx - (x - tmp)
	mp_mod_sub(&dX, &dX, &tmp);
	mp_mod_sub_const(&dX, &tripleNegativeGx, &dX);

	pDeltaX[idx] = dX;
	pPrevLambda[idx] = lambda;

	// Calculate y from dX and lambda
	// y' = (-G_Y) - λ * d' <=> p.y := negativeGy - (p.y * p.x)
	mp_mod_mul(&tmp, &lambda, &dX);
	mp_mod_sub_const(&tmp, &negativeGy, &tmp);

	// Restore X coordinate from delta value
	mp_mod_sub(&dX, &dX, &negativeGx);
	point pubKey;
	pubKey.x.d[0] = dX.d[0];
	pubKey.x.d[1] = dX.d[1];
	pubKey.x.d[2] = dX.d[2];
	pubKey.x.d[3] = dX.d[3];
	pubKey.x.d[4] = dX.d[4];
	pubKey.x.d[5] = dX.d[5];
	pubKey.x.d[6] = dX.d[6];
	pubKey.x.d[7] = dX.d[7];
	pubKey.y.d[0] = tmp.d[0];
	pubKey.y.d[1] = tmp.d[1];
	pubKey.y.d[2] = tmp.d[2];
	pubKey.y.d[3] = tmp.d[3];
	pubKey.y.d[4] = tmp.d[4];
	pubKey.y.d[5] = tmp.d[5];
	pubKey.y.d[6] = tmp.d[6];
	pubKey.y.d[7] = tmp.d[7];

	m_memResultKeys[idx].x.d[0] = dX.d[0];
	m_memResultKeys[idx].x.d[1] = dX.d[1];
	m_memResultKeys[idx].x.d[2] = dX.d[2];
	m_memResultKeys[idx].x.d[3] = dX.d[3];
	m_memResultKeys[idx].x.d[4] = dX.d[4];
	m_memResultKeys[idx].x.d[5] = dX.d[5];
	m_memResultKeys[idx].x.d[6] = dX.d[6];
	m_memResultKeys[idx].x.d[7] = dX.d[7];
	m_memResultKeys[idx].y.d[0] = tmp.d[0];
	m_memResultKeys[idx].y.d[1] = tmp.d[1];
	m_memResultKeys[idx].y.d[2] = tmp.d[2];
	m_memResultKeys[idx].y.d[3] = tmp.d[3];
	m_memResultKeys[idx].y.d[4] = tmp.d[4];
	m_memResultKeys[idx].y.d[5] = tmp.d[5];
	m_memResultKeys[idx].y.d[6] = tmp.d[6];
	m_memResultKeys[idx].y.d[7] = tmp.d[7];


	uint8_t num_table = *(uint8_t*)((uint8_t*)&pubKey.x.d[7] + 3);
	int ret = 0;
	uint64_t line_in_table_find;
	if (tables[num_table].size != 0)
	{
		const uint64_t bytes_y = *(const uint64_t*)&pubKey.x.d[6];
		ret = find_in_table_8_bytes(&pubKey, &tables[num_table], &line_in_table_find);
	}
	if (ret == 1)
	{
		m_memResult->score++;
		if (m_memResult->score >= NUM_RESULT_FOUND_KEYS)
		{
			m_memResult->score = 0;
		}
		uint32_t score = m_memResult->score;
		for (int ii = 0; ii < 8; ii++)
		{
			m_memResult->pub_key[score].x.d[ii] = pubKey.x.d[ii];
			m_memResult->pub_key[score].y.d[ii] = pubKey.y.d[ii];
		}
		m_memResult->line_in_tables[score] = line_in_table_find;
		m_memResult->id[score] = idx;
	}
}


