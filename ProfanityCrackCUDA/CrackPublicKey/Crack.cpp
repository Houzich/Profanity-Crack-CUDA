/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <algorithm>
#include <stdexcept>
#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdlib>
#include <cstdio>
#include <vector>
#include <map>
#include <set>

#include "Helper.h"
#include "Dispatcher.hpp"
#include "../../config/Config.hpp"
#include <Find.h>



int crack_public_key(DataClass& data, std::vector<std::string>& publicKeys, ConfigClass& config) {
	point pubKey = { {0} };
	Dispatcher d(data, config);
	d.addDevice(data, pubKey);
	int mode = data.mode;


	if (mode != MODE_SEARCH_ONLY_IN_CPU)
		d.memsetSearchGPU();

	for (const std::string& pubKeyStr : publicKeys) {
		uint32_t prev_score = 0;
		std::cout << "Crack Public Key: " << pubKeyStr << "\n";
		tools::stringToPoint(pubKeyStr, &pubKey);
		data.host.setPublicKey(pubKey);
		d.Dev->public_key = pubKey;
		d.Dev->m_round = 0;
		d.init(mode);

		while (1)
		{
			if (mode == MODE_SEARCH_ONLY_IN_GPU)
			{
				d.startSearchOnlyGPU();
				d.endSearchOnlyGPU();
			}
			else if (mode == MODE_SEARCH_ONLY_IN_CPU)
			{
				d.startSearchOnlyCPU();
				d.endSearchOnlyCPU();
			}
			else if (mode == MODE_SEARCH_IN_GPU_AND_CPU)
			{
				d.startSearchGPUAndCPU();
				d.endSearchGPUAndCPU();
			}

			++d.Dev->m_round;

			if (mode == MODE_SEARCH_ONLY_IN_GPU)
			{
				if (checkResult(data, &data.host.result, prev_score, d.Dev->m_round, config) == 1) {
					break;
				}
			}
			else if (mode == MODE_SEARCH_ONLY_IN_CPU)
			{
				if (searchKeysCPU(data.host, data.host.result_keys, data.wallets_in_round_gpu, d.Dev->m_round, config) == 1) {
					break;
				}
			}
			else if (mode == MODE_SEARCH_IN_GPU_AND_CPU)
			{
				if (checkResult(data, &data.host.result, prev_score, d.Dev->m_round, config) == 1) {
					break;
				}
				if (searchKeysCPU(data.host, data.host.result_keys, data.wallets_in_round_gpu, d.Dev->m_round, config) == 1) {
					break;
				}
			}

			d.Dev->m_speed.sample((double)data.wallets_in_round_gpu);

			if (d.Dev->m_round < 20) d.printSpeed(d.Dev->m_round);
			else if((d.Dev->m_round - 1) % 500 == 0) d.printSpeed(d.Dev->m_round);

			if ((mode == MODE_SEARCH_ONLY_IN_GPU) || (mode == MODE_SEARCH_IN_GPU_AND_CPU))
			{
				prev_score = data.host.result.score;
				if (prev_score >= NUM_RESULT_FOUND_KEYS)
				{
					std::cerr << "ERROR: prev_score = " << prev_score << std::endl;
					std::cerr << "ERROR: prev_score = " << prev_score << std::endl;
					std::cerr << "ERROR: prev_score = " << prev_score << std::endl;
					std::cerr << "ERROR: prev_score = " << prev_score << std::endl;
					return -1;
				}
			}

			if (d.Dev->m_round >= config.max_rounds)
			{
				std::cout << "Reached the maximum number of rounds! round = " << config.max_rounds << "\n";
				break;
			}
		}
	}
	return 0;
}

