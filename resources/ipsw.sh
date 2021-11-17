#!/bin/bash

JailbreakSet() {
    Jailbreak=1
    if [[ $ProductType == "iPhone4,1" || $ProductType == "iPad2,4" || $ProductType == "iPad2,5" ||
          $ProductType == "iPad2,6" || $ProductType == "iPad2,7" || $ProductType == "iPod5,1" ]] ||
        [[ $ProductType == "iPad3"* && $DeviceProc == 5 ]]; then
        [[ $OSVer == "8.4.1" ]] && JBDaibutsu=1
    fi

    if [[ $JBDaibutsu == 1 ]]; then
        JBName="daibutsu"
    elif [[ $OSVer == "8.4.1" ]]; then
        JBName="EtasonJB"
    elif [[ $OSVer == "6.1.3" ]]; then
        JBName="p0sixspwn"
    fi
}

MemoryOption() {
    if [[ $Jailbreak == 1 && $Verify == 1 && $platform != "win" ]]; then
        Input "Memory Option for creating custom IPSW"
        Echo "* This option makes creating the custom IPSW faster, but it requires at least 8GB of RAM."
        Echo "* If you do not have enough RAM, disable this option and make sure that you have enough storage space."
        Echo "* This option is enabled by default (Y)."
        read -p "$(Input 'Enable this option? (Y/n):')" JBMemory
        if [[ $JBMemory == 'N' || $JBMemory == 'n' ]]; then
            Log "Memory option disabled by user."
        else
            Log "Memory option enabled."
        fi
        echo
    fi
}

IPSW32() {
    local Bundle="Down_${ProductType}_${OSVer}_${BuildVer}.bundle"
    local ExtraArgs
    local JBFiles
    local JBSHA1

    if [[ $IPSWRestore == $IPSWCustom ]]; then
        Log "Found existing Custom IPSW. Skipping IPSW creation."
        return
    fi

    if [[ $JBDaibutsu == 1 ]]; then
        ExtraArgs+="-daibutsu "
        echo '#!/bin/bash' > tmp/reboot.sh
        echo "mount_hfs /dev/disk0s1s1 /mnt1; mount_hfs /dev/disk0s1s2 /mnt2" >> tmp/reboot.sh
        echo "nvram -d boot-partition; nvram -d boot-ramdisk" >> tmp/reboot.sh
        echo "/usr/bin/haxx_overwrite -$HWModel" >> tmp/reboot.sh
        JBFiles2=("bin.tar" "cydia.tar" "untether.tar")
        JBSHA1=("98034227c68610f4c7dd48ca9e622314a1e649e7" "2e9e662afe890e50ccf06d05429ca12ce2c0a3a3" "f88ec9a1b3011c4065733249363e9850af5f57c8")
        cd tmp
        for i in {0..2}; do
            local URL="https://github.com/dora2-iOS/daibutsuCFW/raw/main/build/src/"
            (( i > 0 )) && URL+="daibutsu/${JBFiles2[$i]}" || URL+="${JBFiles2[$i]}"
            if [[ ! -e ../resources/jailbreak/${JBFiles2[$i]} ]]; then
                Log "Downloading ${JBFiles2[$i]}..."
                SaveFile $URL ${JBFiles2[$i]} ${JBSHA1[$i]}
                mv ${JBFiles2[$i]} ../resources/jailbreak
            fi
            JBFiles2[$i]=jailbreak/${JBFiles2[$i]}
        done
        cd ..

    elif [[ $Jailbreak == 1 ]]; then
        if [[ $OSVer == "8.4.1" ]]; then
            JBFiles=("fstab.tar" "etasonJB-untether.tar" "Cydia8.tar")
            JBSHA1="6459dbcbfe871056e6244d23b33c9b99aaeca970"
            ExtraArgs+="-s 2305 "
        elif [[ $OSVer == "6.1.3" ]]; then
            JBFiles=("fstab_rw.tar" "p0sixspwn.tar" "Cydia6.tar")
            JBSHA1="1d5a351016d2546aa9558bc86ce39186054dc281"
            ExtraArgs+="-s 1260 "
        else
            Error "No OSVer selected?"
        fi
        if [[ ! -e resources/jailbreak/${JBFiles[2]} ]]; then
            cd tmp
            Log "Downloading ${JBFiles[2]}..."
            SaveFile https://github.com/LukeZGD/iOS-OTA-Downgrader-Keys/releases/download/jailbreak/${JBFiles[2]} ${JBFiles[2]} $JBSHA1
            mv ${JBFiles[2]} ../resources/jailbreak
            cd ..
        fi
        for i in {0..2}; do
            JBFiles[$i]=jailbreak/${JBFiles[$i]}
        done
    fi
    ExtraArgs+="-bbupdate"

    if [[ ! -e $IPSWCustom.ipsw ]]; then
        [[ $JBMemory != 'N' && $JBMemory != 'n' ]] && ExtraArgs+=" -memory"
        Log "Preparing custom IPSW..."
        cd resources
        rm -rf FirmwareBundles
        if [[ $JBDaibutsu == 1 && -d firmware/JailbreakBundles/$Bundle ]]; then
            cp -R firmware/JailbreakBundles FirmwareBundles
        else
            cp -R firmware/FirmwareBundles FirmwareBundles
        fi
        $ipsw ./../$IPSW.ipsw ./../$IPSWCustom.ipsw $ExtraArgs "${JBFiles[@]}"
        cd ..
    fi
    if [[ ! -e $IPSWCustom.ipsw ]]; then
        Error "Failed to find custom IPSW. Please run the script again" \
        "You may try selecting N for memory option"
    fi

    Log "Setting restore IPSW to: $IPSWCustom.ipsw"
    IPSWRestore=$IPSWCustom
}
