#!/usr/bin/env bash
pulseaudio --start
lxterminal -e "/home/pi/sdr-scripts/pulse-config.sh"
