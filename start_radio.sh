#!/usr/bin/env bash
flrig &
# pi 4 needs a few seconds for flrig to start before fldigi can find its server
sleep 5
fldigi &