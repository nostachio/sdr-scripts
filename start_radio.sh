#!/usr/bin/env bash
pulseaudio --start
sleep 5
flrig &
# pi 4 needs a few seconds for flrig to start before fldigi can find its server
sleep 5
fldigi &
wstjx &