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
#include <vector>
#include "../ProfanityCrackCUDA/types.hpp"
namespace tools {
	void start_time(void);
	void stop_time_and_calc(float* delay);
	bool incUlong4(uint64_t* s);
	void printPrivateKey(char* title, private_key* privKey);
	void stringToPoint(std::string str, point* pubKey);
	std::string formatWithCommas(double val);
	std::string formatWithCommas(uint64_t value);
	void reverseHashUint32(uint32_t* hash_in, uint32_t* hash_out);
	std::vector<uint8_t> hexStringToVector(const std::string& source);
	std::string byteToHexString(uint8_t data);
	std::string bytesToHexString(const uint8_t* data, int len);
	int hexStringToBytes(const std::string& source, uint8_t* bytes, int max_len);
	std::string vectorToHexString(std::vector<uint8_t>& data);
	std::string pointToHEX(point* point);
	std::string privateKeyToHEX(private_key* privKey);
}