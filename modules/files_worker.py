import os
import shutil
import filecmp
import tarfile
import hashlib

from .log import *

def try_copy_file(source, destination):  # функция копирования если файлы различаются
    if not os.path.exists(source):
        raise FileNotFoundError (f"file not found for copy: {source}")
        return False

    if os.path.exists(destination):
        if filecmp.cmp(source, destination, shallow=False):
            return True

    if shutil.copy2(source, destination):
        return True
    else:
        return False

def try_force_link_file(source, link):
    if not os.path.exists(source):
        raise FileNotFoundError (f"file not found for link: {source}")
        return False

    try:
        if os.path.exists(link) or os.path.islink(link):
            os.remove(link)

        os.symlink(source, link)
    except Exception as e:
        log.error(f"failed to create link for file: {e}")


def try_remove_file(file_path):
    if os.path.exists(file_path) and os.path.isfile(file_path):
        try:
            os.remove(file_path)
        except Exception as e:
            log.error(f"failed to remove file: {e}")

def create_new_dir(*path):
    for i in path:
        if not os.path.exists(i):
            try:
                os.makedirs(i)
            except Exception as e:
                log.error(f"failed to create directory: {e}")

def try_force_link_dir(path, link):
    if not os.path.exists(path):
        raise FileNotFoundError (f"directory not found for link: {path}")
        return False

    try:
        if os.path.exists(link) or os.path.islink(link):
            os.remove(link)

        os.symlink(path, link)
    except Exception as e:
        log.error(f"failed to create link for file: {e}")

def replace_file(file_path, file_name): # функция замены файла (сначала запись во временный файл, потом замена)
    try:
        if os.path.exists(file_name) and os.path.getsize(file_name) > 0:
            os.replace(file_name, file_path)  # Меняем местами файлы, если временный файл не пуст
            log.info(f"Данные успешно обновлены в {file_path}.")
        else:
            log.warning(f"Временный файл {file_name} пуст, замена в {file_path} не выполнена.")
            if os.path.exists(file_name):
                os.remove(file_name)  # Удаляем пустой временный файл
    except Exception as e:
        log.error(f"Ошибка при замене файла: {e}")

def try_write_temp_file(file_path, file_name):  # функция записи в tmp
    try:
        with open(file_path, 'w') as file:
            file.write("\n".join(file_name))  # Записываем все имена файлов во временный файл
    except Exception as e:
        log.error(f"Ошибка при записи во временный файл {file_path}: {e}")

def try_remove_dir(path):
    if os.path.exists(path) and os.path.isdir(path):
        try:
            shutil.rmtree(path)
        except Exception as e:
            log.error(f"failed to remove directory: {e}")

def get_last_modified_time(file_path, fallback=None):  # Добавьте fallback как необязательный параметр
    try:
        return os.path.getmtime(file_path)
    except FileNotFoundError:
        log.warning(f"Файл не найден: {file_path}")
        return fallback  # Возврат значения по умолчанию
    except Exception as e:
        log.error(f"Ошибка при получении времени изменения файла {file_path}: {e}")
        return fallback  # Возврат значения по умолчанию



def unpack(archive_path, extract_to=None):
    # Проверяем, существует ли архив
    if not os.path.isfile(archive_path):
        log.error(f"Архив {archive_path} не найден.")
        return False
    try:
        if extract_to is None:
            # TODO: перенести распаковку по умолчанию в tmp
            extract_to = os.path.dirname(archive_path)
        elif not os.path.isdir(extract_to):
            create_new_dir(extract_to)

        with tarfile.open(archive_path, mode="r:*") as tar:
            tar.extractall(path=extract_to)
            full_path = os.path.realpath(extract_to)
            log.info(f"Архив {archive_path} успешно распакован в {full_path}")
    except tarfile.TarError as e:
        log.error(f"Ошибка при распаковке архива {archive_path}: {e}")
        return False
    except PermissionError:
        log.error(f"Ошибка доступа к файлу {archive_path}. Убедитесь, что у вас есть права на чтение.")
        return False
    except Exception as e:
        log.error(f"Неизвестная ошибка: {e}")
        return False

    return True

def check_hash_sum(check_file, check_sum):
    if check_sum and isinstance(check_sum, str):
        true_hash = check_sum
    elif os.path.isfile(check_sum):
        try:
            with open(check_sum, "r", encoding="utf-8") as file:
                first_line = file.readline().strip()
                elements = first_line.split()
                if elements:
                    true_hash = elements[0]
                else:
                    log.error(f"Первая строка файла {check_sum} пуста.")
        except FileNotFoundError:
            log.error(f"Файл {check_sum} не найден.")
        except Exception as e:
            log.error(f"Ошибка при чтении файла: {e}")
    else:
        log.error(f"Verification sha256sum was failed: {check_file}")

    with open(check_file,"rb") as f:
        bytes = f.read() # read entire file as bytes
        check_file_hash = hashlib.sha256(bytes).hexdigest()

    if true_hash == check_file_hash:
        log.info("Verification sha256sum was successfully.")
        return True
    else:
        log.error("Verification sha256sum was failed.")
        return False

