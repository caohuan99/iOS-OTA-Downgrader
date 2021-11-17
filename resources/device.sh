#!/bin/bash

FindDevice() {
    local DeviceIn
    local i=0
    local Timeout=999
    local USB
    [[ $1 == "DFU" ]] && USB=1227 || USB=1281
    [[ -n $2 ]] && Timeout=3
    
    Log "Finding device in $1 mode..."
    while (( i < Timeout )); do
        if [[ $platform == "linux" ]]; then
            DeviceIn=$(lsusb | grep -c "05ac:$USB")
        else
            [[ $($irecovery -q 2>/dev/null | grep -w "MODE" | cut -c 7-) == "$1" ]] && DeviceIn=1
        fi
        if [[ $DeviceIn == 1 ]]; then
            Log "Found device in $1 mode."
            DeviceState="$1"
            break
        fi
        sleep 1
        ((i++))
    done
    
    if [[ $DeviceIn != 1 ]]; then
        [[ $2 == "error" ]] && Error "Failed to find device in $1 mode. (Timed out)"
        return 1
    fi
}

GetDeviceValues() {
    local ideviceinfo2
    local version
    
    Log "Finding device in Normal mode..."
    DeviceState=
    ideviceinfo2=$($ideviceinfo -s)
    if [[ $? != 0 && $1 != "NoDevice" ]]; then
        Log "Finding device in DFU/recovery mode..."
        [[ $platform == "linux" ]] && Echo "* Enter root password of your PC when prompted"
        DeviceState="$($irecovery -q 2>/dev/null | grep -w "MODE" | cut -c 7-)"
    elif [[ $1 == "NoDevice" ]]; then
        Log "NoDevice argument detected. Skipping device detection"
        DeviceState="NoDevice"
    elif [[ -n $ideviceinfo2 ]]; then
        DeviceState="Normal"
    fi

    if [[ $DeviceState == "DFU" || $DeviceState == "Recovery" ]]; then
        local ProdCut=7
        ProductType=$($irecovery -qv 2>&1 | grep "Connected to iP" | cut -c 14-)
        [[ $(echo $ProductType | cut -c 3) == 'h' ]] && ProdCut=9
        ProductType=$(echo $ProductType | cut -c -$ProdCut)
        UniqueChipID=$((16#$(echo $($irecovery -q | grep "ECID" | cut -c 7-) | cut -c 3-)))
        ProductVer="Unknown"
    elif [[ $DeviceState == "Normal" ]]; then
        ProductType=$(echo "$ideviceinfo2" | grep "ProductType" | cut -c 14-)
        [[ ! $ProductType ]] && ProductType=$($ideviceinfo | grep "ProductType" | cut -c 14-)
        ProductVer=$(echo "$ideviceinfo2" | grep "ProductVer" | cut -c 17-)
        UniqueChipID=$(echo "$ideviceinfo2" | grep "UniqueChipID" | cut -c 15-)
        UniqueDeviceID=$(echo "$ideviceinfo2" | grep "UniqueDeviceID" | cut -c 17-)
        version="(iOS $ProductVer) "
    fi

    if [[ ! $DeviceState ]]; then
        echo -e "\n${Color_R}[Error] No device detected. Please put the device in normal mode before proceeding. ${Color_N}"
        echo "${Color_Y}* Make sure to also trust this computer by selecting \"Trust\" at the pop-up. ${Color_N}"
        echo "${Color_Y}* For Windows/macOS users, double-check if the device is being detected by iTunes/Finder. ${Color_N}"
        echo "${Color_Y}* Recovery or DFU mode is also applicable. For more details regarding alternative methods, read the \"Troubleshooting\" wiki page in GitHub ${Color_N}"
        echo "${Color_Y}* To perform operations without an iOS device connected, add NoDevice as an argument. Example: ./restore.sh NoDevice ${Color_N}"
        exit 1
    elif [[ -n $DeviceState ]]; then
        if [[ ! $ProductType ]]; then
            read -p "$(Input 'Enter ProductType (eg. iPad2,1):')" ProductType
        fi
        if [[ ! $UniqueChipID || $UniqueChipID == 0 ]]; then
            read -p "$(Input 'Enter UniqueChipID (ECID, must be decimal):')" UniqueChipID
        fi
    fi
    
    Firmware=resources/firmware/$ProductType
    Baseband=0
    BasebandURL=$(cat $Firmware/13G37/url 2>/dev/null)
    
    if [[ $ProductType == "iPad2,2" ]]; then
        BasebandURL=$(cat $Firmware/13G36/url)
        Baseband="ICE3_04.12.09_BOOT_02.13.Release.bbfw"
        BasebandSHA1="e6f54acc5d5652d39a0ef9af5589681df39e0aca"
    
    elif [[ $ProductType == "iPad2,3" ]]; then
        Baseband="Phoenix-3.6.03.Release.bbfw"
        BasebandSHA1="8d4efb2214344ea8e7c9305392068ab0a7168ba4"
    
    elif [[ $ProductType == "iPad2,6" || $ProductType == "iPad2,7" ]]; then
        Baseband="Mav5-11.80.00.Release.bbfw"
        BasebandSHA1="aa52cf75b82fc686f94772e216008345b6a2a750"
    
    elif [[ $ProductType == "iPad3,2" || $ProductType == "iPad3,3" ]]; then
        Baseband="Mav4-6.7.00.Release.bbfw"
        BasebandSHA1="a5d6978ecead8d9c056250ad4622db4d6c71d15e"
    
    elif [[ $ProductType == "iPhone4,1" ]]; then
        Baseband="Trek-6.7.00.Release.bbfw"
        BasebandSHA1="22a35425a3cdf8fa1458b5116cfb199448eecf49"
    
    elif [[ $ProductType == "iPad3,5" || $ProductType == "iPad3,6" ||
            $ProductType == "iPhone5,1" || $ProductType == "iPhone5,2" ]]; then
        BasebandURL=$(cat $Firmware/14G61/url)
        Baseband="Mav5-11.80.00.Release.bbfw"
        BasebandSHA1="8951cf09f16029c5c0533e951eb4c06609d0ba7f"
    
    elif [[ $ProductType == "iPad4,2" || $ProductType == "iPad4,3" || $ProductType == "iPad4,5" ||
            $ProductType == "iPhone6,1" || $ProductType == "iPhone6,2" ]]; then
        BasebandURL=$(cat $Firmware/14G60/url)
        Baseband="Mav7Mav8-7.60.00.Release.bbfw"
        BasebandSHA1="f397724367f6bed459cf8f3d523553c13e8ae12c"
    
    elif [[ $ProductType != "iPad2"* && $ProductType != "iPad3"* && $ProductType != "iPad4,1" &&
            $ProductType != "iPad4,4" && $ProductType != "iPod5,1" && $ProductType != "iPhone5"* ]]; then
        Error "Your device $ProductType ${version}is not supported."
    else
        BasebandURL=0
    fi
    
    if [[ $ProductType == "iPad2"* || $ProductType == "iPad3,1" || $ProductType == "iPad3,2" ||
          $ProductType == "iPad3,3" || $ProductType == "iPhone4,1" || $ProductType == "iPod5,1" ]]; then
        DeviceProc=5
    elif [[ $ProductType == "iPhone5"* || $ProductType == "iPad3"* ]]; then
        DeviceProc=6
    elif [[ $ProductType == "iPhone6"* || $ProductType == "iPad4"* ]]; then
        DeviceProc=7
    fi
    
    HWModel=$(cat $Firmware/hwmodel)
    
    if [[ ! $BasebandURL || ! $HWModel ]]; then
        Error "Missing BasebandURL and/or HWModel values. Is the firmware folder missing?" \
        "Reinstall dependencies and try again. For more details, read the \"Troubleshooting\" wiki page in GitHub"
    fi
    
    if [[ $ProductType == "iPod5,1" ]]; then
        iBSS="${HWModel}ap"
        iBSSBuildVer="10B329"
    elif [[ $ProductType == "iPad3,1" ]]; then
        iBSS="${HWModel}ap"
        iBSSBuildVer="11D257"
    elif [[ $ProductType == "iPhone6"* ]]; then
        iBSS="iphone6"
        IPSWType="iPhone_4.0_64bit"
    elif [[ $ProductType == "iPad4"* ]]; then
        iBSS="ipad4"
        IPSWType="iPad_64bit"
    else
        iBSS="$HWModel"
        iBSSBuildVer="12H321"
    fi
    [[ ! $IPSWType ]] && IPSWType="$ProductType"
    iBSS="iBSS.$iBSS.RELEASE"
    SEP="sep-firmware.$HWModel.RELEASE.im4p"
    
    Log "$ProductType ${version}connected in $DeviceState mode."
    Log "ECID: $UniqueChipID"
}

Baseband841() {
    BasebandURL=$(cat $Firmware/12H321/url)
    if [[ $ProductType == "iPad2,3" ]]; then
        Baseband="Phoenix-3.0.04.Release.bbfw"
        BasebandSHA1="a507ee2fe061dfbf8bee7e512df52ade8777e113"

    elif [[ $ProductType == "iPad3,2" || $ProductType == "iPad3,3" ]]; then
        Baseband="Mav4-5.4.00.Release.bbfw"
        BasebandSHA1="b51f10bda04cd51f673a75d064c18af1ccb661fe"

    elif [[ $ProductType == "iPhone4,1" ]]; then
        Baseband="Trek-5.5.00.Release.bbfw"
        BasebandSHA1="24849fa866a855e7e640c72c1cb2af6a0e30c742"

    elif [[ $ProductType == "iPad2,6" || $ProductType == "iPad2,7" ||
            $ProductType == "iPad3,5" || $ProductType == "iPad3,6" ||
            $ProductType == "iPhone5,1" || $ProductType == "iPhone5,2" ]]; then
        Baseband="Mav5-8.02.00.Release.bbfw"
        BasebandSHA1="db71823841ffab5bb41341576e7adaaeceddef1c"
    fi
}

CheckM8() {
    local pwnDFUTool
    local pwnDFUDevice
    local pwnD=1
    
    if [[ $platform == "macos" && $(uname -m) != "x86_64" ]]; then
        pwnDFUTool="iPwnder32"
    elif [[ $platform == "macos" ]]; then
        Selection=("iPwnder32" "ipwndfu")
        Input "Select pwnDFU tool to use (Select 1 if unsure):"
        select opt in "${Selection[@]}"; do
        case $opt in
            "ipwndfu" ) pwnDFUTool="ipwndfu"; break;;
            *) pwnDFUTool="iPwnder32"; break;;
        esac
        done
    else
        pwnDFUTool="ipwndfu"
    fi
    
    Log "Entering pwnDFU mode with $pwnDFUTool..."
    if [[ $pwnDFUTool == "ipwndfu" ]]; then
        cd resources/ipwndfu
        [[ $platform == "linux" ]] && Echo "* Enter root password of your PC when prompted"
        $ipwndfu -p
        if  [[ $DeviceProc == 7 ]]; then
            Log "Running rmsigchks.py..."
            $rmsigchks
            pwnDFUDevice=$?
            cd ../..
        else
            cd ../..
            Log "Sending iBSS..."
            kDFU iBSS || echo
            pwnDFUDevice=$?
        fi
    elif [[ $pwnDFUTool == "iPwnder32" ]]; then
        $ipwnder32 -p
        pwnDFUDevice=$?
    fi
    [[ $DeviceProc == 7 ]] && pwnD=$($irecovery -q | grep -c "PWND")
    
    if [[ $pwnDFUDevice != 0 && $pwnD != 1 ]]; then
        echo -e "\n${Color_R}[Error] Failed to enter pwnDFU mode. Please run the script again: ./restore.sh Downgrade ${Color_N}"
        echo "${Color_Y}* This step may fail a lot, especially on Linux, and unfortunately there is nothing I can do about the low success rates. ${Color_N}"
        echo "${Color_Y}* The only option is to make sure you are using an Intel or Apple Silicon device, and to try multiple times ${Color_N}"
        Echo "* For more details, read the \"Troubleshooting\" wiki page in GitHub"
        exit 1
    elif [[ $pwnDFUDevice == 0 ]]; then
        Log "Device in pwnDFU mode detected."
    else
        Log "Warning - Failed to detect device in pwnDFU mode."
        Echo "* If the device entered pwnDFU mode successfully, you may continue"
        Echo "* If entering pwnDFU failed, you may have to force restart your device and start over"
    fi
}

Recovery() {
    local RecoveryDFU
    
    if [[ $DeviceState != "Recovery" ]]; then
        Log "Entering recovery mode..."
        $ideviceenterrecovery $UniqueDeviceID >/dev/null
        FindDevice "Recovery"
    fi
    
    Echo "* Get ready to enter DFU mode."
    read -p "$(Input 'Select Y to continue, N to exit recovery (Y/n)')" RecoveryDFU
    if [[ $RecoveryDFU == 'N' || $RecoveryDFU == 'n' ]]; then
        Log "Exiting recovery mode."
        $irecovery -n
        exit 0
    fi
    
    Echo "* Hold POWER and HOME button for 8 seconds."
    for i in {08..01}; do
        echo -n "$i "
        sleep 1
    done
    echo -e "\n$(Echo '* Release POWER and hold HOME button for 8 seconds.')"
    for i in {08..01}; do
        echo -n "$i "
        sleep 1
    done
    echo
    
    FindDevice "DFU" error
    CheckM8
}

RecoveryExit() {
    read -p "$(Input 'Attempt to exit recovery mode? (Y/n)')" Selection
    if [[ $Selection != 'N' && $Selection != 'n' ]]; then
        Log "Exiting recovery mode."
        $irecovery -n
    fi
    exit 0
}

kDFU() {
    local kloader
    local VerDetect=$(echo $ProductVer | cut -c 1)
    
    if [[ ! -e saved/$ProductType/$iBSS.dfu ]]; then
        Log "Downloading iBSS..."
        $partialzip "$(cat $Firmware/$iBSSBuildVer/url)" Firmware/dfu/$iBSS.dfu $iBSS.dfu
        mkdir -p saved/$ProductType 2>/dev/null
        mv $iBSS.dfu saved/$ProductType
    fi
    
    if [[ ! -e saved/$ProductType/$iBSS.dfu ]]; then
        Error "Failed to save iBSS. Please run the script again"
    fi
    
    Log "Patching iBSS..."
    $bspatch saved/$ProductType/$iBSS.dfu tmp/pwnediBSS resources/patches/$iBSS.patch
    
    if [[ $1 == iBSS ]]; then
        cd resources/ipwndfu
        Log "Sending iBSS..."
        $ipwndfu -l ../../tmp/pwnediBSS
        local ret=$?
        cd ../..
        return $ret
    fi
    
    [[ $VerDetect == 1 ]] && kloader="kloader_hgsp"
    [[ $VerDetect == 5 ]] && kloader="kloader5"
    [[ ! $kloader ]] && kloader="kloader"
    
    $iproxy 2222 22 &
    iproxyPID=$!

    Log "Copying stuff to device via SSH..."
    Echo "* Make sure OpenSSH/Dropbear is installed on the device and running!"
    Echo "* Dropbear is only needed for devices on iOS 10"
    Echo "* To make sure that SSH is successful, try these steps:"
    Echo "* Reinstall OpenSSH/Dropbear, reboot and rejailbreak, then reinstall them again"
    echo
    Input "Enter the root password of your iOS device when prompted."
    Echo "* Note that you will be prompted twice. Do not worry that your input is not visible, it is still being entered."
    Echo "* The default password is \"alpine\""
    $SCP -P 2222 resources/tools/$kloader tmp/pwnediBSS root@127.0.0.1:/tmp
    if [[ $? == 0 ]]; then
        $SSH -p 2222 root@127.0.0.1 "chmod +x /tmp/$kloader; /tmp/$kloader /tmp/pwnediBSS" &
    else
        Log "Cannot connect to device via USB SSH."
        Echo "* Please try the steps above to make sure that SSH is successful"
        Echo "* Alternatively, you may use kDFUApp by tihmstar (from my repo, see \"Troubleshooting\" wiki page)"
        Input "Press Enter/Return to continue anyway (or press Ctrl+C to cancel and try again)"
        read -s
        Log "Will try again with Wi-Fi SSH..."
        Echo "* Make sure that the device and your PC/Mac are on the same network!"
        Echo "* You can check for your device's IP Address in: Settings > WiFi/WLAN > tap the 'i' next to your network name"
        read -p "$(Input 'Enter the IP Address of your device:')" IPAddress
        Log "Copying stuff to device via SSH..."
        $SCP resources/tools/$kloader tmp/pwnediBSS root@$IPAddress:/tmp
        if [[ $? == 1 ]]; then
            Error "Cannot connect to device via SSH." \
            "Please try the steps above to make sure that SSH is successful"
        fi
        $SSH root@$IPAddress "chmod +x /tmp/$kloader; /tmp/$kloader /tmp/pwnediBSS" &
    fi
    
    Log "Entering kDFU mode..."
    Echo "* Press POWER or HOME button when the device disconnects and its screen goes black"
    FindDevice "DFU"
}
