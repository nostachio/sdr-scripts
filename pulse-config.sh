#!/usr/bin/env bash
#check if pulseaudio is installed
#check if nomachine is installed
#detect sources and sinks
#create sinks and loopbacks
#set radio name
RADIO="alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo"
#set sink name
SINK="dummy"
#get sound from rig source
echo "Setting default souce to radio source"
pacmd set-default-source ${RADIO}
#create an empty sink
echo "Create empty sink"
pactl load-module module-null-sink sink_name=${SINK}
#make that sink the default
echo "Making sink default"
pacmd set-default-sink ${SINK}
#mirror radio source to the sink
echo "Mirroring radio source to sink"
pacmd load-module module-loopback source=${RADIO} sink=${SINK}
#mirror nx (aka nomachine) server input to rig
echo "Mirroring NX (aka NoMachine) source to sink"
pactl load-module module-loopback source=nx_voice_out.monitor sink=${RADIO}