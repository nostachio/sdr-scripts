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
pacmd set-default-source ${RADIO}
#create an empty sink
pactl load-module module-null-sink sink_name=${SINK}
#make that sink the default
pacmd set-default-sink ${SINK}
#mirror radio source to the sink
pacmd load-module module-loopback source=${RADIO} sink=${SINK}
#mirror nx (aka nomachine) server input to rig
pactl load-module module-loopback source=nx_voice_out.monitor sink=${RADIO}