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
#include <vector>
#include <string>
#include "../ProfanityCrackCUDA/stdafx.h"
namespace tools {
	std::string getFileName(std::string path, size_t num_file, std::string extension);
	size_t getBinaryFileSize(std::string filename);
	void getFromBinaryFile(std::string filename, void* data, size_t size, size_t position);
	void generateRandomWordsIndex(uint16_t* buff, size_t len);
	int pushToMemory(uint8_t* addr_buff, std::vector<std::string>& lines, int max_len);
	int readPublicKeys(std::string filename, std::vector<std::string>& pubKeys);
	int readTables(tableStruct* tables, std::string path);
	void saveResult(private_key privateKey, point publicKey);
}