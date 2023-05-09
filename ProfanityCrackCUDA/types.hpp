/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#ifndef HPP_TYPES
#define HPP_TYPES

#include "defines.h"
#include <cstdint>


#define MP_NWORDS 8

typedef struct {
	uint32_t d[MP_NWORDS];
} mp_number;

typedef struct {
    mp_number x;
    mp_number y;
} point;

typedef struct {
	uint64_t key[8];
} public_key;

typedef struct {
	uint64_t key[4];
} private_key;

#endif /* HPP_TYPES */