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
#include "types.hpp"
#include <Helper.h>
#include "../../config/Config.hpp"



int checkResult(DataClass& data, resultFound* result, size_t prev_score, size_t round, ConfigClass& config);
int searchKeysCPU(host_buffers_class& data, point* keys, size_t num_keys, size_t round, ConfigClass& config);



