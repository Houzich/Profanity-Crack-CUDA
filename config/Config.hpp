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
#include <string>


struct ConfigClass
{
public:
	std::string folder_keys = "";
	std::string folder_8_bytes_keys_gpu = "";
	std::string folder_8_bytes_keys_cpu = "";
	std::string file_public_keys = "";
	uint64_t max_rounds = 0;
	uint64_t num_files = 256;
	uint64_t cuda_grid = 1024 * 16; //1024 * 16
	uint64_t cuda_block = 255;
public:
	ConfigClass()
	{
	}
	~ConfigClass()
	{
	}
};


int parse_config(ConfigClass* config, std::string path);

