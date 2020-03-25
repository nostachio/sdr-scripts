#!/usr/bin/env bash
#set variables
#set sink name
COMBINED_SINK="dummy"
#set nomachine path (default is /usr/NX)
NXPATH="/usr/NX"

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

#check if NoMachine sources are present (if not, there is not a current NoMachine session and the scripts shouldn't change anything.) or exit with message to reconnect with NoMachine to repopulate its pulseaudio sources and sinks.
pacmd list-sources | grep name: | grep 'nx_voice_out' >/dev/null
if [ $? -ne 0 ]
then
  echo "NoMachine sink not available in Pulseaudio.  This script should only be run while connected via NoMachine.  If you are connected via NoMachine, please check the audio settings and try again."
  echo "You may need to terminate your NoMachine session and then reconnect."
  exit 3
fi

#detect sources and sinks
#from pi
PI_IN_SOURCE=$(pacmd list-sources | grep platform | tr -d '<>' | awk '{print $2}')
# to pi (unused, but may be handy at some point)
#PI_OUT_SINK=$(pacmd list-sinks | grep platform | tr -d '<>' | awk '{print $2}')
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
fi

# Combine pi and radio into one sink
echo "Sending system audio to combined sink."
pacmd load-module module-loopback source=${PI_IN_SOURCE} sink=${COMBINED_SINK}
echo "Sending radio audio input to combined sink."
pacmd load-module module-loopback source=${RADIO_IN} sink=${COMBINED_SINK}
echo "Sending combined sink monitor to remote NoMachine."
pacmd load-module module-loopback source=${COMBINED_SINK}.monitor sink=${NOMACHINE_OUT_SINK}
echo "Mirroring remote NoMachine audio to radio."
pactl load-module module-loopback source=${NOMACHINE_IN} sink=${RADIO_OUT_SINK}