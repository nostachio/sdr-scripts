#!/usr/bin/env bash
#set variables
#set sink name
COMBINED_SINK="dummy"
#set nomachine path (default is /usr/NX)
NXPATH="/usr/NX"
# how long should the user wait for NoMachine sinks to show up
WAIT_TIME=5
TIMEOUT=60

#silently check if pulseaudio is installed and running or exit with message
pulseaudio --start >/dev/null
if [ $? -ne 0 ]
then
  echo "Pulseaudio is not installed or is having issues starting.  Please fix this and try again."
  exit 1
fi

#silently check if nomachine is installed or exit with message
${NXPATH}/bin/nxserver --version >/dev/null
if [ $? -ne 0 ]
then
  echo "NoMachine is not installed or not installed in the default directory.  Please install it and try again."
  exit 2
fi

# check if we're in a NoMachine session
# may not have the option as an unprivileged user, so we're going to check if a non-local IP is connecting to something with nx in the name
# list connected tcp ports and programs, find foreign ips that are nx-associated that are not from the local machine and count them
# alternate methods could include allowing the specific nxserver --list command or something like that, but that seems complicated to rely on the user doing and still require a password prompt to ensure a first time setup, so let's keep it to functions that don't require elevated privileges.
NON_LOCAL_NX_CONNECTIONS=$(netstat -tnp 2>/dev/null | grep "nxnode" | awk '{print $5}' | grep -v 127.0.0.1 | grep -v '::1:' | wc -l)
if [ ${NON_LOCAL_NX_CONNECTIONS} -eq 0 ]
then
  echo "There don't seem to be any NoMachine sessions.  This script should only be run while connected via NoMachine."
  exit 3
fi

#check if NoMachine sources are present. Wait for them to appear if not.  Timeout after a minute.
echo "Ensuring NoMachine sinks present..."
LOOPTIME=0
while true ; do
  pacmd list-sources | grep name: | grep 'nx_voice_out' >/dev/null
  if [ $? -eq 0 ]
  then
    break
  elif [ ${LOOPTIME} -gt ${TIMEOUT} ]
  then
    echo "NoMachine sinks have not appeared within ${TIMEOUT} seconds."
    echo "Please run the following commands to force their recreation (you will lose your NoMachine connection and have to reconnect):"
    echo "pulseaudio -k"
    echo "sudo /etc/NX/nxserver --restart"
    exit 4
  else
    echo "Waiting for sinks to appear..."
    LOOPTIME+=${WAIT_TIME}
    sleep ${WAIT_TIME}
  fi
done

#detect sources and sinks
#from pi
PI_IN_SOURCE=$(pacmd list-sources | grep platform | tr -d '<>' | awk '{print $2}')
# to pi (unused, but may be handy at some point)
PI_OUT_SINK=$(pacmd list-sinks | grep platform | tr -d '<>' | awk '{print $2}')
# from rig
RADIO_IN=$(pacmd list-sources | grep name: | grep input | tr -d '<>' | awk '{print $2}')
# to rig
RADIO_OUT_SINK=$(pacmd list-sinks | grep name: | grep usb | grep output | tr -d '<>' | awk '{print $2}')
#from remote nomachine
NOMACHINE_IN=$(pacmd list-sources | grep name: | grep nx | grep monitor | tr -d '<>' | awk '{print $2}')
#to remote nomachine
NOMACHINE_OUT_SINK=$(pacmd list-sinks | grep name: |grep nx_voice_out | tr -d '<>' | awk '{print $2}')

#create sinks and loopbacks
#create an empty sink if not already present (if present pulseaudio gives a 53 error)
pacmd list-sinks |grep "name: <${COMBINED_SINK}>"
if [ $? -eq 0 ]
then
  echo "${COMBINED_SINK} sink already exists.  Skipping."
else
  echo "Creating sink ${COMBINED_SINK}"
  pactl load-module module-null-sink sink_name=${COMBINED_SINK}
  echo "Done."
fi

# Combine pi and radio into one sink
echo "Sending system audio to combined sink."
pacmd load-module module-loopback source=${PI_IN_SOURCE} sink=${COMBINED_SINK}
echo "Done."
echo "Sending radio audio input to combined sink."
pacmd load-module module-loopback source=${RADIO_IN} sink=${COMBINED_SINK}
echo "Done."
echo "Sending combined sink to Pi output."
pacmd load-module module-loopback source=source=${COMBINED_SINK}.monitor sink=${PI_OUT_SINK}
echo "Done."
echo "Sending combined sink monitor to remote NoMachine."
pacmd load-module module-loopback source=${COMBINED_SINK}.monitor sink=${NOMACHINE_OUT_SINK}
echo "Done."
echo "Mirroring remote NoMachine audio to radio."
pacmd load-module module-loopback source=${NOMACHINE_IN} sink=${RADIO_OUT_SINK}
echo "Done."
echo "Setting volumes..."
SINK_LIST=$(pacmd list-sinks | grep index: | tr -d '<>*' | awk '{print $2}')
for SINK in ${SINK_LIST}
do
  echo "pacmd set-sink-volume ${SINK} 100"
  pacmd set-sink-volume ${SINK} 100
done
SOURCE_LIST=$(pacmd list-sinks | grep index: | tr -d '<>*' | awk '{print $2}')
for SOURCE in ${SOURCE_LIST}
do
  echo "pacmd set-source-volume ${SOURCE} 100"
  pacmd set-source-volume ${SOURCE} 100
done
SOURCE_OUTPUT_LIST=$(pacmd list-source-outputs | grep index: | tr -d '<>*' | awk '{print $2}')
for SOURCE_OUTPUT in ${SOURCE_OUTPUT_LIST}
do
  echo "pacmd set-source-output-volume ${SOURCE_OUTPUT} 100"
  pacmd set-source-output-volume ${SOURCE_OUTPUT} 100
done
SINK_INPUT_LIST=$(pacmd list-sink-inputs | grep index: | tr -d '<>*' | awk '{print $2}')
for SINK_INPUT in ${SINK_INPUT_LIST}
do
  echo "pacmd set-sink-input-volume ${SINK_INPUT} 100"
  pacmd set-sink-input-volume ${SINK_INPUT} 100
done
echo "Setup and config for using your radio over NoMachine is now complete."
