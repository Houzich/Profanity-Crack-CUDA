/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include "main.h"
#include <string>
#include <vector>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <omp.h>
#include <set>
#include <random>
#include <fstream>
#include <filesystem>

#include "../ProfanityCrackCUDA/stdafx.h"
#include "tools.h"
#include "utils.h"
#include "base58.h"
#include "segwit_addr.h"



namespace tools {


	void generateRandomWordsIndex(uint16_t* buff, size_t len) {
		std::random_device rd;
		std::uniform_int_distribution<uint16_t> distr;
		std::mt19937 eng(rd());

		for (int i = 0; i < len; i++)
		{
			buff[i] = distr(eng) % 1626;
		}
	}

	int pushToMemory(uint8_t* addr_buff, std::vector<std::string>& lines, int max_len) {
		int err = 0;
		for (int x = 0; x < lines.size(); x++) {
			const std::string line = lines[x];
			err = hexStringToBytes(line, &addr_buff[max_len * x], max_len);
			if (err != 0) {
				std::cerr << "\n!!!ERROR HASH160 TO BYTES: " << line << std::endl;
				return err;
			}
		}
		return err;
	}

	//int ReadTablesToMemory(ConfigClass& config, HostBuffersClass& Data)
	//{
	//	int ret = 0;
	//	openBinaryFilesForRead(Data.instream, config.folder_8_bytes_keys);
	//	//#pragma omp parallel for
	//	for (int num_file = 0; num_file < config.num_files; num_file++) {
	//		double percent = (num_file == 0) ? 0 : (100.0 / ((double)config.num_files / (double)num_file));
	//		//#pragma omp critical (ReadTables)
	//		{
	//			printPercent("READ TABLES PROCESS: ", percent);
	//		}
	//		std::string filename = getFileName(config.folder_8_bytes_keys, num_file, "bin");
	//		size_t filesize = getBinaryFileSize(filename);
	//		if (filesize % (8) != 0) {
	//			std::cout << "Error file (" << filename << ") size (" << filesize << ")" << std::endl;
	//			return -1;
	//		}
	//		size_t numKeys = filesize / (8);
	//		ret = Data.MallocTable(num_file, numKeys * 8);
	//		if (ret != 0) return ret;

	//		uint8_t* data = Data.getTable(num_file);
	//		getFromBinaryFile(filename, data, 8 * numKeys, 0);
	//	}
	//	closeInStreams(Data.instream);
	//	printPercent("\nREAD TABLES PROCESS: ", 100.0);

	//	return 0;
	//}

	void printPercent(std::string title, double percent) {
		std::ostringstream ss;
		ss << std::fixed << std::setprecision(3) << percent << "%";
		const auto savePercent = ss.str();

		const std::string strVT100ClearLine = "\33[2K\r";
		// << '\r' << std::flush;
		//std::cout << strVT100ClearLine << title << savePercent << '\n' << std::flush;
		std::cout << strVT100ClearLine << title << savePercent << std::flush;
	}

	size_t getBinaryFileSize(std::string filename) {
		std::ifstream in(filename, std::ios::binary);

		const auto begin = in.tellg();
		in.seekg(0, std::ios::end);
		const auto end = in.tellg();
		const auto fsize = (end - begin);
		return fsize;
	}

	std::string getFileName(std::string path, size_t num_file, std::string extension) {
		std::ostringstream ss;
		ss << std::hex << std::uppercase;
		ss << path << '/' << std::setfill('0') << std::setw(2) << num_file << "." << extension;
		return ss.str();
	}

	void getFromBinaryFile(std::string filename, void* data, size_t size, size_t position) {
		std::ifstream in;
		in.exceptions(std::ifstream::badbit);
		try {
			in.open(filename, std::ios::in | std::ios::binary);
			in.seekg(position, in.beg);
			in.read((char*)data, size);
			in.close();
		}
		catch (std::ifstream::failure e) {
			std::cerr << "Error read file " << filename << " : " << e.what() << '\n';
			throw;
		}
	}




	int readPublicKeys(std::string filename, std::vector<std::string>& pubKeys)
	{
		size_t filesize = getBinaryFileSize(filename);
		if (filesize < 128) {
			std::cerr << "Error file (" << filename << ") size (" << filesize << ")" << std::endl;
			return -1;
		}
		std::ifstream inFile(filename, std::ifstream::in);
		if (inFile.is_open())
		{
			//int64_t cnt_lines = std::count(std::istreambuf_iterator<char>(inFile), std::istreambuf_iterator<char>(), '\n');
			std::string line;
			while (getline(inFile, line)) {
				if (line.size() != 128) {
					std::cout << "ERROR: incorrect public key length: " << line.size() << ", public key: \"" << line << "\"\n";
					return -1;
				}
				pubKeys.push_back(line);
			}
		}
		else
		{
			std::cerr << "\n!!!ERROR open file: " << filename << std::endl;
			return -1;
		}
		return 0;
	}


	int readTables(tableStruct* tables, std::string path)
	{
		int ret = 0;
		std::string num_tables;
		size_t all_lines = 0;
#pragma omp parallel for 
		for (int num_file = 0; num_file < 256; num_file++) {
			double percent = (num_file == 0) ? 0 : (100.0 / ((double)256 / (double)num_file));
			{
				printPercent("READ TABLES PROCESS: ", percent);
			}
			std::string filename = getFileName(path, num_file, "bin");
			size_t filesize = getBinaryFileSize(filename);
			if (filesize % (8) != 0) {
				std::cerr << "Error file (" << filename << ") size (" << filesize << ")" << std::endl;
				ret = -1;
				break;
			}
			size_t numKeys = filesize / 8;
			if (numKeys != 0) {
				tables[num_file].table = (uint64_t*)malloc(filesize);
				if (tables[num_file].table == NULL) {
					printf("Error: malloc failed to allocate buffers.Size %llu. From file %s\n", (unsigned long long int)(filesize), filename.c_str());
					ret = -1;
					break;
				}
				tables[num_file].size = (uint32_t)_msize((void*)tables[num_file].table);
				memset((uint8_t*)tables[num_file].table, 0, tables[num_file].size);
				getFromBinaryFile(filename, tables[num_file].table, filesize, 0);
			}
			else {
#pragma omp critical 
				{
					//std::cout << "!!! WORNING !!! COUNT KEYS IS 0, FILE " << filename << std::endl;
				}
			}

		}

#ifdef	USE_REVERSE_32
#pragma omp parallel for 
		for (int i = 0; i < 256; i++) {
			size_t addrs = tables[i].size / 20;
			for (int x = 0; x < addrs; x++) {
				if (tables[i].table != NULL)
					reverseHashUint32(&tables[i].table[x * 5], &tables[i].table[x * 5]);
			}

		}
#endif //USE_REVERSE
		//std::cout << "\nALL ADDRESSES IN FILES " << all_lines << std::endl;
		//std::cout << "TEMP MALLOC ALL RAM MEMORY SIZE (DATABASE): " << std::to_string((float)(all_lines * 20) / (1024.0f * 1024.0f * 1024.0f)) << " GB\n";
		return ret;
	}



	void saveResult(private_key privateKey, point publicKey) {
				std::ofstream out;
				out.open(FILE_PATH_RESULT, std::ios::app);

					if (out.is_open())
					{
						std::string s = privateKeyToHEX(&privateKey) + ',' + pointToHEX(&publicKey) + '\n';
						out << s;
					}
					else
					{
						printf("\n!!!ERROR create file %s!!!\n", FILE_PATH_RESULT);
					}

				out.close();
	}

}
