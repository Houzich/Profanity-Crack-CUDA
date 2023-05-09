/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V1.3.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include "Config.hpp"
#include <tao/config.hpp>

int parse_config(ConfigClass* config, std::string path)
{
	try {
		const tao::config::value v = tao::config::from_file(path);
		config->folder_keys = access(v, tao::config::key("folder_keys")).get_string();
		config->folder_8_bytes_keys_gpu = access(v, tao::config::key("folder_8_bytes_keys_gpu")).get_string();
		config->folder_8_bytes_keys_cpu = access(v, tao::config::key("folder_8_bytes_keys_cpu")).get_string();
		config->file_public_keys = access(v, tao::config::key("file_public_keys")).get_string();
		config->max_rounds = access(v, tao::config::key("max_rounds")).get_unsigned();
	}
	catch (std::runtime_error& e) {
		std::cerr << "Error parse config.cfg file " << path << " : " << e.what() << '\n';
		throw std::logic_error("error parse config.cfg file");
	}
	catch (...) {
		std::cerr << "Error parse config.cfg file, unknown exception occured" << std::endl;
		throw std::logic_error("error parse config.cfg file");
	}
	return 0;
}


