androidkeygen(){
    KEY_PATH=$1
    KEY_ALIAS=$2

    if [[ "$KEY_PATH" = "-h" || -z $KEY_PATH ]] 
    then
        echo "usage: androidkeygen <path> <alias>"
        return
    fi
      
    keytool -genkey -v -keystore $KEY_PATH -alias $KEY_ALIAS -keyalg RSA -keysize 2048 -validity 10000
}

aidQuery() {
    adb shell content query --uri content://settings/secure --where "name=\'android_id\'"
}

aidChange() {
    adb shell content delete --uri content://settings/secure --where "name=\'android_id\'"
    adb shell content insert --uri content://settings/secure --bind name:s:android_id --bind value:s:$1
}

funtion adb-unlock(){
    echo "Don't forget to start your emulator in writable-system" 
    adb root && adb remount
}

function atcp {
    if [ -z "${1}" ]; then
	IP=$(adb shell ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | sed -e "s/addr://")
    else
	IP=$1
    fi
    adb tcpip 5555 && adb connect $IP":5555"
}

function android_enable_animation {
    adb shell settings put global window_animation_scale 1
    adb shell settings put global transition_animation_scale 1
    adb shell settings put global animator_duration_scale 1
}
