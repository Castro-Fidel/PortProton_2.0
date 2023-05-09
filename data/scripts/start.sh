#!/usr/bin/env bash
# Author: linux-gaming.ru
export NO_AT_BRIDGE=1
export pp_full_command_line=("$0" $*)
if [ -f "$1" ]; then
    export portproton_exe="$(readlink -f "$1")"
fi
. "$(dirname $(readlink -f "$0"))/runlib"

# распаковка префикса из .ppack
if [[ -n $(basename "${portproton_exe}" | grep .ppack) ]] ; then
    export PP_PREFIX_NAME=$(basename "$1" | awk -F'.' '{print $1}')
    xterm -e unsquashfs -f -d "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}" "$1" &
    sleep 10
    while true ; do
        if [[ -n $(pgrep -a xterm | grep ".ppack" | head -n 1 | awk '{print $1}') ]] ; then
            sleep 0.5
        else
            kill -TERM $(pgrep -a unsquashfs | grep ".ppack" | head -n 1 | awk '{print $1}')
            sleep 0.3
            if [[ -z "$(pgrep -a unsquashfs | grep ".ppack" | head -n 1 | awk '{print $1}')" ]]
            then break
            else sleep 0.3
            fi
        fi
    done
    if [[ -f "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/.create_shortcut" ]] ; then
        orig_IFS="$IFS"
        IFS=$'\n'
        for crfb in $(cat "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/.create_shortcut") ; do
            export portproton_exe="${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/${crfb}"
            portwine_create_shortcut "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/${crfb}"
        done
        IFS="$orig_IFS"
    fi
    exit 0
fi


# CLI
case "${1}" in
    '--help' )
        files_from_autoinstall=$(ls "${PORT_PROTON_SCRIPTS_PATH}/pp_autoinstall") 
        echo -e "
usege: [--reinstall] [--autoinstall]

--reinstall                                         reinstall files of the portproton to default settings
--autoinstall [script_frome_PP_autoinstall]         autoinstall from the list below:
"
        echo ${files_from_autoinstall}
        echo ""
        exit 0 ;;

    '--reinstall' )
        export PP_REINSTALL_FROM_TERMINAL=1
        pp_reinstall_pp ;;

    '--autoinstall' )
        export PP_YAD_SET="$2"
        pp_autoinstall_from_db 
        exit 0 ;;
esac

PP_ALL_PREFIXES=$(ls "${PORT_PROTON_PATH}/data/prefixes/" | sed -e s/"${PP_PREFIX_NAME}$"//g)
export PP_ALL_PREFIXES

if [[ -z "${PP_DISABLED_CREATE_DB}" ]] ; then
    if [[ -n "${PORTWINE_DB}" ]] && [[ -z "${PORTWINE_DB_FILE}" ]] ; then
        PORTWINE_DB_FILE=$(grep -il "\#${PORTWINE_DB}.exe" "${PORT_PROTON_SCRIPTS_PATH}/portwine_db"/*)
        if [[ -z "${PORTWINE_DB_FILE}" ]] ; then
            echo "#!/usr/bin/env bash"  > "${portproton_exe}".ppdb
            echo "#Author: "${USER}"" >> "${portproton_exe}".ppdb
            echo "#"${PORTWINE_DB}.exe"" >> "${portproton_exe}".ppdb
            echo "#Rating=1-5" >> "${portproton_exe}".ppdb
            cat "${PORT_PROTON_SCRIPTS_PATH}/portwine_db/default" | grep "##" >> "${portproton_exe}".ppdb
            export PORTWINE_DB_FILE="${portproton_exe}".ppdb
        fi
    fi
    edit_db_from_gui PP_VULKAN_USE PP_WINE_USE PP_PREFIX_NAME 
fi