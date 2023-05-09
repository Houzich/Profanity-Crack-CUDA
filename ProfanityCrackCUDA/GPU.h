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

#include <stdint.h>
#include "stdafx.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

__global__ void dev_crack_init(const point* const precomp, mp_number* const pDeltaX, mp_number* const pPrevLambda, point* publicKey);
__global__ void profanity_inverse(const mp_number* const pDeltaX, mp_number* const pInverse);
__global__ void dev_crack_search_only_gpu(mp_number* const pDeltaX, mp_number* const pInverse, mp_number* const pPrevLambda, const tableStruct* __restrict__ tables, resultFound* __restrict__ m_memResult);
__global__ void dev_crack_search_only_cpu(mp_number* const pDeltaX, mp_number* const pInverse, mp_number* const pPrevLambda, point* __restrict__ m_memResult);
__global__ void dev_crack_search_gpu_cpu(mp_number* const pDeltaX, mp_number* const pInverse, mp_number* const pPrevLambda, const tableStruct* __restrict__ tables, point* __restrict__ m_memResultKeys, resultFound* __restrict__ m_memResult);
