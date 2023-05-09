
/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
// Includes
#include <stdexcept>
#include <iostream>
#include <thread>
#include <sstream>
#include <iomanip>
#include <random>
#include <thread>
#include <algorithm>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "precomp.hpp"
#include "Dispatcher.hpp"
#include "Data/Find.h"
#include <GPU.h>


//(any random 256-bit number from 0x1 to 0xFFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFE BAAE DCE6 AF48 A03B BFD2 5E8C D036 4140)
uint64_t* Dispatcher::Device::genPrivateKeys(private_key* priv_keys, size_t size, uint64_t* init_value) {

	uint64_t value[4];
	value[0] = init_value[0];
	value[1] = init_value[1];
	value[2] = init_value[2];
	value[3] = init_value[3];

	for (size_t i = 0; i < size; i++)
	{
		priv_keys[i].key[0] = value[0];
		priv_keys[i].key[1] = value[1];
		priv_keys[i].key[2] = value[2];
		priv_keys[i].key[3] = value[3];
		tools::incUlong4(value);
	}
	return value;
}


Dispatcher::Device::Device(
	Dispatcher& parent,
	DataClass& Data,
	point public_key) :
	m_parent(parent),
	data(Data),
	public_key(public_key),
	m_round(0),
	m_speed(SPEED_SAMPLES)
{

}

Dispatcher::Device::~Device() {

}
Dispatcher::Dispatcher(DataClass& data, ConfigClass& config) :
	data(data),
	config(config)
{

}

Dispatcher::~Dispatcher() {

}

void Dispatcher::addDevice(DataClass& data, point public_key) {
	Device* pDevice = new Device(*this, data, public_key);
	Dev = pDevice;
}


int Dispatcher::cudaMallocDevice(uint8_t** point, uint64_t size, uint64_t* all_gpu_memory_size, std::string buff_name) {
	if (cudaMalloc(point, size) != cudaSuccess) {
		fprintf(stderr, "cudaMalloc (%s) failed! Size: %s", buff_name.c_str(), tools::formatWithCommas(size).data()); return -1;
	}
	*all_gpu_memory_size += size;
	//if(size == 0)
	//	std::cout << "!!! WORNING !!! MALLOC GPU MEMORY SIZE (" << buff_name << "): 0.000000 MB\n";
	//else
	//	std::cout << "MALLOC GPU MEMORY SIZE (" << buff_name << "): " << std::to_string((float)size / (1024.0f * 1024.0f)) << " MB\r";
	return 0;
}

int Dispatcher::memsetGlobal(int mode)
{
	if (cudaMemcpyAsync(this->data.dev.public_key, &this->data.host.public_key, sizeof(point), cudaMemcpyHostToDevice, this->data.stream1) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.public_key failed!"); return -1; }
	if (cudaMemcpyAsync(this->data.dev.precomp, g_precomp, sizeof(g_precomp), cudaMemcpyHostToDevice, this->data.stream1) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.precomp failed!"); return -1; }
	if((mode == MODE_SEARCH_IN_GPU_AND_CPU) || (mode == MODE_SEARCH_ONLY_IN_GPU))
		if (cudaMemsetAsync(this->data.dev.result, 0, sizeof(resultFound), this->data.stream1) != cudaSuccess) { fprintf(stderr, "cudaMemset Board->dev.ret failed!"); return -1; }
	return 0;
}

int Dispatcher::memsetSearchGPU() {
	std::cout << "Initialization..." << std::endl;
	std::cout << "May take several minutes..." << std::endl;
	size_t memory_size = 0;
	for (int i = 0; i < 256; i++)
	{
		std::string name = "Table " + tools::byteToHexString(i);
		if (cudaMallocDevice((uint8_t**)&this->data.dev.tables[i].table, this->data.host.tables_gpu[i].size, &memory_size, name.c_str()) != 0)
		{
			std::cout << "Error cudaMallocDevice(), Board->dev.table[i]! i = " << i << std::endl;
			return -1;
		}
		this->data.dev.tables[i].size = this->data.host.tables_gpu[i].size;
		this->data.dev.memory_size += this->data.host.tables_gpu[i].size;
	}
	//std::cout << "MALLOC MEMORY SIZE (TABLES GPU): " << std::to_string((float)memory_size / (1024.0f * 1024.0f)) << " MB\n";

	std::cout << "INIT GPU ... \n";
	for (int i = 0; i < 256; i++)
	{
		if (cudaMemcpy((void*)this->data.dev.tables[i].table, this->data.host.tables_gpu[i].table, this->data.host.tables_gpu[i].size, cudaMemcpyHostToDevice) != cudaSuccess)
		{
			std::cout << "cudaMemcpy to Board->dev.table[i] failed! i = " << i << std::endl;
			return -1;
		}
		const size_t percentDone = (i * 100 / 255);
		std::cout << "  " << percentDone << "%\r";
	}
	if (cudaMemcpy(this->data.dev.dev_tables, this->data.dev.tables, 256 * sizeof(tableStruct), cudaMemcpyHostToDevice) != cudaSuccess) { fprintf(stderr, "cudaMemcpyAsync to Board->dev.table failed!"); return -1; }
	
	if (deviceSynchronize("memsetGPU") != cudaSuccess) return -1;

	this->data.host.freeTableBuffersGPU();

	return 0;
}

int Dispatcher::init(int mode) {
	memsetGlobal(mode);
	std::cout << std::endl;
	//dev_crack_init << <(uint32_t)this->config.cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> > (this->data.dev.precomp, this->data.dev.extension_public_key, this->data.dev.public_key);
	dev_crack_init << <(uint32_t)this->config.cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> > (this->data.dev.precomp, this->data.dev.pDeltaX, this->data.dev.pPrevLambda, this->data.dev.public_key);
	if (deviceSynchronize("crack_init") != cudaSuccess) return -1; //


	return 0;
}

int Dispatcher::startSearchOnlyCPU() {
	uint32_t cuda_grid = (uint32_t)this->config.cuda_grid / PROFANITY_INVERSE_SIZE;
	profanity_inverse << <(uint32_t)cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> > (this->data.dev.pDeltaX, this->data.dev.pInverse);
	dev_crack_search_only_cpu << <(uint32_t)this->config.cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> > (
		this->data.dev.pDeltaX,
		this->data.dev.pInverse,
		this->data.dev.pPrevLambda,
		this->data.dev.result_keys);

	cudaError_t cudaStatus = cudaSuccess;
	if (deviceSynchronize("crack") != cudaSuccess) return -1; //
	return 0;
}


int Dispatcher::endSearchOnlyCPU() {
	cudaError_t cudaStatus = cudaSuccess;
	cudaStatus = cudaMemcpy(this->data.host.result_keys, this->data.dev.result_keys, this->data.host.size_result_keys, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy result failed!");
		return -1;
	}
	return 0;
}

int Dispatcher::startSearchOnlyGPU() {

	uint32_t cuda_grid = (uint32_t)this->config.cuda_grid / PROFANITY_INVERSE_SIZE;
	profanity_inverse <<<(uint32_t)cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1>>>(this->data.dev.pDeltaX, this->data.dev.pInverse);
	dev_crack_search_only_gpu << <(uint32_t)this->config.cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> >(
		this->data.dev.pDeltaX,
		this->data.dev.pInverse,
		this->data.dev.pPrevLambda,
		this->data.dev.dev_tables,
		this->data.dev.result);
	
	if (deviceSynchronize("crack") != cudaSuccess) return -1; //
	return 0;
}


int Dispatcher::endSearchOnlyGPU() {
	cudaError_t cudaStatus = cudaSuccess;
	cudaStatus = cudaMemcpy(&this->data.host.result, this->data.dev.result, sizeof(resultFound), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy result failed!");
		return -1;
	}
	return 0;
}

int Dispatcher::startSearchGPUAndCPU() {

	uint32_t cuda_grid = (uint32_t)this->config.cuda_grid / PROFANITY_INVERSE_SIZE;
	profanity_inverse << <(uint32_t)cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> > (this->data.dev.pDeltaX, this->data.dev.pInverse);
	dev_crack_search_gpu_cpu << <(uint32_t)this->config.cuda_grid, (uint32_t)this->config.cuda_block, 0, this->data.stream1 >> > (
		this->data.dev.pDeltaX,
		this->data.dev.pInverse,
		this->data.dev.pPrevLambda,
		this->data.dev.dev_tables,
		this->data.dev.result_keys,
		this->data.dev.result);

	if (deviceSynchronize("crack") != cudaSuccess) return -1; //
	return 0;
}


int Dispatcher::endSearchGPUAndCPU() {
	cudaError_t cudaStatus = cudaSuccess;
	cudaStatus = cudaMemcpy(&this->data.host.result, this->data.dev.result, sizeof(resultFound), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy result failed!");
		return -1;
	}
	cudaStatus = cudaMemcpy(this->data.host.result_keys, this->data.dev.result_keys, this->data.host.size_result_keys, cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy result_keys failed!");
		return -1;
	}
	return 0;
}





void Dispatcher::dispatch(Device& d) {

}

void Dispatcher::handleResult() {
	//point* res = Dev->result;
	//if (Search_Keys_In_Memory(Dev->data, res, m_size, Dev->m_round, config) == 1) {
	//	m_quit = true;
	//}
}



// This is run when m_mutex is held.
void Dispatcher::printSpeed(size_t round) {
	std::string strGPUs;
	double speedTotal = 0;

	const auto curSpeed = Dev->m_speed.getSpeed();
	speedTotal += curSpeed;
	strGPUs += " GPU: " + formatSpeed(curSpeed);


	const std::string strVT100ClearLine = "\33[2K\r";
	std::cerr << strVT100ClearLine << "Total: " << formatSpeed(speedTotal) << " -" << strGPUs << ", Round: " << round << '\r' << std::flush;
}


std::string Dispatcher::formatSpeed(double f) {
	const std::string S = " KMGT";

	unsigned int index = 0;
	while (f > 1000.0f && index < S.size()) {
		f /= 1000.0f;
		++index;
	}

	std::ostringstream ss;
	ss << std::fixed << std::setprecision(5) << (double)f << " " << S[index] << "H/s";
	return ss.str();
}
