# GPU(CUDA) Profanity Crack
## (Version 1.1)
## Файл config.cfg
* ***"folder_keys": "F:\\tables_bin_sort"***  - папка с таблицами публичных ключей алгоритма profanity. *(таблицы сгенерированы программой GeneratorProfanityPubKeys.exe)*
* ***"folder_8_bytes_keys_gpu": "F:\\tables_bin_8_bytes_gpu"***  - папка с таблицами публичных ключей алгоритма profanity, первые 8 байт координаты X.*(таблицы сгенерированы программой GeneratorProfanityPubKeys.exe)*
* ***"folder_8_bytes_keys_cpu": "F:\\tables_bin_8_bytes_cpu"***  - папка с таблицами публичных ключей алгоритма profanity, первые 8 байт координаты X.*(таблицы сгенерированы программой GeneratorProfanityPubKeys.exe)*
* ***"file_public_keys": "F:\\public_keys.txt"***  - файл с искомыми публичными ключами
* ***"max_rounds": 1024*** - максимальное количество раундов, которые будут пройдены для одного публичного ключа


## Описание
Программа GeneratorProfanityPubKeys.exe создает таблицы в двух папках "tables_bin_sort" и "tables_bin_8_bytes". Папку "tables_bin_8_bytes" можно разделить на две папки "folder_8_bytes_keys_gpu" и "folder_8_bytes_keys_cpu".
В первой папке будут содержаться таблицы для поиска совпадения ключа на GPU, во второй - таблицы для поиска на CPU.
В начале программы, считываются настройки из файла config.cfg. Потом предлагается ввести номер используемой видеокарты.</br>
Функцией ReadTablesToMemory считываются таблицы в оперативную память из папок "folder_8_bytes_keys_gpu" и "folder_8_bytes_keys_cpu", общий объем 32 ГБ. Запускается функция crack_public_key().
Если папка "folder_8_bytes_keys_cpu" пуста, и все таблицы хранятся в "folder_8_bytes_keys_gpu" то поиск будет происходить только на GPU.(ВНИМАНИЕ!!! объем таблиц 32 ГБ).
Если папка "folder_8_bytes_keys_gpu" пуста, и все таблицы хранятся в "folder_8_bytes_keys_cpu" то поиск будет происходить только на CPU.

Вызывается функция crack_init на GPU, в которой создаются 255*16384 публичных ключей, каждый ключ равен "искомый ключ" минус G*2 192*id.</br>
Далее, постоянно вызывается функция crack(), в которой каждый ключ уменьшается на точку G. Все эти ключи выгружаются на CPU, где происходит поиск их по таблицам, по
8-ми байтам. Если найдено совпадение (в консоли появиться надпись "!!!FOUND 8 BYTES!!!"), то идет обращение к таблице "полных" ключей "folder_to_save_sort_results" и по номеру файла и позиции совпавших 8 байтах, сравниваются полностью 64-байтные ключи. Если совпало, то в функции calcKeyFromResult вычисляется искомый приватный ключ. Если нет, вызывается снова функция crack() и так далее.

# Если нашли ключ
В консоли появиться надписи:
> * !!!FOUND!!!</br>
!!!FOUND!!!</br>
!!!FOUND!!!</br>
!!!FOUND!!!</br>
ROUND: 1256</br>
PUBLIC KEY: 7CEFE04DDBDB17E3861EC995D515BAC16CC2766CCA1D66C27ACDCEE876FB3CD2D811C410835D71C56FAB7E492084A3949AA6797AEFB38AB4B1AB1DD1B6E15F45</br>
FOUND PRIVATE KEY: C8505C6C876399185B499F3C1AE43E5B553496E135DBCC2CA67C4B278CD9BB18</br>
FOUND PRIVATE KEY: C8505C6C876399185B499F3C1AE43E5B553496E135DBCC2CA67C4B278CD9BB18</br>
FOUND PRIVATE KEY: C8505C6C876399185B499F3C1AE43E5B553496E135DBCC2CA67C4B278CD9BB18
*

## Файл ProfanityCrackV11.exe находится в папке exe


### ОБСУЖДЕНИЕ КОДА: https://t.me/brute_force_gpu
