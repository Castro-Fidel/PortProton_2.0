#!/usr/bin/env python3
import sys
import tempfile

from modules.config_parser import *
from modules.log import *
from modules.env_var import *
from modules.files_worker import *
from modules.downloader import *
from modules.init_wine import *
from modules.source_fetcher import *

tmp_path = tempfile.gettempdir() + "/portproton"

mirror = True

work_path = get_env_var("USER_WORK_PATH")

data_path = work_path + "/data"
dist_path = data_path + "/dist"
img_path = data_path + "/img"

vulkan_path = data_path + "/vulkan"
plugins_path = data_path + "/plugins_v" + var("plugins_ver")
libs_path = data_path + "/libs_v" + var("libs_ver")

create_new_dir(dist_path, tmp_path, img_path, vulkan_path)

log.info(f"рабочий каталог: {work_path}")
log.info(f"принятые аргументы: {sys.argv[1:]}")

if __name__ == "__main__":
    # TODO: реализовать все функции get_* в модуль downloader.py:

    if len(sys.argv) > 1:  # Проверяем, что есть хотя бы один аргумент (кроме имени скрипта)
        match sys.argv[1]:  # Игнорируем первый аргумент (имя скрипта)
            case "--get-wine": 
                # без аргументов сохраняем список доступных в tmp_path/get_wine.tmp и выводим в терминал
                # если есть аргумент (например WINE_LG_10-1) то обновляем и парсим tmp_path/get_wine.tmp с последующим скачиванием
                get_sources(sys.argv[2:], tmp_path, dist_path, mirror)
            case "--get-dxvk":
                # без аргументов сохраняем список доступных в tmp_path/get_dxvk.tmp и выводим в терминал
                # если есть аргумент (например 2.5.3-31) то обновляем и парсим tmp_path/get_dxvk.tmp с последующим скачиванием
                get_dxvk(sys.argv[2:])
            case "--get-vkd3d":
                # без аргументов сохраняем список доступных в tmp_path/get_dxvk.tmp и выводим в терминал
                # если есть аргумент (например 1.1-4367) то обновляем и парсим tmp_path/get_dxvk.tmp с последующим скачиванием
                get_vkd3d(sys.argv[2:])
            case "--get-plugins":
                # версия плагинов будет захардкожена, парсить ничего не надо
                get_plugins(plugins_ver)
            case "--get-libs":
                # версия контейнера будет захардкожена, парсить ничего не надо
                get_libs(libs_ver)

    init_wine(dist_path)
