#!/usr/bin/env bash
# Author: linux-gaming.ru
# clear
export NO_AT_BRIDGE=1
export PP_full_command_line=("$0" $*)
if [ -f "$1" ]; then
    export portwine_exe="$(readlink -f "$1")"
fi
. "$(dirname $(readlink -f "$0"))/runlib"
kill_portwine
killall -15 yad 2>/dev/null
kill -TERM `pgrep -a yad | grep ${portname} | head -n 1 | awk '{print $1}'` 2>/dev/null

if [[ -f "/usr/bin/portproton" ]] && [[ -f "${HOME}/.local/share/applications/PortProton.desktop" ]] ; then
    /usr/bin/env bash "/usr/bin/portproton" "$@" & 
    exit 0
fi

if [[ "${XDG_SESSION_TYPE}" = "wayland" ]] && [[ ! -f "${PORT_PROTON_TMP_PATH}/check_wayland" ]]; then
    zenity_info "$PP_WAYLAND_INFO"
    echo "1" > "${PORT_PROTON_TMP_PATH}/check_wayland"
fi

if [[ -f "${PORT_PROTON_TMP_PATH}/tmp_main_gui_size" ]] && [[ -n "$(cat ${PORT_PROTON_TMP_PATH}/tmp_main_gui_size)" ]] ; then
    export PP_MAIN_SIZE_W="$(cat ${PORT_PROTON_TMP_PATH}/tmp_main_gui_size | awk '{print $1}')"
    export PP_MAIN_SIZE_H="$(cat ${PORT_PROTON_TMP_PATH}/tmp_main_gui_size | awk '{print $2}')"
else
    export PP_MAIN_SIZE_W="1000"
    export PP_MAIN_SIZE_H="260"
fi    

if [[ -n $(basename "${portwine_exe}" | grep .ppack) ]] ; then
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
            export portwine_exe="${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/${crfb}"
            portwine_create_shortcut "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/${crfb}"
        done
        IFS="$orig_IFS"
    fi
    exit 0
fi

portwine_launch () {
    start_portwine
    PORTWINE_MSI=$(basename "${portwine_exe}" | grep .msi)
    PORTWINE_BAT=$(basename "${portwine_exe}" | grep .bat)
    if [[ -n "${PP_VIRTUAL_DESKTOP}" && "${PP_VIRTUAL_DESKTOP}" == "1" ]] ; then
        PP_screen_resolution=$(xrandr --current | grep "*" | awk '{print $1;}' | head -1)
        PP_run explorer "/desktop=PortProton,${PP_screen_resolution}" ${WINE_WIN_START} "$portwine_exe"
    elif [ -n "${PORTWINE_MSI}" ]; then
        PP_run msiexec /i "$portwine_exe"
    elif [[ -n "${PORTWINE_BAT}" || -n "${portwine_exe}" ]] ; then
        PP_run ${WINE_WIN_START} "$portwine_exe"
    else
        PP_run winefile
    fi
}

portwine_start_debug () {
    kill_portwine
    export PP_LOG=1
    export PP_WINEDBG_DISABLE=0
    echo "${port_deb1}" > "${PORT_PROTON_PATH}/${portname}.log"
    echo "${port_deb2}" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "-------------------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "PortWINE version:" >> "${PORT_PROTON_PATH}/${portname}.log"
    read install_ver < "${PORT_PROTON_TMP_PATH}/${portname}_ver"
    echo "${portname}-${install_ver}" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "------------------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Scripts version:" >> "${PORT_PROTON_PATH}/${portname}.log"
    cat "${PORT_PROTON_TMP_PATH}/scripts_ver" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "----------------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    if [ -n "${portwine_exe}" ] ; then
        echo "Debug for programm:" >> "${PORT_PROTON_PATH}/${portname}.log"
        echo "${portwine_exe}" >> "${PORT_PROTON_PATH}/${portname}.log"
        echo "---------------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    echo "GLIBC version:" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo $(ldd --version | grep -m1 ldd | awk '{print $NF}') >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "--------------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    if [[ "${PP_VULKAN_USE}" = "0" ]] ; then 
        echo "PP_VULKAN_USE=${PP_VULKAN_USE} - DX9-11 to ${loc_gui_open_gl}" >> "${PORT_PROTON_PATH}/${portname}.log"
    elif [[ "${PP_VULKAN_USE}" = "3" ]] ; then 
        echo "PP_VULKAN_USE=${PP_VULKAN_USE} - native DX9 on MESA drivers" >> "${PORT_PROTON_PATH}/${portname}.log"
    else 
        echo "PP_VULKAN_USE=${PP_VULKAN_USE}" >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    echo "--------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Version WINE in the Port:" >> "${PORT_PROTON_PATH}/${portname}.log"
    print_var PP_WINE_USE >> "${PORT_PROTON_PATH}/${portname}.log"
    [ -f "${WINEDIR}/version" ] && cat "${WINEDIR}/version" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "------------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Date and time of start debug for ${portname}:" >> "${PORT_PROTON_PATH}/${portname}.log"
    date >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "-----------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "The installation path of the ${portname}:" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "$PORT_PROTON_PATH" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "----------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Operating system" >> "${PORT_PROTON_PATH}/${portname}.log"
    lsb_release -d | sed s/Description/ОС/g >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "--------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Desktop environment:" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Desktop session: ${DESKTOP_SESSION}" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Current desktop: ${XDG_CURRENT_DESKTOP}" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Session type: ${XDG_SESSION_TYPE}" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "--------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Kernel" >> "${PORT_PROTON_PATH}/${portname}.log"
    uname -r >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "-------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "CPU" >> "${PORT_PROTON_PATH}/${portname}.log"
    cat /proc/cpuinfo | grep "model name" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "------------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "RAM" >> "${PORT_PROTON_PATH}/${portname}.log"
    free -m >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "-----------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Graphic cards and drivers:" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo 'lspci -k | grep -EA3 VGA|3D|Display:' >> "${PORT_PROTON_PATH}/${portname}.log"
    echo $(lspci -k | grep -EA3 'VGA|3D|Display') >> "${PORT_PROTON_PATH}/${portname}.log"
    [[ `which glxinfo` ]] && glxinfo -B >> "${PORT_PROTON_PATH}/${portname}.log"
    echo " " >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "inxi -G:" >> "${PORT_PROTON_PATH}/${portname}.log"
    "${PP_WINELIB}/portable/bin/inxi" -G >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "----------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "Vulkan info device name:" >> "${PORT_PROTON_PATH}/${portname}.log"
    [[ `which vulkaninfo` ]] && vulkaninfo | grep deviceName >> "${PORT_PROTON_PATH}/${portname}.log"
    "${PP_WINELIB}/portable/bin/vkcube" --c 50
    if [ $? -eq 0 ]; then
        echo "Vulkan cube test passed successfully" >> "${PORT_PROTON_PATH}/${portname}.log"
    else
        echo "Vkcube test completed with error" >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    if [ ! -x "$(which gamemoderun 2>/dev/null)" ]
    then
        echo "---------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
        echo "!!!gamemod not found!!!"  >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    echo "-------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    if [[ "${PP_USE_D3D_EXTRAS}" != 1 ]]
    then echo "D3D_EXTRAS - disabled" >> "${PORT_PROTON_PATH}/${portname}.log"
    else echo "D3D_EXTRAS - enabled" >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    echo "------------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "winetricks.log:" >> "${PORT_PROTON_PATH}/${portname}.log"
    cat "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log" | sed -e /"^d3dcomp*"/d -e /"^d3dx*"/d >> "${PORT_PROTON_PATH}/${portname}.log"
    echo "-----------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    if [ -n "${PORTWINE_DB_FILE}" ]; then
        echo "Use ${PORTWINE_DB_FILE} db file:" >> "${PORT_PROTON_PATH}/${portname}.log"
        cat "${PORTWINE_DB_FILE}" | sed '/##/d' >> "${PORT_PROTON_PATH}/${portname}.log"
    else
        echo "Use ${PORT_PROTON_SCRIPTS_PATH}/portwine_db/default db file:" >> "${PORT_PROTON_PATH}/${portname}.log"
        cat "${PORT_PROTON_SCRIPTS_PATH}/portwine_db/default" | sed '/##/d' >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    echo "----------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"
    if [ -f "${USER_CONF}" ]; then
        cat "${USER_CONF}" | sed '/bash/d' >> "${PORT_PROTON_PATH}/${portname}.log"
    fi
    echo "---------------------------------------" >> "${PORT_PROTON_PATH}/${portname}.log"

    export DXVK_HUD="full"

    portwine_launch &
    sleep 3
    PP_stop_progress_bar_cover
    unset PP_TIMER
    while read -r line || [[ -n $(pgrep -a yad | grep "yad --text-info --tail --button="STOP":0 --title="DEBUG"" | awk '{print $1}') ]] ; do
            sleep 0.005
            if [[ -n "${line}" ]] && [[ -z "$(echo "${line}" | grep -i "kerberos")" ]] \
                                    && [[ -z "$(echo "${line}" | grep -i "ntlm")" ]]
            then
                echo "# ${line}"
            fi
            if [[ "${PP_TIMER}" != 1 ]] ; then
                sleep 3
                PP_TIMER=1
            fi
    done < "${PORT_PROTON_PATH}/${portname}.log" | yad --text-info --tail --button="STOP":0 --title="DEBUG" \
    --skip-taskbar --center --width=800 --height=400 --text "${port_debug}" &&
    kill_portwine
#    sleep 1 && zenity --info --title "DEBUG" --text "${port_debug}" --no-wrap &> /dev/null && kill_portwine
    sed -i '/.fx$/d' "${PORT_PROTON_PATH}/${portname}.log"
    sed -i '/kerberos/d' "${PORT_PROTON_PATH}/${portname}.log"
    sed -i '/ntlm/d' "${PORT_PROTON_PATH}/${portname}.log"
    sed -i '/HACK_does_openvr_work/d' "${PORT_PROTON_PATH}/${portname}.log"
    sed -i '/Uploading is disabled/d' "${PORT_PROTON_PATH}/${portname}.log"
    deb_text=$(cat "${PORT_PROTON_PATH}/${portname}.log"  | awk '! a[$0]++') 
    echo "$deb_text" > "${PORT_PROTON_PATH}/${portname}.log"
    "$PP_yad" --title="${portname}.log" --borders=7 --no-buttons --text-align=center \
    --text-info --show-uri --wrap --center --width=1200 --height=550  --uri-color=red \
    --filename="${PORT_PROTON_PATH}/${portname}.log"
    stop_portwine
}

PP_winecfg () {
    start_portwine
    PP_run winecfg
}

PP_winefile () {
    start_portwine
    PP_run winefile
}

PP_winecmd () {
    export PP_USE_TERMINAL=1
    start_portwine
    cd "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/drive_c"
    xterm -e "${WINELOADER}" cmd
    stop_portwine
}

PP_winereg () {
    start_portwine
    PP_run regedit
}

PP_prefix_manager () {
    update_winetricks
    start_portwine
    if [ ! -f "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log" ] ; then
        touch "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log"
    fi

    PP_start_progress_bar_block "Starting prefix manager..."
    "${PORT_PROTON_TMP_PATH}/winetricks" dlls list | awk -F'(' '{print $1}' 1> "${PORT_PROTON_TMP_PATH}/dll_list"
    "${PORT_PROTON_TMP_PATH}/winetricks" fonts list | awk -F'(' '{print $1}' 1> "${PORT_PROTON_TMP_PATH}/fonts_list"
    "${PORT_PROTON_TMP_PATH}/winetricks" settings list | awk -F'(' '{print $1}' 1> "${PORT_PROTON_TMP_PATH}/settings_list"
    PP_stop_progress_bar

    gui_prefix_manager () {
        PP_start_progress_bar_block "Starting prefix manager..."
        unset SET_FROM_PFX_MANAGER_TMP SET_FROM_PFX_MANAGER
        old_IFS=$IFS
        IFS=$'\n'
        try_remove_file  "${PORT_PROTON_TMP_PATH}/dll_list_tmp"
        while read PP_BOOL_IN_DLL_LIST ; do
            if [[ -z $(echo "${PP_BOOL_IN_DLL_LIST}" | grep -E 'd3d|directx9|dont_use|dxvk|vkd3d|galliumnine|faudio1') ]] ; then
                if grep "^$(echo ${PP_BOOL_IN_DLL_LIST} | awk '{print $1}')$" "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log" ; then
                    echo -e "true\n$(echo ${PP_BOOL_IN_DLL_LIST} | awk '{print $1}')\n`echo ${PP_BOOL_IN_DLL_LIST} | awk '{ $1 = ""; print substr($0, 2) }'`" >> "${PORT_PROTON_TMP_PATH}/dll_list_tmp"
                else
                    echo -e "false\n`echo "${PP_BOOL_IN_DLL_LIST}" | awk '{print $1}'`\n`echo ${PP_BOOL_IN_DLL_LIST} | awk '{ $1 = ""; print substr($0, 2) }'`" >> "${PORT_PROTON_TMP_PATH}/dll_list_tmp"
                fi
            fi
        done < "${PORT_PROTON_TMP_PATH}/dll_list"
        try_remove_file  "${PORT_PROTON_TMP_PATH}/fonts_list_tmp"
        while read PP_BOOL_IN_FONTS_LIST ; do
            if [[ -z $(echo "${PP_BOOL_IN_FONTS_LIST}" | grep -E 'dont_use') ]] ; then
                if grep "^$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{print $1}')$" "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log" ; then
                    echo -e "true\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{print $1}')\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{ $1 = ""; print substr($0, 2) }')" >> "${PORT_PROTON_TMP_PATH}/fonts_list_tmp"
                else
                    echo -e "false\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{print $1}')\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{ $1 = ""; print substr($0, 2) }')" >> "${PORT_PROTON_TMP_PATH}/fonts_list_tmp"
                fi
            fi
        done < "${PORT_PROTON_TMP_PATH}/fonts_list"
        try_remove_file  "${PORT_PROTON_TMP_PATH}/settings_list_tmp"
        while read PP_BOOL_IN_FONTS_LIST ; do
            if [[ -z $(echo "${PP_BOOL_IN_FONTS_LIST}" | grep -E 'vista|alldlls|autostart_|bad|good|win|videomemory|vd=|isolate_home') ]] ; then
                if grep "^$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{print $1}')$" "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log" ; then
                    echo -e "true\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{print $1}')\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{ $1 = ""; print substr($0, 2) }')" >> "${PORT_PROTON_TMP_PATH}/settings_list_tmp"
                else
                    echo -e "false\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{print $1}')\n$(echo "${PP_BOOL_IN_FONTS_LIST}" | awk '{ $1 = ""; print substr($0, 2) }')" >> "${PORT_PROTON_TMP_PATH}/settings_list_tmp"
                fi
            fi
        done < "${PORT_PROTON_TMP_PATH}/settings_list"
        PP_stop_progress_bar

        KEY_EDIT_MANAGER_GUI=$RANDOM
        yad --plug=$KEY_EDIT_MANAGER_GUI --tabnum=1 --list --checklist \
        --text="Select components to install in prefix: <b>\"${PP_PREFIX_NAME}\"</b>, using wine: <b>\"${PP_WINE_USE}\"</b>" \
        --column=set --column=dll --column=info < "${PORT_PROTON_TMP_PATH}/dll_list_tmp" 1>> "${PORT_PROTON_TMP_PATH}/to_winetricks" &

        yad --plug=$KEY_EDIT_MANAGER_GUI --tabnum=2 --list --checklist \
        --text="Select fonts to install in prefix: <b>\"${PP_PREFIX_NAME}\"</b>, using wine: <b>\"${PP_WINE_USE}\"</b>" \
        --column=set --column=dll --column=info < "${PORT_PROTON_TMP_PATH}/fonts_list_tmp" 1>> "${PORT_PROTON_TMP_PATH}/to_winetricks" &

        yad --plug=$KEY_EDIT_MANAGER_GUI --tabnum=3 --list --checklist \
        --text="Change config for prefix: <b>\"${PP_PREFIX_NAME}\"</b>" \
        --column=set --column=dll --column=info < "${PORT_PROTON_TMP_PATH}/settings_list_tmp" 1>> "${PORT_PROTON_TMP_PATH}/to_winetricks" &

        yad --key=$KEY_EDIT_MANAGER_GUI --notebook --borders=5 --width=700 --height=600 --center \
        --window-icon="$PP_GUI_ICON_PATH/port_proton.png" --title "PREFIX MANAGER..." --tab-pos=bottom --tab="DLL" --tab="FONTS" --tab="SETTINGS"
        YAD_STATUS="$?"
        if [[ "$YAD_STATUS" == "1" || "$YAD_STATUS" == "252" ]] ; then
            stop_portwine
            exit 0
        fi 
        try_remove_file  "${PORT_PROTON_TMP_PATH}/dll_list_tmp"
        try_remove_file  "${PORT_PROTON_TMP_PATH}/fonts_list_tmp"
        try_remove_file  "${PORT_PROTON_TMP_PATH}/settings_list_tmp"

        for STPFXMNG in $(cat "${PORT_PROTON_TMP_PATH}/to_winetricks") ; do
            grep $(echo ${STPFXMNG} | awk -F'|' '{print $2}') "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/winetricks.log" &>/dev/null
            if [ "$?" == "1" ] ; then
                [[ -n "${STPFXMNG}" ]] && SET_FROM_PFX_MANAGER+="$(echo "${STPFXMNG}" | awk -F'|' '{print $2}') "
            fi
        done
        IFS=${old_IFS}
        try_remove_file  "${PORT_PROTON_TMP_PATH}/to_winetricks"

        if [[ -n ${SET_FROM_PFX_MANAGER} ]] ; then
            xterm -e "${PORT_PROTON_TMP_PATH}/winetricks" -q -r -f ${SET_FROM_PFX_MANAGER}
            gui_prefix_manager
        else
            print_info "Nothing to do. Restarting PortProton..."
            stop_portwine &
            /usr/bin/env bash -c ${PP_full_command_line[*]} 
        fi
    }
    gui_prefix_manager
}

PP_winetricks () {
    update_winetricks
    export PP_USE_TERMINAL=1
    start_portwine
    PP_stop_progress_bar
    echo "WINETRICKS..." > "${PORT_PROTON_TMP_PATH}/update_pfx_log"
    unset PP_TIMER
    while read -r line || [[ -n $(pgrep -a yad | grep "yad --text-info --tail --no-buttons --title="WINETRICKS"" | awk '{print $1}') ]] ; do
            sleep 0.005
            if [[ -n "${line}" ]] && [[ -z "$(echo "${line}" | grep -i "gstreamer")" ]] \
                                    && [[ -z "$(echo "${line}" | grep -i "kerberos")" ]] \
                                    && [[ -z "$(echo "${line}" | grep -i "ntlm")" ]]
            then
                echo "# ${line}"
            fi
            if [[ "${PP_TIMER}" != 1 ]] ; then
                sleep 3
                PP_TIMER=1
            fi
    done < "${PORT_PROTON_TMP_PATH}/update_pfx_log" | yad --text-info --tail --no-buttons --title="WINETRICKS" \
    --auto-close --skip-taskbar --width=$PP_GIF_SIZE_X --height=$PP_GIF_SIZE_Y &
    "${PORT_PROTON_TMP_PATH}/winetricks" -q -r -f &>>"${PORT_PROTON_TMP_PATH}/update_pfx_log"
    try_remove_file "${PORT_PROTON_TMP_PATH}/update_pfx_log"
    kill -s SIGTERM "$(pgrep -a yad | grep "title=WINETRICKS" | awk '{print $1}')" > /dev/null 2>&1    
    stop_portwine
}

PP_start_cont_xterm () {
    cd "$HOME"
    xterm
}

PP_create_prefix_backup () {
    cd "$HOME"
    PP_PREFIX_TO_BACKUP=$(yad --file --directory --borders=5 --width=650 --height=500 --auto-close --center \
    --window-icon="$PP_GUI_ICON_PATH/port_proton.png" --title "BACKUP PREFIX TO...")
    YAD_STATUS="$?"
    if [[ "$YAD_STATUS" == "1" || "$YAD_STATUS" == "252" ]] ; then exit 0 ; fi
    if [[ -n "$(grep "/${PP_PREFIX_NAME}/" "${PORT_PROTON_PATH}"/*.desktop )" ]] ; then
        try_remove_file "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/.create_shortcut"
        grep "/${PP_PREFIX_NAME}/" "${PORT_PROTON_PATH}"/*.desktop | awk -F"/${PP_PREFIX_NAME}/" '{print $2}' \
        | awk -F\" '{print $1}' > "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}/.create_shortcut"
    fi
    xterm -e mksquashfs "${PORT_PROTON_PATH}/data/prefixes/${PP_PREFIX_NAME}" "${PP_PREFIX_TO_BACKUP}/${PP_PREFIX_NAME}.ppack.part" -comp zstd &
    sleep 10
    while true ; do
        if [[ -n $(pgrep -a xterm | grep ".ppack.part" | head -n 1 | awk '{print $1}') ]] ; then
            sleep 0.5
        else
            kill -TERM $(pgrep -a mksquashfs | grep ".ppack.part" | head -n 1 | awk '{print $1}')
            sleep 0.3
            if [[ -z "$(pgrep -a mksquashfs | grep ".ppack.part" | head -n 1 | awk '{print $1}')" ]]
            then break
            else sleep 0.3
            fi
        fi
    done
    if [[ -f "${PP_PREFIX_TO_BACKUP}/${PP_PREFIX_NAME}.ppack.part" ]] ; then
        mv -f "${PP_PREFIX_TO_BACKUP}/${PP_PREFIX_NAME}.ppack.part" "${PP_PREFIX_TO_BACKUP}/${PP_PREFIX_NAME}.ppack"
        zenity_info "Backup for prefix \"${PP_PREFIX_NAME}\" successfully created."
    else 
        zenity_error "An error occurred while creating a backup for prefix: \"${PP_PREFIX_NAME}\" !"
    fi
    return 0
}

PP_edit_db () {
    PP_gui_for_edit_db \
    PP_MANGOHUD PP_MANGOHUD_USER_CONF ENABLE_VKBASALT PP_NO_ESYNC PP_NO_FSYNC PP_USE_DXR10 PP_USE_DXR11 \
    PP_USE_NVAPI_AND_DLSS PP_USE_FAKE_DLSS PP_WINE_FULLSCREEN_FSR PP_HIDE_NVIDIA_GPU PP_VIRTUAL_DESKTOP PP_USE_TERMINAL \
    PP_GUI_DISABLED_CS PP_USE_GAMEMODE PP_DX12_DISABLE PP_PRIME_RENDER_OFFLOAD PP_USE_D3D_EXTRAS PP_FIX_VIDEO_IN_GAME \
    PP_USE_GSTREAMER PP_FORCE_LARGE_ADDRESS_AWARE PP_USE_SHADER_CACHE PP_USE_WINE_DXGI
    if [ "$?" == 0 ] ; then
        echo "Restarting PP after update ppdb file..."
        /usr/bin/env bash -c ${PP_full_command_line[*]} &
        exit 0
    fi
    # PP_WINE_ALLOW_XIM PP_FORCE_USE_VSYNC PP_WINEDBG_DISABLE PP_USE_AMDVLK_DRIVER
}

PP_autoinstall_from_db () {
    export PP_USER_TEMP="${PORT_PROTON_TMP_PATH}"
    export PP_FORCE_LARGE_ADDRESS_AWARE=0
    export PP_USE_GAMEMODE=0
    export PP_CHECK_AUTOINSTAL=1
    export PP_GUI_DISABLED_CS=1
    export PP_WINEDBG_DISABLE=1
    export PP_NO_WRITE_WATCH=0
    export PP_VULKAN_USE=0
    export PP_NO_FSYNC=1
    export PP_NO_ESYNC=1
    unset PORTWINE_CREATE_SHORTCUT_NAME
    export PP_DISABLED_CREATE_DB=1
    export PP_MANGOHUD=0
    export ENABLE_VKBASALT=0
    export PP_USE_D3D_EXTRAS=1
    . "${PORT_PROTON_SCRIPTS_PATH}/PP_autoinstall/${PP_YAD_SET}"
}

gui_credits () {
    . "${PORT_PROTON_SCRIPTS_PATH}/credits"
}
export -f gui_credits

###MAIN###

# HOTFIX WGC TO LGC
if [[ ! -z "$(echo ${1} | grep 'wgc_api.exe')" ]] && [[ ! -f "${1}" ]] ; then
    export PP_YAD_SET=PP_LGC
    PP_autoinstall_from_db 
    exit 0
fi

# HOTFIX CALIBRE
if [[ ! -z "$(echo ${1} | grep '/Caliber/')" ]] ; then
    export PP_WINE_USE=PROTON_STEAM_6.3-8
fi

# CLI
case "${1}" in
    '--help' )
        files_from_autoinstall=$(ls "${PORT_PROTON_SCRIPTS_PATH}/PP_autoinstall") 
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
        PP_reinstall_pp ;;

    '--autoinstall' )
        export PP_YAD_SET="$2"
        PP_autoinstall_from_db 
        exit 0 ;;
esac

PP_PREFIX_NAME="$(echo "${PP_PREFIX_NAME}" | sed -e s/[[:blank:]]/_/g)"
PP_ALL_PREFIXES=$(ls "${PORT_PROTON_PATH}/data/prefixes/" | sed -e s/"${PP_PREFIX_NAME}$"//g)
export PP_PREFIX_NAME PP_ALL_PREFIXES

# if [[ -n "${PORTWINE_DB}" ]] && [[ -z `echo "${PP_PREFIX_NAME}" | grep -i "$(echo "${PORTWINE_DB}" | sed -e s/[[:blank:]]/_/g)"` ]] ; then 
#     export PP_PREFIX_NAME="${PP_PREFIX_NAME}!`echo "${PORTWINE_DB}" | sed -e s/[[:blank:]]/_/g`"
# fi

unset PP_ADD_PREFIXES_TO_GUI
IFS_OLD=$IFS
IFS=$'\n'
for PAIG in ${PP_ALL_PREFIXES[*]} ; do 
    [[ "${PAIG}" != $(echo "${PORTWINE_DB^^}" | sed -e s/[[:blank:]]/_/g) ]] && \
    export PP_ADD_PREFIXES_TO_GUI="${PP_ADD_PREFIXES_TO_GUI}!${PAIG}"
done
IFS=$IFS_OLD
export PP_ADD_PREFIXES_TO_GUI="${PP_PREFIX_NAME^^}${PP_ADD_PREFIXES_TO_GUI}"

PP_ALL_DIST=$(ls "${PORT_PROTON_PATH}/data/dist/" | sed -e s/"${PP_PROTON_GE_VER}$//g" | sed -e s/"${PP_PROTON_LG_VER}$//g")
unset DIST_ADD_TO_GUI
for DAIG in ${PP_ALL_DIST}
do
    export DIST_ADD_TO_GUI="${DIST_ADD_TO_GUI}!${DAIG}"
done
if [[ -n "${PORTWINE_DB_FILE}" ]] ; then
    [[ -z "${PP_COMMENT_DB}" ]] && PP_COMMENT_DB="${loc_gui_db_comments} <b>${PORTWINE_DB}</b>."
    if [[ -z "${PP_VULKAN_USE}" || -z "${PP_WINE_USE}" ]] ; then
        unset PP_GUI_DISABLED_CS
        [[ -z "${PP_VULKAN_USE}" ]] && export PP_VULKAN_USE=1
    fi
    case "${PP_VULKAN_USE}" in
            "0") export PP_DEFAULT_VULKAN_USE="${loc_gui_open_gl}!${loc_gui_vulkan_stable}!${loc_gui_vulkan_git}!${loc_gui_gallium_nine}" ;;
            "2") export PP_DEFAULT_VULKAN_USE="${loc_gui_vulkan_git}!${loc_gui_vulkan_stable}!${loc_gui_open_gl}!${loc_gui_gallium_nine}" ;;
            "3") export PP_DEFAULT_VULKAN_USE="${loc_gui_gallium_nine}!${loc_gui_vulkan_stable}!${loc_gui_vulkan_git}!${loc_gui_open_gl}" ;;
              *) export PP_DEFAULT_VULKAN_USE="${loc_gui_vulkan_stable}!${loc_gui_vulkan_git}!${loc_gui_open_gl}!${loc_gui_gallium_nine}" ;;
    esac
    if [[ -n $(echo "${PP_WINE_USE}" | grep "^PROTON_LG$") ]] ; then
        export PP_DEFAULT_WINE_USE="${PP_PROTON_LG_VER}!${PP_PROTON_GE_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE"
    elif [[ -n $(echo "${PP_WINE_USE}" | grep "^PROTON_GE$") ]] ; then
        export PP_DEFAULT_WINE_USE="${PP_PROTON_GE_VER}!${PP_PROTON_LG_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE"
    else
        if [[ "${PP_WINE_USE}" == "${PP_PROTON_LG_VER}" ]] ; then
            export PP_DEFAULT_WINE_USE="${PP_WINE_USE}!${PP_PROTON_GE_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE" 
        elif [[ "${PP_WINE_USE}" == "${PP_PROTON_GE_VER}" ]] ; then
            export PP_DEFAULT_WINE_USE="${PP_WINE_USE}!${PP_PROTON_LG_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE" 
        else
            export DIST_ADD_TO_GUI=$(echo "${DIST_ADD_TO_GUI}" | sed -e s/"\!${PP_WINE_USE}$//g")
            export PP_DEFAULT_WINE_USE="${PP_WINE_USE}!${PP_PROTON_GE_VER}!${PP_PROTON_LG_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE"
        fi
    fi
else
    export PP_DEFAULT_VULKAN_USE="${loc_gui_vulkan_stable}!${loc_gui_vulkan_git}!${loc_gui_open_gl}!${loc_gui_gallium_nine}"
    if [[ -n $(echo "${PP_WINE_USE}" | grep "^PROTON_LG$") ]] ; then
        export PP_DEFAULT_WINE_USE="${PP_PROTON_LG_VER}!${PP_PROTON_GE_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE"
    elif [[ -n $(echo "${PP_WINE_USE}" | grep "^PROTON_GE$") ]] ; then
        export PP_DEFAULT_WINE_USE="${PP_PROTON_GE_VER}!${PP_PROTON_LG_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE"
    else
        if [[ "${PP_WINE_USE}" == "${PP_PROTON_LG_VER}" ]] ; then
            export PP_DEFAULT_WINE_USE="${PP_WINE_USE}!${PP_PROTON_GE_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE" 
        elif [[ "${PP_WINE_USE}" == "${PP_PROTON_GE_VER}" ]] ; then
            export PP_DEFAULT_WINE_USE="${PP_WINE_USE}!${PP_PROTON_LG_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE" 
        else
            export DIST_ADD_TO_GUI=$(echo "${DIST_ADD_TO_GUI}" | sed -e s/"\!${PP_WINE_USE}$//g")
            export PP_DEFAULT_WINE_USE="${PP_WINE_USE}!${PP_PROTON_GE_VER}!${PP_PROTON_LG_VER}${DIST_ADD_TO_GUI}!GET-OTHER-WINE"
        fi     
    fi
    unset PP_GUI_DISABLED_CS
fi
if [ -n "${portwine_exe}" ]; then
    if [[ -z "${PP_GUI_DISABLED_CS}" || "${PP_GUI_DISABLED_CS}" == 0 ]] ; then  
        PP_create_gui_png
        grep -il "${portwine_exe}" "${HOME}/.local/share/applications"/*.desktop
        if [[ "$?" != "0" ]] ; then
            PP_SHORTCUT="${loc_gui_create_shortcut}!$PP_GUI_ICON_PATH/separator.png!${loc_create_shortcut}:100"
        else
            PP_SHORTCUT="${loc_gui_delete_shortcut}!$PP_GUI_ICON_PATH/separator.png!${loc_delete_shortcut}:98"
        fi
        OUTPUT_START=$(yad --text-align=center --text "$PP_COMMENT_DB" --wrap-width=150 --borders=7 --form --center  \
        --title "${portname}-${install_ver} (${scripts_install_ver})" --image "${PP_ICON_FOR_YAD}" --separator=";" --keep-icon-size \
        --window-icon="$PP_GUI_ICON_PATH/port_proton.png" \
        --field="3D API  : :CB" "${PP_DEFAULT_VULKAN_USE}" \
        --field="  WINE  : :CB" "${PP_DEFAULT_WINE_USE}" \
        --field="PREFIX  : :CBE" "${PP_ADD_PREFIXES_TO_GUI}" \
        --field=":LBL" "" \
        --button="${loc_gui_vkbasalt_start}"!"$PP_GUI_ICON_PATH/separator.png"!"${ENABLE_VKBASALT_INFO}":120 \
        --button="${loc_gui_edit_db_start}"!"$PP_GUI_ICON_PATH/separator.png"!"${loc_edit_db} ${PORTWINE_DB}":118 \
        --button="${PP_SHORTCUT}" \
        --button="${loc_gui_debug}"!"$PP_GUI_ICON_PATH/separator.png"!"${loc_debug}":102 \
        --button="${loc_gui_launch}"!"$PP_GUI_ICON_PATH/separator.png"!"${loc_launch}":106 )
        export PP_YAD_SET="$?"
        if [[ "$PP_YAD_SET" == "1" || "$PP_YAD_SET" == "252" ]] ; then exit 0 ; fi
        export VULKAN_MOD=$(echo "${OUTPUT_START}" | grep \;\; | awk -F";" '{print $1}')
        export PP_WINE_VER=$(echo "${OUTPUT_START}" | grep \;\; | awk -F";" '{print $2}')
        export PP_PREFIX_NAME=$(echo "${OUTPUT_START}" | grep \;\; | awk -F";" '{print $3}' | sed -e s/[[:blank:]]/_/g)
        if [[ -z "${PP_PREFIX_NAME}" ]] || [[ -n "$(echo "${PP_PREFIX_NAME}" | grep -E '^_.*' )" ]] ; then
            export PP_PREFIX_NAME="DEFAULT"
        else
            export PP_PREFIX_NAME="${PP_PREFIX_NAME^^}"
        fi
    elif [ -n "${PORTWINE_DB_FILE}" ]; then
        portwine_launch
    fi
else
    button_click () {
        [[ -n "$1" ]] && echo "$1" > "${PORT_PROTON_TMP_PATH}/tmp_yad_form"
        if [[ -n $(pidof -s yad) ]] || [[ -n $(pidof -s yad) ]] ; then
            kill -s SIGUSR1 $(pgrep -a yad | grep "\-\-key=${KEY} \-\-notebook" | awk '{print $1}') > /dev/null 2>&1
        fi
    }
    export -f button_click

    run_desktop_b_click () {
        [[ -n "$1" ]] && echo "$1" > "${PORT_PROTON_TMP_PATH}/tmp_yad_form"
        if [[ -n $(pidof -s yad) ]] || [[ -n $(pidof -s yad) ]] ; then
            kill -s SIGUSR1 $(pgrep -a yad | grep "\-\-key=${KEY} \-\-notebook" | awk '{print $1}') > /dev/null 2>&1
        fi
        PP_EXEC_FROM_DESKTOP="$(cat "${PORT_PROTON_PATH}/${PP_YAD_SET//¬/" "}" | grep Exec | head -n 1 | awk -F"=env " '{print $2}')"

        echo "Restarting PP after choose desktop file..."
        # stop_portwine
        /usr/bin/env bash -c "${PP_EXEC_FROM_DESKTOP}" &
        exit 0 
    }
    export -f run_desktop_b_click

    gui_clear_pfx () {
        if gui_question "${port_clear_pfx}" ; then
            PP_clear_pfx
            echo "Restarting PP after clearing prefix..."
            /usr/bin/env bash -c ${PP_full_command_line[*]} &
            exit 0
        fi
    }
    export -f gui_clear_pfx

    gui_rm_portproton () {
        if gui_question "${port_del2}" ; then
            rm -fr "${PORT_PROTON_PATH}"
            rm -fr "${PORT_PROTON_TMP_PATH}"
            rm -fr "${HOME}/PortWINE"
            rm -f $(grep -il PortProton "${HOME}/.local/share/applications"/*)
            update-desktop-database -q "${HOME}/.local/share/applications"
        fi
        exit 0
    }
    export -f gui_rm_portproton

    gui_PP_update () {
        try_remove_file "${PORT_PROTON_TMP_PATH}/scripts_update_notifier"
        echo "Restarting PP for check update..."
        /usr/bin/env bash -c ${PP_full_command_line[*]} &
        exit 0
    }

    change_loc () {
        try_remove_file "${PORT_PROTON_TMP_PATH}/PortProton_loc"
        echo "Restarting PP for change language..."
        /usr/bin/env bash -c ${PP_full_command_line[*]} &
        exit 0
    }

    gui_wine_uninstaller () {
        start_portwine
        PP_run uninstaller
    }
    export -f gui_wine_uninstaller

    gui_open_user_conf () {
        xdg-open "${PORT_PROTON_PATH}/data/user.conf"
    }
    export -f gui_open_user_conf

    gui_open_scripts_from_backup () {
        cd "${PORT_PROTON_TMP_PATH}/scripts_backup/"
        PP_SCRIPT_FROM_BACKUP=$(yad --file --borders=5 --width=650 --height=500 --auto-close --center \
        --window-icon="$PP_GUI_ICON_PATH/port_proton.png" --title "SCRIPTS FROM BACKUP" --file-filter="backup_scripts|scripts_v*.tar.gz")
        YAD_STATUS="$?"
        if [[ "$YAD_STATUS" == "1" || "$YAD_STATUS" == "252" ]] ; then exit 0 ; fi
        unpack_tar_gz "$PP_SCRIPT_FROM_BACKUP" "${PORT_PROTON_PATH}/data/"
        echo "0" > "${PORT_PROTON_TMP_PATH}/scripts_update_notifier"
        echo "Restarting PP after backup..."
        /usr/bin/env bash -c ${PP_full_command_line[*]} &
        exit 0
    }
    export -f gui_open_scripts_from_backup


    export KEY="$RANDOM"
    
    orig_IFS="$IFS" && IFS=$'\n'
    PP_ALL_DF="$(ls ${PORT_PROTON_PATH}/ | grep .desktop | grep -vE '(PortProton|readme)')"
    if [[ -z "${PP_ALL_DF}" ]]
    then PP_GUI_SORT_TABS=(1 2 3 4 5)
    else PP_GUI_SORT_TABS=(2 3 4 5 1)
    fi  
    PP_GENERATE_BUTTONS="--field=   $loc_create_shortcut_from_gui!${PP_GUI_ICON_PATH}/find_48.png!:FBTN%@bash -c \"button_click PP_find_exe\"%"
    for PP_DESKTOP_FILES in ${PP_ALL_DF} ; do
        PP_NAME_D_ICON="$(cat "${PORT_PROTON_PATH}/${PP_DESKTOP_FILES}" | grep Icon | awk -F= '{print $2}')"
        PP_NAME_D_ICON_48="${PP_NAME_D_ICON//".png"/"_48.png"}"
        if [[ ! -f "${PP_NAME_D_ICON_48}" ]]  && [[ -f "${PP_NAME_D_ICON}" ]] && [[ -x "`which "convert" 2>/dev/null`" ]] ; then
            convert "${PP_NAME_D_ICON}" -resize 48x48 "${PP_NAME_D_ICON_48}" 
        fi
        PP_GENERATE_BUTTONS+="--field=   ${PP_DESKTOP_FILES//".desktop"/""}!${PP_NAME_D_ICON_48}!:FBTN%@bash -c \"run_desktop_b_click "${PP_DESKTOP_FILES//" "/¬}"\"%"
    done
    IFS="$orig_IFS"
    old_IFS=$IFS && IFS="%"
    yad --plug=$KEY --tabnum=${PP_GUI_SORT_TABS[4]} --form --columns=3 --align-buttons --keep-icon-size --scroll --separator=" " ${PP_GENERATE_BUTTONS} &
    IFS="$orig_IFS"

    yad --plug=${KEY} --tabnum=${PP_GUI_SORT_TABS[3]} --form --columns=3 --align-buttons --keep-icon-size --separator=";" \
    --field="   $loc_gui_PP_reinstall_pp"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_PP_reinstall_pp"' \
    --field="   $loc_gui_rm_pp"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_rm_portproton"' \
    --field="   $loc_gui_upd_pp"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_PP_update"' \
    --field="   $loc_gui_changelog"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click open_changelog"' \
    --field="   $loc_gui_change_loc"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click change_loc"' \
    --field="   $loc_gui_edit_usc"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_open_user_conf"' \
    --field="   $loc_gui_scripts_fb"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_open_scripts_from_backup"' \
    --field="   Xterm"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click PP_start_cont_xterm"' \
    --field="   $loc_gui_credits"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_credits"' &

    yad --plug=${KEY} --tabnum=${PP_GUI_SORT_TABS[2]} --form --columns=3 --align-buttons --keep-icon-size --separator=";" \
    --field="  3D API  : :CB" "${loc_gui_vulkan_stable}!${loc_gui_vulkan_git}!${loc_gui_open_gl}!${loc_gui_gallium_nine}" \
    --field="  PREFIX  : :CBE" "${PP_ADD_PREFIXES_TO_GUI}" \
    --field="  WINE    : :CB" "${PP_DEFAULT_WINE_USE}" \
    --field="                  DOWNLOAD OTHER WINE"!"$PP_GUI_ICON_PATH/separator.png"!"${loc_download_other_wine}":"FBTN" '@bash -c "button_click gui_proton_downloader"' \
    --field='   WINECFG'!"$PP_GUI_ICON_PATH/separator.png"!"${loc_winecfg}":"FBTN" '@bash -c "button_click WINECFG"' \
    --field='   WINEFILE'!"$PP_GUI_ICON_PATH/separator.png"!"${loc_winefile}":"FBTN" '@bash -c "button_click WINEFILE"' \
    --field='   WINECMD'!"$PP_GUI_ICON_PATH/separator.png"!"${loc_winecmd}":"FBTN" '@bash -c "button_click WINECMD"' \
    --field='   WINEREG'!"$PP_GUI_ICON_PATH/separator.png"!"${loc_winereg}":"FBTN" '@bash -c "button_click WINEREG"' \
    --field='   WINETRICKS'!"$PP_GUI_ICON_PATH/separator.png"!"${loc_winetricks}":"FBTN" '@bash -c "button_click WINETRICKS"' \
    --field="   WINE UNINSTALLER"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_wine_uninstaller"' \
    --field="   CLEAR PREFIX"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click gui_clear_pfx"' \
    --field="   CREATE PFX BACKUP"!"$PP_GUI_ICON_PATH/separator.png"!"":"FBTN" '@bash -c "button_click PP_create_prefix_backup"' &> "${PORT_PROTON_TMP_PATH}/tmp_yad_form_vulkan" &

    yad --plug=$KEY --tabnum=${PP_GUI_SORT_TABS[1]} --form --columns=3 --align-buttons --keep-icon-size --scroll  \
    --field="   Dolphin 5.0"!"$PP_GUI_ICON_PATH/dolphin.png"!"":"FBTN" '@bash -c "button_click PP_DOLPHIN"' \
    --field="   MAME"!"$PP_GUI_ICON_PATH/mame.png"!"":"FBTN" '@bash -c "button_click PP_MAME"' \
    --field="   ScummVM"!"$PP_GUI_ICON_PATH/scummvm.png"!"":"FBTN" '@bash -c "button_click PP_SCUMMVM"' \
    --field="   RetroArch"!"$PP_GUI_ICON_PATH/retroarch.png"!"":"FBTN" '@bash -c "button_click PP_RETROARCH"' \
    --field="   PPSSPP Windows"!"$PP_GUI_ICON_PATH/ppsspp.png"!"":"FBTN" '@bash -c "button_click PP_PPSSPP"' \
    --field="   Citra"!"$PP_GUI_ICON_PATH/citra.png"!"":"FBTN" '@bash -c "button_click PP_CITRA"' \
    --field="   Cemu"!"$PP_GUI_ICON_PATH/cemu.png"!"":"FBTN" '@bash -c "button_click PP_CEMU"' \
    --field="   DuckStation"!"$PP_GUI_ICON_PATH/duckstation.png"!"":"FBTN" '@bash -c "button_click PP_DUCKSTATION"' \
    --field="   ePSXe"!"$PP_GUI_ICON_PATH/epsxe.png"!"":"FBTN" '@bash -c "button_click PP_EPSXE"' \
    --field="   Project64"!"$PP_GUI_ICON_PATH/project64.png"!"":"FBTN" '@bash -c "button_click PP_PROJECT64"' \
    --field="   VBA-M"!"$PP_GUI_ICON_PATH/vba-m.png"!"":"FBTN" '@bash -c "button_click PP_VBA-M"' \
    --field="   Yabause"!"$PP_GUI_ICON_PATH/yabause.png"!"":"FBTN" '@bash -c "button_click PP_YABAUSE"' &

    yad --plug=$KEY --tabnum=${PP_GUI_SORT_TABS[0]} --form --columns=3 --align-buttons --keep-icon-size --scroll \
    --field="   Lesta Game Center"!"$PP_GUI_ICON_PATH/lgc.png"!"":"FBTN" '@bash -c "button_click PP_LGC"' \
    --field="   Wargaming Game Center"!"$PP_GUI_ICON_PATH/wgc.png"!"":"FBTN" '@bash -c "button_click PP_WGC"' \
    --field="   vkPlay Games Center"!"$PP_GUI_ICON_PATH/mygames.png"!"":"FBTN" '@bash -c "button_click PP_VKPLAY"' \
    --field="   Battle.net Launcher"!"$PP_GUI_ICON_PATH/battle_net.png"!"":"FBTN" '@bash -c "button_click PP_BATTLE_NET"' \
    --field="   Epic Games Launcher"!"$PP_GUI_ICON_PATH/epicgames.png"!"":"FBTN" '@bash -c "button_click PP_EPIC"' \
    --field="   GoG Galaxy Launcher"!"$PP_GUI_ICON_PATH/gog.png"!"":"FBTN" '@bash -c "button_click PP_GOG"' \
    --field="   Ubisoft Game Launcher"!"$PP_GUI_ICON_PATH/ubc.png"!"":"FBTN" '@bash -c "button_click PP_UBC"' \
    --field="   EVE Online Launcher"!"$PP_GUI_ICON_PATH/eve.png"!"":"FBTN" '@bash -c "button_click PP_EVE"' \
    --field="   EA App"!"$PP_GUI_ICON_PATH/eaapp.png"!"":"FBTN" '@bash -c "button_click PP_EAAPP"' \
    --field="   Rockstar Games Launcher"!"$PP_GUI_ICON_PATH/Rockstar.png"!"":"FBTN" '@bash -c "button_click PP_ROCKSTAR"' \
    --field="   Ankama Launcher"!"$PP_GUI_ICON_PATH/ankama.png"!"":"FBTN" '@bash -c "button_click PP_ANKAMA"' \
    --field="   OSU"!"$PP_GUI_ICON_PATH/osu.png"!"":"FBTN" '@bash -c "button_click PP_OSU"' \
    --field="   League of Legends"!"$PP_GUI_ICON_PATH/lol.png"!"":"FBTN" '@bash -c "button_click PP_LOL"' \
    --field="   Gameforge Client"!"$PP_GUI_ICON_PATH/gameforge.png"!"":"FBTN" '@bash -c "button_click  PP_GAMEFORGE"' \
    --field="   World of Sea Battle (BETA)"!"$PP_GUI_ICON_PATH/wosb.png"!"":"FBTN" '@bash -c "button_click PP_WOSB"' \
    --field="   CALIBER"!"$PP_GUI_ICON_PATH/caliber.png"!"":"FBTN" '@bash -c "button_click PP_CALIBER"' \
    --field="   FULQRUM GAMES"!"$PP_GUI_ICON_PATH/fulqrumgames.png"!"":"FBTN" '@bash -c "button_click PP_FULQRUM_GAMES"' \
    --field="   Plarium Play"!"$PP_GUI_ICON_PATH/plariumplay.png"!"":"FBTN" '@bash -c "button_click PP_PLARIUM_PLAY"' \
    --field="   ITCH.IO"!"$PP_GUI_ICON_PATH/itch.png"!"":"FBTN" '@bash -c "button_click PP_ITCH"' \
    --field="   Steam (unstable)"!"$PP_GUI_ICON_PATH/steam.png"!"":"FBTN" '@bash -c "button_click PP_STEAM"' \
    --field="   Crossout"!"$PP_GUI_ICON_PATH/crossout.png"!"":"FBTN" '@bash -c "button_click PP_CROSSOUT"' \
    --field="   Indiegala Client"!"$PP_GUI_ICON_PATH/igclient.png"!"":"FBTN" '@bash -c "button_click PP_IGCLIENT"' \
    --field="   Warframe"!"$PP_GUI_ICON_PATH/warframe.png"!"":"FBTN" '@bash -c "button_click PP_WARFRAME"' \
    --field="   Panzar"!"$PP_GUI_ICON_PATH/panzar.png"!"":"FBTN" '@bash -c "button_click PP_PANZAR"' \
    --field="   STALCRAFT"!"$PP_GUI_ICON_PATH/stalcraft.png"!"":"FBTN" '@bash -c "button_click PP_STALCRAFT"' \
    --field="   ROBLOX"!"$PP_GUI_ICON_PATH/roblox.png"!"":"FBTN" '@bash -c "button_click PP_ROBLOX"' \
    --field="   Path of Exile"!"$PP_GUI_ICON_PATH/poe.png"!"":"FBTN" '@bash -c "button_click PP_POE"' &

    # --field="   Secret World Legends (ENG)"!"$PP_GUI_ICON_PATH/swl.png"!"":"FBTN" '@bash -c "button_click PP_SWL"'
    # --field="   Guild Wars 2"!"$PP_GUI_ICON_PATH/gw2.png"!"":"FBTN" '@bash -c "button_click PP_GUILD_WARS_2"'
    # --field="   Bethesda.net Launcher"!"$PP_GUI_ICON_PATH/bethesda.png"!"":"FBTN" '@bash -c "button_click PP_BETHESDA"'

    if  [[ `which wmctrl` ]] &>/dev/null ; then
        sleep 2
        while [[ $(pgrep -a yad | head -n 1 | awk '{print $1}' 2>/dev/null) ]] ; do
            sleep 2
            PP_MAIN_GUI_SIZE_TMP="$(wmctrl -lG | grep PortProton-1.0 | awk '{print $5" "$6}' 2>/dev/null)"
            if [[ -n "${PP_MAIN_GUI_SIZE_TMP}" ]] ; then
                echo "${PP_MAIN_GUI_SIZE_TMP}" > "${PORT_PROTON_TMP_PATH}/tmp_main_gui_size"
            fi
        done
    fi &

    if [[ -z "${PP_ALL_DF}" ]] ; then
        yad --key=$KEY --notebook --borders=5 --width="${PP_MAIN_SIZE_W}" --height="${PP_MAIN_SIZE_H}" --no-buttons --auto-close --center \
        --window-icon="$PP_GUI_ICON_PATH/port_proton.png" --title "${portname}-${install_ver} (${scripts_install_ver})" \
        --tab-pos=bottom --keep-icon-size \
        --tab="$loc_mg_autoinstall"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_emulators"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_wine_settings"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_portproton_settings"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_installed"!"$PP_GUI_ICON_PATH/separator.png"!""
        YAD_STATUS="$?"
    else
        yad --key=$KEY --notebook --borders=5 --width="${PP_MAIN_SIZE_W}" --height="${PP_MAIN_SIZE_H}" --no-buttons --auto-close --center \
        --window-icon="$PP_GUI_ICON_PATH/port_proton.png" --title "${portname}-${install_ver} (${scripts_install_ver})" \
        --tab-pos=bottom --keep-icon-size \
        --tab="$loc_mg_installed"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_autoinstall"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_emulators"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_wine_settings"!"$PP_GUI_ICON_PATH/separator.png"!"" \
        --tab="$loc_mg_portproton_settings"!"$PP_GUI_ICON_PATH/separator.png"!""
        YAD_STATUS="$?"
    fi

    if [[ "$YAD_STATUS" == "1" || "$YAD_STATUS" == "252" ]] ; then exit 0 ; fi

    if [[ -f "${PORT_PROTON_TMP_PATH}/tmp_yad_form" ]]; then
        export PP_YAD_SET=$(cat "${PORT_PROTON_TMP_PATH}/tmp_yad_form" | head -n 1 | awk '{print $1}')
    fi
    if [[ -f "${PORT_PROTON_TMP_PATH}/tmp_yad_form_vulkan" ]] ; then
        export VULKAN_MOD=$(cat "${PORT_PROTON_TMP_PATH}/tmp_yad_form_vulkan" | grep \;\;  | awk -F";" '{print $1}')
        export PP_PREFIX_NAME=$(cat "${PORT_PROTON_TMP_PATH}/tmp_yad_form_vulkan" | grep \;\;  | awk -F";" '{print $2}' | sed -e "s/[[:blank:]]/_/g" )
        export PP_WINE_VER=$(cat "${PORT_PROTON_TMP_PATH}/tmp_yad_form_vulkan" | grep \;\; | awk -F";" '{print $3}')
        if [[ -z "${PP_PREFIX_NAME}" ]] || [[ -n "$(echo "${PP_PREFIX_NAME}" | grep -E '^_.*' )" ]] ; then
            export PP_PREFIX_NAME="DEFAULT"
        else
            export PP_PREFIX_NAME="${PP_PREFIX_NAME^^}"
        fi
        try_remove_file "${PORT_PROTON_TMP_PATH}/tmp_yad_form_vulkan"
    fi
    export PP_DISABLED_CREATE_DB=1
fi

case "${VULKAN_MOD}" in
    "${loc_gui_open_gl}" )          export PP_VULKAN_USE="0" ;;
    "${loc_gui_vulkan_stable}" )    export PP_VULKAN_USE="1" ;;
    "${loc_gui_vulkan_git}" )       export PP_VULKAN_USE="2" ;;
    "${loc_gui_gallium_nine}" )     export PP_VULKAN_USE="3" ;;
esac

init_wine_ver

if [[ -z "${PP_DISABLED_CREATE_DB}" ]] ; then
    if [[ -n "${PORTWINE_DB}" ]] && [[ -z "${PORTWINE_DB_FILE}" ]] ; then
        PORTWINE_DB_FILE=$(grep -il "\#${PORTWINE_DB}.exe" "${PORT_PROTON_SCRIPTS_PATH}/portwine_db"/*)
        if [[ -z "${PORTWINE_DB_FILE}" ]] ; then
            echo "#!/usr/bin/env bash"  > "${portwine_exe}".ppdb
            echo "#Author: "${USER}"" >> "${portwine_exe}".ppdb
            echo "#"${PORTWINE_DB}.exe"" >> "${portwine_exe}".ppdb
            echo "#Rating=1-5" >> "${portwine_exe}".ppdb
            cat "${PORT_PROTON_SCRIPTS_PATH}/portwine_db/default" | grep "##" >> "${portwine_exe}".ppdb
            export PORTWINE_DB_FILE="${portwine_exe}".ppdb
        fi
    fi
    edit_db_from_gui PP_VULKAN_USE PP_WINE_USE PP_PREFIX_NAME 
fi

case "$PP_YAD_SET" in
    98) portwine_delete_shortcut ;;
    100) portwine_create_shortcut ;;
    DEBUG|102) portwine_start_debug ;;
    106) portwine_launch ;;
    WINECFG|108) PP_winecfg ;;
    WINEFILE|110) PP_winefile ;;
    WINECMD|112) PP_winecmd ;;
    WINEREG|114) PP_winereg ;;
    WINETRICKS|116) PP_prefix_manager ;;
    118) PP_edit_db ;;
    gui_clear_pfx) gui_clear_pfx ;;
    gui_open_user_conf) gui_open_user_conf ;;
    gui_wine_uninstaller) gui_wine_uninstaller ;;
    gui_rm_portproton) gui_rm_portproton ;;
    gui_PP_reinstall_pp) PP_reinstall_pp ;;
    gui_PP_update) gui_PP_update ;;
    gui_proton_downloader) gui_proton_downloader ;;
    gui_open_scripts_from_backup) gui_open_scripts_from_backup ;;
    open_changelog) open_changelog ;;
    change_loc) change_loc ;;
    120) gui_vkBasalt ;;
    PP_create_prefix_backup) PP_create_prefix_backup ;;
    gui_credits) gui_credits ;;
    PP_start_cont_xterm) PP_start_cont_xterm ;;
    PP_find_exe) PP_find_exe ;;
    PP_*) PP_autoinstall_from_db ;;
    *.desktop) run_desktop_b_click ;;
    1|252|*) exit 0 ;;
esac

stop_portwine
