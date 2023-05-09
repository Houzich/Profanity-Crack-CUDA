/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>

#include "CrackPublicKey/Crack.hpp"
#include "Helper.h"

#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "../config/Config.hpp"

int main()
{
	int ret = 0;

	DataClass* Data = new DataClass();
	std::vector <std::string> publicKeys;

	setlocale(LC_ALL, "Russian");
	system("chcp 1251");

	cudaError_t cudaStatus = cudaSuccess;
	ConfigClass Config;
	try {
		parse_config(&Config, "config.cfg");
	}
	catch (...) {
		for (;;)
			std::this_thread::sleep_for(std::chrono::seconds(30));
	}

	devicesInfo();

	uint32_t num_device = 0;
	int mode = -1;
	int err = -1;
	// address 0x77cc6699448b8c5e9c503e749a16b8374015c976  private_key 0xc8505c6c876399185b499f3c1ae43e5b553496e135dbcc2ca67c4b278cd9bb18
	//std::string pubKeyIn = "7cefe04ddbdb17e3861ec995d515bac16cc2766cca1d66c27acdcee876fb3cd2d811c410835d71c56fab7e492084a3949aa6797aefb38ab4b1ab1dd1b6e15f45";

#ifndef TEST_MODE
	std::cout << "\n\nEnter number of device: ";
	std::cin >> num_device;
#endif //TEST_MODE
	cudaStatus = cudaSetDevice(num_device);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}
#ifndef TEST_MODE
	//std::cout << "Enter the public key you are looking for: ";
	//std::cin >> pubKeyIn;
	//if (pubKeyIn.size() != 128) {
	//	std::cout << "ERROR: incorrect public key length: " << "  [" << pubKeyIn.size() << "]\n";
	//	goto Error;
	//}
#endif //TEST_MODE

	err = tools::readPublicKeys(Config.file_public_keys, publicKeys);
	if (err == -1) {
		std::cout << "Error readPublicKeys!" << std::endl;
		goto Error;
	}

	std::cout << "READ TABLES FOR GPU! WAIT..." << std::endl;
	err = tools::readTables(Data->host.tables_gpu, Config.folder_8_bytes_keys_gpu);
	if (err == -1) {
		std::cerr << "Error readAllTables!" << std::endl;
		goto Error;
	}
	std::cout << "\nREAD TABLES FOR CPU! WAIT..." << std::endl;
	err = tools::readTables(Data->host.tables_cpu, Config.folder_8_bytes_keys_cpu);
	if (err == -1) {
		std::cerr << "Error readAllTables!" << std::endl;
		goto Error;
	}
	Data->host.calcSizeTableBuffersGPU();
	Data->host.calcSizeTableBuffersCPU();
	std::cout << "\nSIZE DATABASE FOR CPU: " << std::to_string((float)(Data->host.size_tables_cpu) / (1024.0f * 1024.0f * 1024.0f)) << " GB\n";
	std::cout << "SIZE DATABASE FOR GPU: " << std::to_string((float)(Data->host.size_tables_gpu) / (1024.0f * 1024.0f * 1024.0f)) << " GB\n";


	if ((Data->host.size_tables_cpu != 0) && (Data->host.size_tables_gpu != 0))
	{
		std::cout << "PROGRAM STARTS IN MODE \"SEARCH IN GPU AND CPU\" \n";
		mode = MODE_SEARCH_IN_GPU_AND_CPU;
	}
	else if ((Data->host.size_tables_cpu != 0) && (Data->host.size_tables_gpu == 0))
	{
		std::cout << "PROGRAM STARTS IN MODE \"SEARCH ONLY IN CPU\" \n";
		mode = MODE_SEARCH_ONLY_IN_CPU;
	}
	else if ((Data->host.size_tables_cpu == 0) && (Data->host.size_tables_gpu != 0))
	{
		std::cout << "PROGRAM STARTS IN MODE \"SEARCH ONLY IN GPU\" \n";
		mode = MODE_SEARCH_ONLY_IN_GPU;
	}
	else if ((Data->host.size_tables_cpu == 0) && (Data->host.size_tables_gpu == 0))
	{
		std::cout << "ERROR TABLES SIZE! SIZE = 0. check the paths in the file confid.cfd \n";
		return -1;
	}

	if (Data->malloc(Config.cuda_grid, Config.cuda_block, mode, false) != 0) {
		std::cerr << "Error Data->Malloc()!" << std::endl;
		goto Error;
	}

	std::cout << "\n*************** Crack START! ********************\n" << std::endl;
	err = crack_public_key(*Data, publicKeys, Config);
	if (err < 0) {
		std::cerr << "Error crack_public_key)!" << std::endl;
		for (;;)
			std::this_thread::sleep_for(std::chrono::seconds(30));
	}

	std::cout << "\n*************** Crack END! **********************\n" << std::endl;
	std::cout << "\n\n";
	std::cout << "FINISH!!!!!\n";
	std::cout << "FINISH!!!!!\n";
	std::cout << "FINISH!!!!!\n";

	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return 0;
Error:
	std::cout << "\n\nERROR!" << std::endl;

	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return -1;
}

