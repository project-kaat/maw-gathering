#!/bin/sh

source ./mawconfig.sh

BAT_STATUS_COMMAND="watch -n 10 ./batstatus.sh"
TAIL_LOG_1_COMMAND="watch tail /tmp/maw.log"
TAIL_LOG_2_COMMAND="watch tail /tmp/maw2.log"

function print_actions() {

    echo "Available actions:"
    echo -e "\tstart"
    echo -e "\tstop"
    echo -e "\twatch"

}

function print_arguments() {

    echo "Available arguments:"
    echo "-h | --help           : display help"
    echo "-s | --single         : run attack in single-interface mode"
    echo "-d | --dual           : run attack in dual-interface mode"
    echo "-g | --nogps          : run attack without gps"
    echo "-i | --iface          : specify interface for single-interface mode"

}

function start_attack() {

    echo "Using mode: $ATTACK_MODE"
    DATAFOLDER=/mnt/captures/$(date -Iseconds)
    mkdir -p $DATAFOLDER
    
    if [ ! -d $DATAFOLDER ]
    then
        echo "Output directory could not be accessed"
        exit 1
    fi
    
    if [ $ATTACK_MODE == "single" ]
    then
        if [ -z $SINGLE_IFACE ]
        then
            echo "Single attack mode interface unspecified"
            echo "Defaulting to $PRIMARY_INTERFACE"
            SINGLE_IFACE="$PRIMARY_INTERFACE"
        fi
        if [ $USE_GPS -eq 1 ]
        then

            reinit_gpsd

            hcxdumptool --use_gpsd -i $SINGLE_IFACE --enable_status=31 -o $DATAFOLDER/allchannels.pcapng > /tmp/maw.log &
        else
            hcxdumptool -i $SINGLE_IFACE --enable_status=31 -o $DATAFOLDER/allchannels.pcapng > /tmp/maw.log &
        fi
    elif [ $MODE == "dual" ]
    then
        if [ $USE_GPS -eq 1 ]
        then

            reinit_gpsd

            hcxdumptool --use_gpsd -i $PRIMARY_INTERFACE -c 1,2,3,4,5,6,7 --enable_status=31 -o $DATAFOLDER/c1to7.pcapng > /tmp/maw.log &
        else

            hcxdumptool -i $PRIMARY_INTERFACE -c 1,2,3,4,5,6,7 --enable_status=31 -o $DATAFOLDER/c1to7.pcapng > /tmp/maw.log &
        fi
        hcxdumptool -i $SECONDARY_INTERFACE -c 8,9,10,11,12,13 --enable_status=31 -o $DATAFOLDER/c8to13.pcapng > /tmp/maw2.log &
    else
        echo "Invalid attack mode specified : $ATTACK_MODE"
        print_modes
        exit 1
    fi
}

function stop_attack() {

    killall hcxdumptool
}

function check_attack() {

    psval=$(ps | grep hcxdumptool | grep -v grep | wc -l)
    if [ -z $psval ]
    then
        return 0
    else
        return $psval
    fi
}

function check_gpsd() {

    psval=$(ps | grep gpsd | grep -v grep | wc -l)
    if [ -z $psval ]
    then
        return 0
    else
        return 1
    fi

}

function start_gpsd() {

    gpsd "tcp://${GPSD_SERVER_ADDRESS}:6000"
    return $?
}


function reinit_gpsd() {
    check_gpsd
    if [ $? -eq 1 ]
    then
        stop_gpsd
    fi
    
    start_gpsd
    
    if [ $? -ne 0 ]
    then
        echo "Failed to start gpsd"
        exit 1
    fi

}

function stop_gpsd() {
    killall gpsd
}

function watch_attack() {

    clear
    if [ $1 -eq 1 ]
    then
        tmux new-session ${TAIL_LOG_1_COMMAND} \; split-window -v -l 1 ${BAT_STATUS_COMMAND}
    elif [ $1 -eq 2 ]
    then
        tmux new-session ${TAIL_LOG_1_COMMAND} \; split-window -v ${TAIL_LOG_2_COMMAND} \; split-window -v -l 1 ${BAT_STATUS_COMMAND}
    fi

}

ATTACK_MODE=""
USE_GPS=1
SINGLE_IFACE=""
ACTION=""

while [ "$#" -gt 0 ]
do

    case $1 in

        -h|--help)
            echo "Usage: $0 <arguments> <action>"
            print_arguments
            print_actions
            exit 0
            ;;
        -s|--single)
            ATTACK_MODE="single"
            ;;
        -d|--dual)
            ATTACK_MODE="dual"
            ;;
        -g|--nogps)
            USE_GPS=0
            ;;

        -i|--iface)
            SINGLE_IFACE=$2
            ;;
        *)
            ACTION=$1
    esac
    shift
done

if [ -z $ACTION ]
then
    echo "Please specify action"
    print_actions
    exit 1

elif [ $ACTION == "start" ]
then
    if [ -z $ATTACK_MODE ]
    then
        echo "Attack mode unspecified. Assuming single-interface"
        ATTACK_MODE="single"
    fi
    start_attack
elif [ $ACTION == "stop" ]
then
    check_attack
    if [ $? -eq 0 ]
    then
        echo "No attack to stop"
        exit 
    fi
    stop_attack
elif [ $ACTION == "watch" ]
then 
    
    check_attack
    nattacks=$?
    if [ $nattacks -eq 0 ]
    then
        echo "No attack is running"
        exit 1
    fi
    watch_attack $nattacks
else
    echo "Invalid action : $ACTION"
    print_actions
    exit 1
fi
