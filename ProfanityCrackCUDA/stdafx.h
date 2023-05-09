/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */

#pragma once
#include <cstdint>
#include "types.hpp"
//compute_86,sm_86

//#define _CRT_SECURE_NO_WARNINGS
//#define TEST_MODE


//#define USE_REVERSE_64
//#define USE_REVERSE_32

#define FILE_PATH_RESULT "Found.csv"

/* Four of six logical functions used in SHA-384 and SHA-512: */
#define REVERSE32_FOR_HASH(w,x)	{ \
	uint32_t tmp = (w); \
	tmp = (tmp >> 16) | (tmp << 16); \
	(x) = ((tmp & 0xff00ff00UL) >> 8) | ((tmp & 0x00ff00ffUL) << 8); \
}

struct tableStruct {
	uint64_t* table;
	unsigned int size;
};

#define MODE_SEARCH_IN_GPU_AND_CPU (2)
#define MODE_SEARCH_ONLY_IN_GPU (1)
#define MODE_SEARCH_ONLY_IN_CPU (0)

#define NUM_RESULT_FOUND_KEYS 20
#pragma pack(push, 1)
typedef struct {
	point pub_key[NUM_RESULT_FOUND_KEYS];
	uint32_t id[NUM_RESULT_FOUND_KEYS];
	uint32_t line_in_tables[NUM_RESULT_FOUND_KEYS];
	uint32_t score;
} resultFound;
#pragma pack(pop)

