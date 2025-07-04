#!/bin/bash
#
# Script for RecalBox to terminate every emulator instance
# Control script to give feedback about state of EmulationStation and
# active EMULATORS
# by cyperghost aka asheimo // 18.03.2019
# Recalbox / Batocera versions // 04.06.2019
# Added sigterm level, added second parameter to activate sigterm during smart_wait function

# Get all childpids from calling process
function getcpid() {
local cpids="$(pgrep -P $1)"
    for cpid in $cpids; do
        pidarray+=($cpid)
        getcpid $cpid
    done
}

# Get a sleep while process is active in background
# if PID is still active then use kill -9 switch
function smart_wait() {
    local PID=$2
    local disablekill9=$1
    local watchdog=0
    sleep 1
    while [[ -e /proc/$PID ]]; do
        sleep 0.25
        ((watchdog++))
        [[ $disablekill9 -eq 1 ]] && [[ watchdog -gt 12 ]] && kill -9 $PID
    done
}

# Emulator currently running?
function check_emurun() {
    local RC_PID="$(pgrep -f -n emulatorlauncher)"
    echo $RC_PID
}

# Emulationstation currently running?
function check_esrun() {
    local ES_PID="$(pgrep -f -n emulationstation)"
    echo $ES_PID
}

# ---- MAINS ----

case ${1,,} in
    --restart)
        /etc/init.d/S31emulationstation stop
        ES_PID=$(check_esrun)
        [[ -z $ES_PID ]] || smart_wait 0 $ES_PID 
        /etc/init.d/S31emulationstation start
    ;;

    --espid)
        # Display ES PID to stdout
        ES_PID=$(check_esrun)
        [[ -n $ES_PID ]] && echo $ES_PID || echo 0
    ;;

    --emupid)
        # This helps to detect emulator is running or not
        RC_PID=$(check_emurun)
        [[ -n $RC_PID ]] && echo $RC_PID || echo 0
    ;;

    --emukill|--shutdown)
        RC_PID=$(check_emurun)
        if [[ -n $RC_PID ]]; then
            getcpid $RC_PID
            for ((z=${#pidarray[*]}-1; z>-1; z--)); do
                kill ${pidarray[z]}
                smart_wait 1 ${pidarray[z]}
            done
            unset pidarray
        fi
        ES_PID=$(check_esrun)
        if [[ "$1" == "--shutdown" && -n $ES_PID ]]; then
            [[ -z $RC_PID ]] || smart_wait 1 $RC_PID && sleep 3
            kill $ES_PID         
            smart_wait 0 $ES_PID
            shutdown -h now
        fi
    ;;

    --kodi)
        ES_PID=$(check_esrun)
        kill $ES_PID
        smart_wait 0 $ES_PID
        /etc/init.d/S31emulationstation stop
        /recalbox/scripts/kodilauncher.sh &
        wait $!
        exitcode=$?
        [[ $exitcode -eq 0 ]] && /etc/init.d/S31emulationstation start
        [[ $exitcode -eq 10 ]] && shutdown -r now
        [[ $exitcode -eq 11 ]] && shutdown -h now
    ;;

    *)
        echo -e "Please parse parameters to this script! \n
                  --restart will RESTART EmulationStation only
                  --kodi will startup KODI Media Center
                  --shutdown will SHUTDOWN whole system
                  --emukill to exit any running EMULATORS
                  --espid to check if EmulationStation is currently active
                  --emupid to check if an Emulator is running"
    ;;

esac
