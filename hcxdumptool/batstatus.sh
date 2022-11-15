#!/bin/sh

BATTERY_CAPACITY_GOOD_BOUNDARY=50
BATTERY_CAPACITY_OK_BOUNDARY=20

capacity=$(cat /sys/class/power_supply/BAT0/capacity)

if [ $capacity -le $BATTERY_CAPACITY_GOOD_BOUNDARY ]
then
    if [ $capacity -le $BATTERY_CAPACITY_OK_BOUNDARY ]
    then
        printf "\e[0;31m" #bad
    else
        printf "\e[1;33m" #ok
    fi
else
    printf "\e[1;32m" #good
fi

printf "Battery level: $capacity\e[0m\n"
