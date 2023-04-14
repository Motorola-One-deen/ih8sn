#!/bin/bash

while getopts ":-:" o; do
    case "${OPTARG}" in
        reboot)
            REBOOT=1
            ;;
        use_remount)
            USE_REMOUNT=1
            ;;
    esac
done

adb wait-for-device root
adb wait-for-device shell "mount | grep -q ^tmpfs\ on\ /system && umount -fl /system/{bin,etc} 2>/dev/null"
if [[ "${USE_REMOUNT}" = "1" ]]; then
    adb wait-for-device shell "remount"
elif [[ "$(adb shell stat -f --format %a /system)" = "0" ]]; then
    echo "ERROR: /system has 0 available blocks, consider using --use_remount"
    exit -1
else
    adb wait-for-device shell "stat --format %m /system | xargs mount -o rw,remount"
fi

adb wait-for-device push system/addon.d/60-ih8sn.sh /system/addon.d/
adb wait-for-device push system/bin/ih8sn /system/bin/
adb wait-for-device push system/etc/init/ih8sn.rc /system/etc/init/

MODEL=$(adb shell getprop ro.product.model)
SERIALNO=$(adb shell getprop ro.boot.serialno)
PRODUCT=$(adb shell getprop ro.build.product)

DEFAULT_CONFIG=system/etc/ih8sn.conf
if [[ -f "$DEFAULT_CONFIG.${MODEL}" ]]; then
    CONFIG=$DEFAULT_CONFIG.${MODEL}
elif [[ -f "$DEFAULT_CONFIG.${SERIALNO}" ]]; then
    CONFIG=$DEFAULT_CONFIG.${SERIALNO}
elif [[ -f "$DEFAULT_CONFIG.${PRODUCT}" ]]; then
    CONFIG=$DEFAULT_CONFIG.${PRODUCT}
else
    CONFIG=$DEFAULT_CONFIG
fi

adb wait-for-device push $CONFIG /system/etc/

sdk_version=$(adb shell getprop ro.build.version.sdk)
libkeystore="libkeystore-attestation-application-id.so"

if [[ -f "system/lib64/$sdk_version/$libkeystore" ]] && grep -q '^FORCE_BASIC_ATTESTATION=1$' "$CONFIG"; then
    adb wait-for-device push "system/lib64/$sdk_version/$libkeystore" /system/lib64/
fi

if [[ "${REBOOT}" = "1" ]]; then
    adb wait-for-device reboot
fi

read -p "Press any key to exit..." && exit
