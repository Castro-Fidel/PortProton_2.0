import os
import shutil
import subprocess

from .log import *
from .env_var import *
from .files_worker import *
from .config_parser import *

def init_wine(dist_path):
    used_wine_upper = var("used_wine").upper()

    # TODO: будем переименовывать все каталоги wine в верхний регистр?

    if used_wine_upper != "SYSTEM":
        if used_wine_upper == "WINE_LG":
            used_wine = var("default_wine")
        elif used_wine_upper == "PROTON_LG":
            used_wine = var("default_proton")

        wine_path = dist_path + "/" + used_wine

        if not os.path.exists(wine_path + "/bin/wine"):
            # TODO: если нет wine то качаем и распаковываем
            log.warning(f"{used_wine} not found. Try download...")

        if not os.path.exists(wine_path + "/bin/wine"):
            log.critical(f"{used_wine} not found. Interrupt!")

        env_var("PATH", wine_path + "/bin")
        env_var("LD_LIBRARY_PATH", wine_path + "/lib")
        set_env_var_force("WINEDLLPATH", wine_path + "/lib/wine")
        if os.path.exists(wine_path + "/lib64/"):
            env_var("LD_LIBRARY_PATH", wine_path + "/lib64")
            env_var("WINEDLLPATH", wine_path + "/lib64/wine")

        wine_share = wine_path + "/share"
        if os.path.exists(wine_share + "/espeak-ng-data/"):
            set_env_var_force("ESPEAK_DATA_PATH", wine_share)
        if os.path.exists(wine_share + "/media/"):
            set_env_var_force("MEDIACONV_BLANK_VIDEO_FILE", wine_share + "/media/blank.mkv")
            set_env_var_force("MEDIACONV_BLANK_AUDIO_FILE", wine_share + "/media/blank.ptna")       

        # TODO: mono, gecko

    else:
        def check_system_wine():
            # Способ 2: Проверка через переменные окружения в нестандартных путях
            wine_env_vars = ["WINEPREFIX", "WINEARCH"]
            found_env_vars = {var: os.getenv(var) for var in wine_env_vars if os.getenv(var)}
            if found_env_vars:
                print("Найдены переменные окружения Wine:")
                for var, value in found_env_vars.items():
                    print(f"{var}={value}")
            else:
                print("Переменные окружения Wine не найдены.")

            # Способ 2: Проверка через which в стандартных путях
            wine_path_system= shutil.which("wine")
            if wine_path_system:
                print(f"Wine найден в PATH: {wine_path_system}")
            else:
                print("Wine не найден в PATH.")

            # Способ 3: Проверка через запуск wine --version
            try:
                result = subprocess.run(['wine', '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True)
                if result.returncode == 0:
                    print(f"Установленная версия: {result.stdout.strip()}")
                else:
                    print("Wine не установлен или произошла ошибка.")
            except FileNotFoundError:
                print("Команда wine не найдена.")

        wine_path = "/usr"
    
    # общие переменные окружения для любой версии wine
    set_env_var_force("WINE", wine_path + "/bin/wine")
    set_env_var_force("WINELOADER", wine_path + "/bin/wine")
    set_env_var_force("WINESERVER", wine_path + "/bin/wineserver")

    log.info(f"wine in used: {used_wine}")
    print_env_var("WINELOADER", "WINESERVER", "WINEDLLPATH")
    print_env_var("PATH", "LD_LIBRARY_PATH")
    # print_env_var("ESPEAK_DATA_PATH", "MEDIACONV_BLANK_VIDEO_FILE", "MEDIACONV_BLANK_AUDIO_FILE")
