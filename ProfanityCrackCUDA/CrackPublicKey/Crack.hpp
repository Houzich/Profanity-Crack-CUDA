/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#ifndef HPP_CRACK_PUBLIC_KEY
#define HPP_CRACK_PUBLIC_KEY

#include <string>
#include "Helper.h"
#include "../config/Config.hpp"

int crack_public_key(DataClass& data, std::vector<std::string>& publicKeys, ConfigClass& config);
#endif /* HPP_CRACK_PUBLIC_KEY */
