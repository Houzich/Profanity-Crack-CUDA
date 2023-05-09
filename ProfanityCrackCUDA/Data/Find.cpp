/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <iostream>
#include <string>
#include <vector>
#include <random>
#include "Find.h"
#include "../../Tools/tools.h"



	int comp_key(const point *key, const uint64_t bytes_y_from_table) {
		uint64_t bytes_y = *(uint64_t*)&key->x.d[6];
		if (bytes_y < bytes_y_from_table)
		{
			return -1;
		}
		else if (bytes_y > bytes_y_from_table)
		{
			return 1;
		}
		return 0;
	}

	int Find_In_Table_8_Bytes(const point* key, const uint64_t* table, size_t size_table, size_t* line_in_table_find) {
		int find = 0;
		bool search_state = true;
		size_t line_cnt = (size_table / 8);
		size_t interval = line_cnt / 3;

		size_t num_line_next = 0;
		size_t num_line_last = 0;

		while (num_line_next < line_cnt) {
			num_line_last = num_line_next;
			uint64_t bytes_from_table;


			if (interval == 0) {
				search_state = false;
			}
			if (search_state) {
				num_line_next += interval;

				if (num_line_next >= line_cnt) {
					num_line_next = num_line_last;
					interval = interval / 2;
					continue;
				}
				bytes_from_table = table[num_line_next];
				*line_in_table_find = num_line_next;
			}
			else {
				bytes_from_table = table[num_line_next];
				*line_in_table_find = num_line_next;
				num_line_next += 1;
			}

			int cmp = comp_key(key, bytes_from_table);
			if (search_state) {
				if (cmp < 0) {
					if (interval < 20) {
						search_state = false;
					}
					else
					{
						interval = interval / 2;
					}
					num_line_next = num_line_last;
					continue;
				}
				else if (cmp == 0) {
					search_state = false;
				}
				else {
					continue;
				}
			}


			if (cmp <= 0) {
				if (cmp == 0)
					find = 1;
				break;
			}
		}

		if (find == 1) {
			return 1;
		}
		return 0;
	}



	class FindKey
	{
	public:
		size_t num_key_in_byffer = 0;
		size_t num_table = 0;
		size_t num_key_in_table = 0;
		point key = { {0} };
		point key_from_file = { {0} };
		uint32_t seed = 0;
		FindKey(size_t num_key_in_byffer, size_t num_table, size_t num_key_in_table, point key)
		{
			this->num_key_in_byffer = num_key_in_byffer;
			this->num_table = num_table;
			this->num_key_in_table = num_key_in_table;
			memcpy(&this->key, &key, sizeof(point));
		}

	};


	void Search_Keys_In_Tables(host_buffers_class&data, point* keys, size_t num_keys, std::vector<FindKey>& out) {
#pragma omp parallel for
		for (int64_t i_key = 0; i_key < (int64_t)num_keys; i_key++)
		{
			const uint8_t* key = (const uint8_t*)(&keys[i_key]);
			uint8_t num_table = key[31];
			const uint64_t* table = data.getTable(num_table);
			if (table == NULL) continue;
			const size_t size = data.getSizeTable(num_table);
			if (size == 0) continue;
			size_t line_in_table_find = 0;
			int find = Find_In_Table_8_Bytes(&keys[i_key], table, size, &line_in_table_find);
			if (find == 1) { 
#pragma omp critical (FindKeys)
				{
					out.push_back(FindKey(i_key, num_table, line_in_table_find, keys[i_key]));
				}
			}


		}
	}

	int comp_points(const point* key1, const point* key2) {
		if (key1->x.d[7] != key2->x.d[7]) return -1;
		if (key1->x.d[6] != key2->x.d[6]) return -1;
		if (key1->x.d[5] != key2->x.d[5]) return -1;
		if (key1->x.d[4] != key2->x.d[4]) return -1;
		if (key1->x.d[3] != key2->x.d[3]) return -1;
		if (key1->x.d[2] != key2->x.d[2]) return -1;
		if (key1->x.d[1] != key2->x.d[1]) return -1;
		if (key1->x.d[0] != key2->x.d[0]) return -1;
		if (key1->y.d[7] != key2->y.d[7]) return -1;
		if (key1->y.d[6] != key2->y.d[6]) return -1;
		if (key1->y.d[5] != key2->y.d[5]) return -1;
		if (key1->y.d[4] != key2->y.d[4]) return -1;
		if (key1->y.d[3] != key2->y.d[3]) return -1;
		if (key1->y.d[2] != key2->y.d[2]) return -1;
		if (key1->y.d[1] != key2->y.d[1]) return -1;
		if (key1->y.d[0] != key2->y.d[0]) return -1;
		return 1;
	}

	size_t genPrivateKeys(private_key* priv_keys, size_t size, size_t init_value) {

		for (size_t i = 0; i < size; i++)
		{
			std::mt19937_64 eng(init_value);
			std::uniform_int_distribution<uint64_t> distr;

			priv_keys[i].key[0] = distr(eng);
			priv_keys[i].key[1] = distr(eng);
			priv_keys[i].key[2] = distr(eng);
			priv_keys[i].key[3] = distr(eng);

			//printPrivateKey(L"Dispather PrivateKeys ", &priv_keys[i]);
			init_value++;
		}

		return init_value;
	}

	class FoundKeyResult
	{
	public:
		size_t id = 0;
		size_t position_in_table = 0;
		point key_result = { {0} };
		size_t num_table = 0;

		point key_from_file = { {0} };
		uint32_t seed = 0;
		FoundKeyResult(size_t id, size_t position_in_table, point key_result)
		{
			this->id = id;
			this->position_in_table = position_in_table;
			memcpy(&this->key_result, &key_result, sizeof(point));

			this->num_table = *(uint8_t*)((uint8_t*)&key_result + 31);
		}

	};

	private_key calcKeyFromResult(private_key privKey, size_t round, size_t id_key) {

		// Format private key
		uint64_t carry = 0;
		private_key found;

		found.key[0] = privKey.key[0] + round; carry = found.key[0] < round;
		found.key[1] = privKey.key[1] + carry; carry = !found.key[1];
		found.key[2] = privKey.key[2] + carry; carry = !found.key[2];
		found.key[3] = privKey.key[3] + carry + id_key;

		return found;
	}

	void printPoint(char* title, point* point) {
		printf("%s%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x%.8x\n",
			title,
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
	}
	void printPublicKey(char* title, public_key* pubKey) {
		printf("%s%.16llX%.16llX%.16llX%.16llX%.16llX%.16llX%.16llX%.16llX\n",
			title,
			pubKey->key[7],
			pubKey->key[6],
			pubKey->key[5],
			pubKey->key[4],
			pubKey->key[3],
			pubKey->key[2],
			pubKey->key[1],
			pubKey->key[0]);
	}

	void printPrivateKey(char* title, private_key* privKey) {
		printf("%s%.16llx%.16llx%.16llx%.16llx\n",
			title,
			privKey->key[3],
			privKey->key[2],
			privKey->key[1],
			privKey->key[0]);
	}
#define KEY_LEN 64
#define SEED_RANDOM_LEN 4
#define LINE_LEN (KEY_LEN + SEED_RANDOM_LEN)

	int checkResult(DataClass& data, resultFound* result, size_t prev_score, size_t round, ConfigClass& config)
	{
		std::vector<FoundKeyResult> out;
		if (result->score == prev_score) return 0;
		while (result->score != prev_score)
		{
			prev_score++;
			if (prev_score >= NUM_RESULT_FOUND_KEYS) {
				prev_score = 0;
			}
			out.push_back(FoundKeyResult(result->id[prev_score], result->line_in_tables[prev_score], result->pub_key[prev_score]));
		}

		if (out.size() != 0)
		{
			//std::cout << "OUT.SIZE = " << out.size() << std::endl;
			for (int x = 0; x < out.size(); x++)
			{
				std::cout << "\n!!!FOUND 8 BYTES GPU!!!\n";
				std::string filename = tools::getFileName(config.folder_keys, out[x].num_table, "bin");
				size_t filesize = tools::getBinaryFileSize(filename);
				if (filesize % LINE_LEN != 0) {
					std::cerr << "Error file (" << filename << ") size (" << filesize << ")" << std::endl;
					return -1;
				}
				tools::getFromBinaryFile(filename, &out[x].key_from_file, 64, out[x].position_in_table * LINE_LEN);
				if (comp_points(&out[x].key_result, &out[x].key_from_file) == 1) {
					tools::getFromBinaryFile(filename, &out[x].seed, 4, out[x].position_in_table * LINE_LEN + 64);

					std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
					private_key privateKeyInTable;
					genPrivateKeys(&privateKeyInTable, 1, out[x].seed);
					//std::cout << "INFO: " << std::endl;
					//tools::printPrivateKey("PRIVATE KEY: ", &privateKeyInTable);
					//printf("SEED: 0x%.8X\n", out[x].seed);
					//std::cout << "ID PUBLIC KEY: " << out[x].id << std::endl;
					//std::cout << "ROUND: " << round << std::endl;
					std::cout << "***************************************************************************\n";
					std::cout << "ROUND: " << (round - 1) << std::endl;
					private_key privateKey = calcKeyFromResult(privateKeyInTable, round + 1, out[x].id);
					printPoint("FOUND  PUBLIC KEY: ", &data.host.public_key);
					printPrivateKey("FOUND PRIVATE KEY: ", &privateKey);
					printPrivateKey("FOUND PRIVATE KEY: ", &privateKey);
					printPrivateKey("FOUND PRIVATE KEY: ", &privateKey);
					std::cout << "***************************************************************************\n\n";
					tools::saveResult(privateKey, data.host.public_key);
					return 1;
				}
			}
		}
		return 0;
	}


	int searchKeysCPU(host_buffers_class& data, point* keys, size_t num_keys, size_t round, ConfigClass& config)
	{
		std::vector<FindKey> out;
		Search_Keys_In_Tables(data, keys, num_keys, out);
		if (out.size() != 0)
		{
			//std::cout << "OUT.SIZE = " << out.size() << std::endl;
			for (int x = 0; x < out.size(); x++)
			{
				std::cout << "\n!!!FOUND 8 BYTES CPU!!!\n";
				std::string filename = tools::getFileName(config.folder_keys, out[x].num_table, "bin");
				size_t filesize = tools::getBinaryFileSize(filename);
				if (filesize % LINE_LEN != 0) {
					std::cout << "Error file (" << filename << ") size (" << filesize << ")" << std::endl;
					return -1;
				}

				tools::getFromBinaryFile(filename, &out[x].key_from_file, 64, out[x].num_key_in_table * LINE_LEN);
				if (comp_points(&out[x].key, &out[x].key_from_file) == 1) {
					tools::getFromBinaryFile(filename, &out[x].seed, 4, out[x].num_key_in_table * LINE_LEN + 64);
					//printf("SEED: %.8x\n", out[x].seed);
					std::cout << "!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n!!!FOUND!!!\n";
					private_key privateKeyInTable;
					genPrivateKeys(&privateKeyInTable, 1, out[x].seed);
					//std::cout << "ROUND: " << round << std::endl;
					//printPoint("PUBLIC KEY: ", &out[x].key);
					//std::cout << "INFO: "<< std::endl;
					//printPrivateKey("TABLE PRIVATE KEY: ", &privateKeyInTable);
					//std::cout << "NUM PUBLIC KEY: " << out[x].num_key_in_byffer << std::endl;
					std::cout << "***************************************************************************\n";
					std::cout << "ROUND: " << (round - 1) << std::endl;
					private_key privateKey = calcKeyFromResult(privateKeyInTable, round + 1, out[x].num_key_in_byffer);
					printPoint("FOUND  PUBLIC KEY: ", &data.public_key);
					printPrivateKey("FOUND PRIVATE KEY: ", &privateKey);
					printPrivateKey("FOUND PRIVATE KEY: ", &privateKey);
					printPrivateKey("FOUND PRIVATE KEY: ", &privateKey);
					std::cout << "***************************************************************************\n\n";
					return 1;
				}
			}
		}
		return 0;
	}


	