/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include "../ProfanityCrackCUDA/stdafx.h"
#include <stdio.h>
#include <windows.h>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <omp.h>
#include <iostream>

#include "base58.h"
#include "tools.h"
#include "utils.h"
#include "segwit_addr.h"

namespace tools {
	static LARGE_INTEGER performanceCountStart;
	static LARGE_INTEGER performanceCountStop;

	void start_time(void) {
		QueryPerformanceCounter(&performanceCountStart);
	}

	void stop_time(void) {
		QueryPerformanceCounter(&performanceCountStop);
	}

	void stop_time_and_calc(float* delay) {
		stop_time();
		LARGE_INTEGER perfFrequency;
		QueryPerformanceFrequency(&perfFrequency);
		*delay = (1000.0f * (float)(performanceCountStop.QuadPart - performanceCountStart.QuadPart) / (float)perfFrequency.QuadPart);
	}

	void printPrivateKey(char* title, private_key* privKey) {
		printf("%s%.16llx%.16llx%.16llx%.16llx\n",
			title,
			privKey->key[3],
			privKey->key[2],
			privKey->key[1],
			privKey->key[0]);
	}

	bool incUlong4(uint64_t* s) {
		if (++s[0] != 0) return false;
		if (++s[1] != 0) return false;
		if (++s[2] != 0) return false;
		if (++s[3] != 0) return false;
		return true; //overflow
	}

	void stringToPoint(std::string str, point* pubKey) {
		for (int i = 0; i < 8; i++) {
			std::string substr = str.substr(((size_t)i * 8), 8);
			pubKey->x.d[7 - i] = (uint32_t)std::stoull(substr, nullptr, 16);
			substr = str.substr(((size_t)i * 8 + 64), 8);
			pubKey->y.d[7 - i] = (uint32_t)std::stoull(substr, nullptr, 16);
		}
	}

	std::string formatWithCommas(double val)
	{
		uint64_t value = (uint64_t)val;
		std::stringstream ss;
		ss.imbue(std::locale("en_US.UTF-8"));
		ss << std::fixed << value;
		return ss.str();
	}

	std::string formatWithCommas(uint64_t value)
	{
		std::stringstream ss;
		ss.imbue(std::locale("en_US.UTF-8"));
		ss << std::fixed << value;
		return ss.str();
	}

	void reverseHashUint32(uint32_t* hash_in, uint32_t* hash_out) {
		uint32_t hash160_reverse[5] = { 0 };
		REVERSE32_FOR_HASH(hash_in[0], hash160_reverse[0]);
		REVERSE32_FOR_HASH(hash_in[1], hash160_reverse[1]);
		REVERSE32_FOR_HASH(hash_in[2], hash160_reverse[2]);
		REVERSE32_FOR_HASH(hash_in[3], hash160_reverse[3]);
		REVERSE32_FOR_HASH(hash_in[4], hash160_reverse[4]);
		hash_out[0] = hash160_reverse[0];
		hash_out[1] = hash160_reverse[1];
		hash_out[2] = hash160_reverse[2];
		hash_out[3] = hash160_reverse[3];
		hash_out[4] = hash160_reverse[4];
	}
	std::vector<uint8_t> hexStringToVector(const std::string& source)
	{
		if (std::string::npos != source.find_first_not_of("0123456789ABCDEFabcdef"))
		{
			// you can throw exception here
			return {};
		}

		union
		{
			uint64_t binary;
			char byte[8];
		} value{};

		auto size = source.size(), offset = (size % 16);
		std::vector<uint8_t> binary{};
		binary.reserve((size + 1) / 2);

		if (offset)
		{
			value.binary = std::stoull(source.substr(0, offset), nullptr, 16);

			for (auto index = (offset + 1) / 2; index--; )
			{
				binary.emplace_back(value.byte[index]);
			}
		}

		for (; offset < size; offset += 16)
		{
			value.binary = std::stoull(source.substr(offset, 16), nullptr, 16);
			for (auto index = 8; index--; )
			{
				binary.emplace_back(value.byte[index]);
			}
		}

		return binary;
	}


	int hexStringToBytes(const std::string& source, uint8_t* bytes, int max_len)
	{
		int len = 0;
		if (std::string::npos != source.find_first_not_of("0123456789ABCDEFabcdef"))
		{
			// you can throw exception here
			return 1;
		}

		union
		{
			uint64_t binary;
			char byte[8];
		} value{};

		auto size = source.size(), offset = (size % 16);

		if (offset)
		{
			value.binary = std::stoull(source.substr(0, offset), nullptr, 16);

			for (auto index = (offset + 1) / 2; index--; )
			{
				if (++len > max_len) return 1;
				*(bytes++) = value.byte[index];
			}
		}

		for (; offset < size; offset += 16)
		{
			value.binary = std::stoull(source.substr(offset, 16), nullptr, 16);
			for (auto index = 8; index--; )
			{
				if (++len > max_len) return 1;
				*(bytes++) = value.byte[index];
			}
		}

		return 0;
	}


	std::string vectorToHexString(std::vector<uint8_t>& data)
	{
		std::stringstream ss;
		ss << std::hex << std::uppercase;
		for (int i = 0; i < data.size(); i++)
			ss << std::setw(2) << std::setfill('0') << (uint16_t)((uint16_t)data[i] & 0xff);
		const std::string hexstr = ss.str();

		return hexstr;
	}

	std::string byteToHexString(uint8_t data)
	{
		std::stringstream ss;
		ss << std::hex << std::uppercase;
		ss << std::setw(2) << std::setfill('0') << (uint16_t)((uint16_t)data & 0xff);
		const std::string hexstr = ss.str();

		return hexstr;
	}

	std::string bytesToHexString(const uint8_t* data, int len)
	{
		std::string hexstr = "";
		for (int i = 0; i < len; i++) {
			hexstr.append(byteToHexString(data[i]));
		}
		return hexstr;
	}

	std::string pointToHEX(point* point) {
		char buff[129] = { 0 };
		snprintf(buff, 129, "%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x",
			point->x.d[7],
			point->x.d[6],
			point->x.d[5],
			point->x.d[4],
			point->x.d[3],
			point->x.d[2],
			point->x.d[1],
			point->x.d[0],
			point->y.d[7],
			point->y.d[6],
			point->y.d[5],
			point->y.d[4],
			point->y.d[3],
			point->y.d[2],
			point->y.d[1],
			point->y.d[0]);
		std::string s(buff, 128);
		return s;
	}

	std::string privateKeyToHEX(private_key* privKey) {
		char buff[65] = {0};
		snprintf(buff, 65, "%.16llx%.16llx%.16llx%.16llx",
			privKey->key[3],
			privKey->key[2],
			privKey->key[1],
			privKey->key[0]);
		std::string s(buff, 64);
		return s;
	}

}
