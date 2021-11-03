#!/bin/bash

SetToolPaths() {
    MPath="./resources/libimobiledevice_"
    if [[ $OSTYPE == "msys" ]]; then
        platform="win"
        MPath+="$platform"
        bspatch="./resources/tools/bspatch_win"
        futurerestore2="./resources/tools/futurerestore2_win"
        idevicerestore="./resources/tools/idevicerestore_win"
        python=/
        Log "Running on platform: windows"
    fi
    git="$(which git)"
    ideviceenterrecovery="$MPath/ideviceenterrecovery"
    ideviceinfo="$MPath/ideviceinfo"
    iproxy="$MPath/iproxy"
    ipsw="./tools/ipsw_$platform"
    irecoverychk="$MPath/irecovery"
    irecovery="$irecoverychk"
    [[ $platform == "linux" ]] && irecovery="sudo LD_LIBRARY_PATH=./resources/lib $irecovery"
    partialzip="./resources/tools/partialzip_$platform"
    SSH="-F ./resources/ssh_config"
    SCP="$(which scp) $SSH"
    SSH="$(which ssh) $SSH"
    tsschecker="./resources/tools/tsschecker_$platform"
}

SaveExternal() {
    local ExternalURL="https://github.com/$1/$2.git"
    local External=$2
    [[ $2 == "iOS-OTA-Downgrader-Keys" ]] && External="firmware"
    cd resources
    if [[ ! -d $External || ! -d $External/.git ]]; then
        Log "Downloading $External..."
        rm -rf $External
        $git clone $ExternalURL $External
    fi
    if [[ ! $(ls $External/*.md) || ! -d $External/.git ]]; then
        rm -rf $External
        Error "Downloading/updating $2 failed. Please run the script again"
    fi
    cd ..
}

SaveFile() {
    curl -L $1 -o $2
    local SHA1=$(shasum $2 | awk '{print $1}')
    if [[ $SHA1 != $3 ]]; then
        Error "Verifying $2 failed. The downloaded file may be corrupted or incomplete. Please run the script again" \
        "SHA1sum mismatch. Expected $3, got $SHA1"
    fi
}

InstallDepends() {
    local libimobiledevice

    mkdir resources/lib tmp 2>/dev/null
    cd resources
    rm -rf ipwndfu lib/*
    cd ../tmp

    Log "Installing dependencies..."
    if [[ $platform == "linux" ]]; then
        Echo "* iOS-OTA-Downgrader will be installing dependencies from your distribution's package manager"
        Echo "* Enter root password of your PC when prompted"
        Input "Press Enter/Return to continue (or press Ctrl+C to cancel)"
        read -s
    fi
    if [[ $ID == "arch" || $ID_LIKE == "arch" || $ID == "artix" ]]; then
        sudo pacman -Syu --noconfirm --needed base-devel bsdiff curl libimobiledevice openssh python2 unzip usbutils zenity

    elif [[ ! -z $UBUNTU_CODENAME && $VERSION_ID == "2"* ]] ||
         [[ $VERSION == "11 (bullseye)" || $PRETTY_NAME == "Debian"*"sid" ]]; then
        [[ ! -z $UBUNTU_CODENAME ]] && sudo add-apt-repository -y universe
        sudo apt update
        sudo apt install -y bsdiff curl git libimobiledevice6 openssh-client python2 unzip usbmuxd usbutils zenity

    elif [[ $ID == "fedora" ]] && (( $VERSION_ID >= 33 )); then
        ln -sf /usr/lib64/libbz2.so.1.* ../resources/lib/libbz2.so.1.0
        sudo dnf install -y bsdiff git libimobiledevice perl-Digest-SHA python2 zenity

    elif [[ $ID == "opensuse-tumbleweed" || $PRETTY_NAME == "openSUSE Leap 15.3" ]]; then
        if [[ $ID == "opensuse-tumbleweed" ]]; then
            libimobiledevice="libimobiledevice-1_0-6"
        else
            libimobiledevice="libimobiledevice6"
            ln -sf /lib64/libreadline.so.7 ../resources/lib/libreadline.so.8
        fi
        sudo zypper -n in bsdiff curl git $libimobiledevice python-base zenity

    elif [[ $platform == "macos" ]]; then
        xcode-select --install
        libimobiledevice=("https://github.com/libimobiledevice-win32/imobiledevice-net/releases/download/v1.3.14/libimobiledevice.1.2.1-r1116-osx-x64.zip" "328e809dea350ae68fb644225bbf8469c0f0634b")
        Echo "* iOS-OTA-Downgrader provides a copy of libimobiledevice and libirecovery by default"
        Echo "* In case that problems occur, try installing them from Homebrew"
        Echo "* The script will detect this automatically and will use the Homebrew versions of the tools"
        Echo "* Install using this command: 'brew install libimobiledevice libirecovery'"

    elif [[ $platform == "win" ]]; then
        pacman -Sy --noconfirm --needed ca-certificates curl openssh unzip zip
        Log "Downloading Windows tools..."
        SaveFile https://github.com/LukeZGD/iOS-OTA-Downgrader-Keys/releases/download/tools/tools_win.zip tools_win.zip 1929c04f6f699f5e423bd9ca7ecc855a9b4f8f7c
        Log "Extracting Windows tools..."
        unzip -oq tools_win.zip -d ../resources/tools
        libimobiledevice=("https://github.com/LukeZGD/iOS-OTA-Downgrader-Keys/releases/download/tools/libimobiledevice_win.zip" "3ed553415cc669b5c467a5f3cd78f692f7149adb")

    else
        Error "Distro not detected/supported by the install script." "See the repo README for supported OS versions/distros"
    fi

    if [[ $platform == "linux" ]]; then
        libimobiledevice=("https://github.com/LukeZGD/iOS-OTA-Downgrader-Keys/releases/download/tools/libimobiledevice_linux.zip" "4344b3ca95d7433d5a49dcacc840d47770ba34c4")
    fi

    if [[ ! -d ../resources/libimobiledevice_$platform && $MPath == "./resources"* ]]; then
        Log "Downloading libimobiledevice..."
        SaveFile ${libimobiledevice[0]} libimobiledevice.zip ${libimobiledevice[1]}
        mkdir ../resources/libimobiledevice_$platform
        Log "Extracting libimobiledevice..."
        unzip -q libimobiledevice.zip -d ../resources/libimobiledevice_$platform
        chmod +x ../resources/libimobiledevice_$platform/*
    elif [[ $MPath != "./resources"* ]]; then
        mkdir ../resources/libimobiledevice_$platform
    fi

    cd ..
    Log "Install script done! Please run the script again to proceed"

    if [[ $platform == "win" ]]; then
        Input "Press Enter/Return to exit."
        read -s
    fi
    exit 0
}
