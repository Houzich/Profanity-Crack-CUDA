/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#ifndef HPP_CRACK_PUB_KEY
#define HPP_CRACK_PUB_KEY

#include <stdexcept>
#include <fstream>
#include <string>
#include <vector>
#include <mutex>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "SpeedSample.hpp"
#include "types.hpp"
#include "Helper.h"
#include "../../config/Config.hpp"



class Dispatcher {
private:

	struct Device {
		static uint64_t* genPrivateKeys(private_key* priv_keys, size_t size, uint64_t* init_value);

		Device(Dispatcher& parent,
			DataClass& Data,
			point public_key);
		~Device();

		
		DataClass& data;
		point public_key;
		point* result;

		Dispatcher& m_parent;

		// Seed and round information
		uint64_t m_round;
		// Speed sampling
		SpeedSample m_speed;

		// Initialization
		size_t m_sizeInitialized;
	};

public:
	Dispatcher::Dispatcher(DataClass& data, ConfigClass& config);
	~Dispatcher();

	void addDevice(
		DataClass& data,
		point public_key);



	int memsetSearchGPU();
	int init(int mode);
	int startSearchOnlyGPU();
	int endSearchOnlyGPU();
	int startSearchOnlyCPU();
	int endSearchOnlyCPU();
	int startSearchGPUAndCPU();
	int endSearchGPUAndCPU();

	void printSpeed(size_t round);
private:
	int cudaMallocDevice(uint8_t** point, uint64_t size, uint64_t* all_gpu_memory_size, std::string buff_name);
	int memsetGlobal(int mode);
	void dispatch(Device& d);
	void handleResult();

	static std::string formatSpeed(double s);
public:



	Device* Dev;

private: /* Instance variables */
	// Run information
	std::mutex mtx;
	std::chrono::time_point<std::chrono::steady_clock> timeStart;
	bool m_quit;
	DataClass& data;
	ConfigClass& config;

};

#endif /* HPP_CRACK_PUB_KEY */
