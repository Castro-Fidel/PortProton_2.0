import re
import requests
import time
from modules.downloader import try_download
from modules.files_worker import *

count_wines = 25  # Количество элементов для записи в .tmp файл


repos = {  # Список репозиториев для обработки и их короткие имена
    "GloriousEggroll/proton-ge-custom": "proton-ge-custom",
    "GloriousEggroll/wine-ge-custom": "wine-ge-custom",
    "Kron4ek/Wine-Builds": "Kron4ek",
    "CachyOS/proton-cachyos": "proton-cachyos",
    "Castro-Fidel/wine_builds": "LG"
}

mirrors = {
    "https://cloud.linux-gaming.ru": "LG_mirror"
}

def source_list_checker(tmp_path):
    for repo, short_name in repos.items():
        output_file = os.path.join(tmp_path, f"{short_name}.tmp")

        if not os.path.exists(output_file) or os.path.getsize(output_file) == 0 or \
                (time.time() - get_last_modified_time(output_file, fallback=0)) >= 10800:
            source_list_downloader(repo, tmp_path, short_name, output_file)
        else:
            log.info(f"Файл {output_file} существует и был обновлён менее 3 часов назад. Используем кэшированные данные.")

    for mirror_url, short_name in mirrors.items():
        output_file = os.path.join(tmp_path, f"{short_name}.tmp")

        if not os.path.exists(output_file) or os.path.getsize(output_file) == 0 or \
                (time.time() - get_last_modified_time(output_file, fallback=0)) >= 10800:
            source_list_downloader(mirror_url, tmp_path, short_name, output_file, use_github=False)
        else:
            log.info(f"Файл {output_file} существует и был обновлён менее 3 часов назад. Используем кэшированные данные.")

def source_list_downloader(source, tmp_path, short_name, output_file, use_github=True):
    if use_github:
        url = f"https://api.github.com/repos/{source}/releases?per_page={count_wines}"
    else:
        url = f"{source}/"

    temp_file = os.path.join(tmp_path, f"{short_name}.tmp.new")

    try:
        response = requests.get(url)
        response.raise_for_status()

        tar_urls = []  # Список для хранения полных URL-адресов архивов

        if use_github:
            releases = response.json()
            for release in releases:
                assets = release.get('assets', [])
                for asset in assets:
                    asset_name = asset['name']
                    asset_url = asset['browser_download_url']
                    if (
                            (re.search(r'(wine|proton)', asset_name, re.IGNORECASE) or
                             re.search(r'^GE-Proton\d+-\d+\.tar\.gz$', asset_name) or
                             re.search(r'^GE-Proton\d+(-\d+)?\.tar\.xz$', asset_name)) and
                            (asset_name.endswith('.tar.gz') or asset_name.endswith('.tar.xz'))
                    ):
                        tar_urls.append(asset_url)  # Добавляем полный URL в список
        else:  # Обработка страницы с зеркалом
            content = response.text
            log.debug(f"Содержимое зеркала: {content}")  # Записываем содержимое страницы для отладки
            relative_urls = re.findall(r'href=[\'"]?(portproton/[^\'" >]+\.tar\.(gz|xz))[\'"]?', content)

            base_url = "https://cloud.linux-gaming.ru/"
            tar_urls = [base_url + url[0] for url in relative_urls]  # Используем первый элемент кортежа для формирования полного URL

        if not tar_urls: # Проверка на наличие URL
            log.warning(f"Нет подходящих файлов в {'GitHub' if use_github else 'зеркале'} {source}.")
            return

        with open(temp_file, 'w') as file: # Запись найденных URL в файл
            file.write("\n".join(tar_urls))

        os.replace(temp_file, output_file)
        log.info(f"Файл {output_file} успешно обновлен.")

    except requests.exceptions.RequestException as e:
        log.error(f"Ошибка при получении данных из {source}: {str(e)}")

def get_sources(args, tmp_path, dist_path, mirror):
    os.makedirs(tmp_path, exist_ok=True)
    source_list_checker(tmp_path)

    if not args:
        log.critical("Аргументы не предоставлены. Завершение работы.")
        return

    for arg in args:
        target_dir_path = os.path.join(dist_path, arg) # Формируем название искомого каталога

        if os.path.isdir(target_dir_path): # Проверяем, существует ли запрашиваемый каталог
            log.debug(f"Запрашиваемый каталог '{arg}' найден в '{dist_path}'.")
        else:
            log.debug(f"Запрашиваемый каталог '{arg}' не найден в '{dist_path}'.")
            file_found = False

            for repo, short_name in repos.items(): # Определяем, какой источник использовать в зависимости от флага mirror
                if mirror and short_name == "LG":
                    short_name = "LG_mirror"  # Меняем имя под зеркалом

                tmp_file_path = os.path.join(tmp_path, f"{short_name}.tmp")
                if os.path.exists(tmp_file_path):
                    with open(tmp_file_path, 'r') as file:
                        all_urls = file.read().splitlines()
                        log.debug(f"Получили ссылки {all_urls}")

                    for url in all_urls:  # Проверяем, есть ли URL соответствующий имени каталога
                        log.debug(f"Проверяем ссылку {url}")
                        if f"{arg}.tar." in os.path.basename(url):
                            log.info(f"Совпадение для '{arg}' найдено в файле {tmp_file_path}")
                            tmp_file = os.path.join(tmp_path, os.path.basename(url))
                            log.debug(f"Сформирован путь к файлу: {tmp_file}")
                            if not os.path.exists(tmp_file):
                                try:
                                    try_download(url, tmp_file)
                                    unpack(tmp_file, dist_path)
                                    try_remove_file(tmp_file)
                                except Exception as e:
                                    log.error(f"Ошибка при загрузке или распаковке: {str(e)}")
                            file_found = True  # Устанавливаем флаг, что файл найден
                            break  # Прерываем цикл, если файл найден

            if not file_found:
                log.critical(f"{arg} не найден в файле {tmp_file_path}. Завершение! Проверьте корректность переданного имени wine/proton.")
