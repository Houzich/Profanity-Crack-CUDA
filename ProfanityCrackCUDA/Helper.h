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
#include <string>
#include <iostream>
#include <chrono>
#include <thread>
#include <fstream>
#include <string>
#include <memory>
#include <sstream>
#include <iomanip>
#include <vector>
#include <map>
#include <omp.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "stdafx.h"
#include "../Tools/utils.h"
#include "precomp.hpp"


class host_buffers_class
{
public:
	tableStruct tables_gpu[256] = { NULL };
	tableStruct tables_cpu[256] = { NULL };
	uint64_t size_tables_gpu = 0;
	uint64_t size_tables_cpu = 0;
	point public_key;
	resultFound result;
	point* result_keys;
	uint64_t size_result_keys = 0;
	uint64_t memory_size = 0;
public:
	host_buffers_class()
	{
	}

	int alignedMalloc(void** point, uint64_t size, uint64_t* all_ram_memory_size, std::string buff_name) {
		*point = _aligned_malloc(size, 4096);
		if (NULL == *point) { fprintf(stderr, "_aligned_malloc (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return 1; }
		*all_ram_memory_size += size;
		//std::cout << "MALLOC RAM MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	int mallocHost(void** point, uint64_t size, uint64_t* all_ram_memory_size, std::string buff_name) {
		if (cudaMallocHost((void**)point, size) != cudaSuccess) {
			fprintf(stderr, "cudaMallocHost (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return -1;
		}
		*all_ram_memory_size += size;
		//std::cout << "MALLOC RAM MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	int malloc(size_t wallets_in_round_gpu, int mode)
	{
		memory_size = 0;
		if ((mode == MODE_SEARCH_ONLY_IN_CPU) || (mode == MODE_SEARCH_IN_GPU_AND_CPU))
		{
			if (mallocResultKeys(wallets_in_round_gpu) != 0) return -1;
		}
		//std::cout << "MALLOC RAM MEMORY SIZE (HOST): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}

	int mallocResultKeys(size_t wallets_in_round_gpu)
	{
		size_result_keys = sizeof(point) * wallets_in_round_gpu;
		if (alignedMalloc((void**)&result_keys, sizeof(point) * wallets_in_round_gpu, &memory_size, "result_keys") != 0) return -1;
		//std::cout << "MALLOC ALL RAM MEMORY SIZE (HOST): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}

	void setPublicKey(point pub_key) {
		for (uint32_t i = 0; i < 8; i++)
		{
			public_key.x.d[i] = pub_key.x.d[i];
			public_key.y.d[i] = pub_key.y.d[i];
		}
	}

	void freeTableBuffersGPU(void) {
		for (int x = 0; x < 256; x++) {
			if (tables_gpu[x].table != NULL)
			{
				free(tables_gpu[x].table);
				tables_gpu[x].table = NULL;
			}			
		}
	}
	void freeTableBuffersCPU(void) {
		for (int x = 0; x < 256; x++) {
			if (tables_cpu[x].table != NULL)
			{
				free(tables_cpu[x].table);
				tables_cpu[x].table = NULL;
			}
		}
	}
	void calcSizeTableBuffersGPU(void) {
		size_tables_gpu = 0;
		for (int x = 0; x < 256; x++) {
			if (tables_gpu[x].table != NULL)
			{
				size_tables_gpu += tables_gpu[x].size;
			}
		}
	}
	void calcSizeTableBuffersCPU(void) {
		size_tables_cpu = 0;
		for (int x = 0; x < 256; x++) {
			if (tables_cpu[x].table != NULL)
			{
				size_tables_cpu += tables_cpu[x].size;
			}
		}
	}
	
	uint64_t* getTable(uint32_t num)
	{
		return tables_cpu[num].table;
	}
	size_t getSizeTable(uint32_t num)
	{
		return tables_cpu[num].size;
	}



	~host_buffers_class()
	{
		freeTableBuffersGPU();
		freeTableBuffersCPU();
		_aligned_free(result_keys);
	}

};

class device_buffers_class
{
public:
	tableStruct tables[256] = { NULL };
	tableStruct* dev_tables;

	point* public_key = NULL;
	point* extension_public_key = NULL;
	point* precomp = NULL;
	resultFound* result = NULL;
	point* result_keys = NULL;
	uint64_t memory_size = 0;


	mp_number* pDeltaX = NULL;
	mp_number* pInverse = NULL;
	mp_number* pPrevLambda = NULL;

public:
	device_buffers_class()
	{
	}

	int cudaMallocDevice(uint8_t** point, uint64_t size, uint64_t* all_gpu_memory_size, std::string buff_name) {
		if (cudaMalloc(point, size) != cudaSuccess) {
			fprintf(stderr, "cudaMalloc (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return -1;
		}
		*all_gpu_memory_size += size;

		//std::cout << "MALLOC GPU MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}
	int malloc(size_t wallets_in_round_gpu, int mode)
	{
		memory_size = 0;	
		if (cudaMallocDevice((uint8_t**)&dev_tables, sizeof(tableStruct) * 256, &memory_size, "dev_tables") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&public_key, sizeof(point), &memory_size, "public_key") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&extension_public_key, sizeof(point) * wallets_in_round_gpu, &memory_size, "extension_public_key") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&precomp, sizeof(g_precomp), &memory_size, "precomp") != 0) return -1;
		if ((mode == MODE_SEARCH_ONLY_IN_GPU) || (mode == MODE_SEARCH_IN_GPU_AND_CPU))
		{
			if (cudaMallocDevice((uint8_t**)&result, sizeof(resultFound), &memory_size, "result") != 0) return -1;
		}
		if ((mode == MODE_SEARCH_ONLY_IN_CPU) || (mode == MODE_SEARCH_IN_GPU_AND_CPU))
		{
			if (cudaMallocDevice((uint8_t**)&result_keys, sizeof(point) * wallets_in_round_gpu, &memory_size, "result_keys") != 0) return -1;
		}
		if (cudaMallocDevice((uint8_t**)&pDeltaX, sizeof(mp_number) * wallets_in_round_gpu, &memory_size, "pDeltaX") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&pInverse, sizeof(mp_number) * wallets_in_round_gpu, &memory_size, "pInverse") != 0) return -1;
		if (cudaMallocDevice((uint8_t**)&pPrevLambda, sizeof(mp_number) * wallets_in_round_gpu, &memory_size, "pPrevLambda") != 0) return -1;

		std::cout << "MALLOC ALL MEMORY SIZE (GPU): " << std::to_string((float)(memory_size) / (1024.0f * 1024.0f)) << " MB\n";
		return 0;
	}

	void freeTableBuffers(void) {
		for (int x = 0; x < 256; x++) {
			if (tables[x].table != NULL)
				cudaFree((void *)tables[x].table);
		}
		cudaFree(dev_tables);
	}

	~device_buffers_class()
	{
		freeTableBuffers();
		cudaFree(dev_tables);
		cudaFree(public_key);
		cudaFree(precomp);
		cudaFree(result);
		cudaFree(result_keys);
	}
};


class DataClass
{
public:
	device_buffers_class dev;
	host_buffers_class host;

	cudaStream_t stream1 = NULL;

	size_t wallets_in_round_gpu = 0;
	int mode = -1;
public:
	DataClass()
	{

	}

	int malloc(size_t cuda_grid, size_t cuda_block, int mode, bool alloc_buff_for_save)
	{
		size_t num_wallet = cuda_grid * cuda_block;

		this->mode = mode;
		if (cudaStreamCreate(&stream1) != cudaSuccess) { fprintf(stderr, "cudaStreamCreate failed!  stream1"); return -1; }
		if (dev.malloc(num_wallet, mode) != 0) return -1;
		if (host.malloc(num_wallet, mode) != 0) return -1;
		this->wallets_in_round_gpu = num_wallet;
		return 0;
	}
	~DataClass()
	{
		cudaStreamDestroy(stream1);
	}
};


cudaError_t deviceSynchronize(std::string name_kernel);
void devicesInfo(void);

