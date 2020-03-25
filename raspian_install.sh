#!/usr/bin/env bash
# This script installs and compiles flrig, fldigi, and their dependencies for Raspian Pi.  The script is based off the work of Matt Roberts at http://kk5jy.net/fldigi-build/

#functions
function print_usage() {
  echo "Usage:"
  echo "--no-cleanup do not delete downloaded files after installation"
  echo "--user|-u [user] set up for user.  Default is pi"
}

#defaults
USER="pi"

#process options and flags
while test $# -gt 0 ; do
  case "$1" in
    --no-cleanup)
      NOCLEANUP="true"
      shift
      ;;
    --user|-u)
      shift
      USER="$1"
      shift
      ;;
    *)
      print_usage
      exit 4
      break
      ;;
    esac
  done

#is this environment sane?
#is it Raspian?
grep "Raspian" /etc/os-release ||
  { echo "This script is meant to be run on Raspian Pi only." ; exit 1 ; }
#are we running as root?
[ "$(id -u)" = 0 ] ||
  { echo "Please run this script as root." ; exit 2 ; }
  
#install prerequisites
#one line per package for ease of maintenance
apt-get update
apt-get -y install curl
apt-get -y install libfltk1.3-dev
apt-get -y install libjpeg9-dev
apt-get -y install libxft-dev
apt-get -y install libxinerama-dev
apt-get -y install libxcursor-dev
apt-get -y install libsndfile1-dev
apt-get -y install libsamplerate0-dev
apt-get -y install portaudio19-dev
apt-get -y install libusb-1.0-0-dev
apt-get -y install libpulse-dev
apt-get -y install texinfo

#prep for build
#compiler optimization
export CXXFLAGS='-O2 -march=native -mtune=native'
export CFLAGS='-O2 -march=native -mtune=native'

#install flxmlrpc
[ -f flxmlrpc-0.1.4.tar.gz ] || curl -k -o http://www.w1hkj.com/files/flxmlrpc/flxmlrpc-0.1.4.tar.gz
[ -d flxmlrpc-0.1.4 ] || tar -zxvf flxmlrpc-0.1.4.tar.gz
cd flxmlrpc-0.1.4 || { echo "Cannot enter flxmlrpc directory." ; exit 3 ; }
./configure --prefix=/usr/local --enable-static
make
make install
ldconfig
cd ..

#install hamlib
[ -f hamlib-3.3.tar.gz ] || curl -k -o https://phoenixnap.dl.sourceforge.net/project/hamlib/hamlib/3.3/hamlib-3.3.tar.gz
[ -d hamlib-3.3 ] || tar -zxvf hamlib-3.3.tar.gz
cd hamlib-3.3 || { echo "Cannot enter hamlib directory." ; exit 3 ; }
./configure --prefix=/usr/local --enable-static
make
make install
ldconfig
cd ..

#install flrig
[ -f flrig-1.3.40.tar.gz ] || curl -k -o http://www.w1hkj.com/files/flrig/flrig-1.3.49.tar.gz
[ -d flrig-1.3.40 ] || tar -zxvf flrig-1.3.40.tar.gz
cd flrig-1.3.40 ||  { echo "Cannot enter flrig directory." ; exit 3 ; }
./configure --prefix=/usr/local --enable-static
make
make install
cd ..

#install fldigi
[ -f fldigi-4.1.08.tar.gz ] || curl -k -o http://www.w1hkj.com/files/fldigi/fldigi-4.1.09.tar.gz
[ -d fldigi-4.1.08 ] || tar -zxvf fldigi-4.1.08.tar.gz
cd fldigi-4.1.08 || { echo "Cannot enter fldigi directory." ; exit 3 ; }
./configure --prefix=/usr/local --enable-static
make
make install
cd ..

#add user to group if not already present
groups ${USER} | grep "dialout" || usermod -a -G dialout ${USER}

#install pulseaudio
apt-get install -y pulseaudio pulseaudio-utils pavucontrol

#install nomachine
if [ ! "$(dpkg -l nomachine | grep nomachine)" = 0 ] ;
  then
  echo "Installing NoMachine..."
  PROCESSOR=$(grep Processor /proc/cpuinfo | grep -o "ARMv.")
  MODEL=$(cat /proc/device-tree/model | awk '{print $3}')
  case $MODEL in
    2)
      case $PROCESSOR in
        ARMv6)
          NOMACHINE_URL="https://download.nomachine.com/download/6.9/Raspberry/nomachine_6.9.2_1_armv6hf.deb"
          ;;
        ARMv7)
          NOMACHINE_URL="https://download.nomachine.com/download/6.9/Raspberry/nomachine_6.9.2_3_armhf.deb"
          ;;
        *)
          echo "Combination of Model ${MODEL} and Processor ${PROCESSOR} not recognized.  Please install NoMachine manually."
          ;;
      esac
      ;;
    3)
      case $PROCESSOR in
        ARMv6)
          NOMACHINE_URL="https://download.nomachine.com/download/6.9/Raspberry/nomachine_6.9.2_1_armv6hf.deb"
          ;;
        ARMv7)
          NOMACHINE_URL="https://download.nomachine.com/download/6.9/Raspberry/nomachine_6.9.2_3_armhf.deb"
          ;;
        ARMv8)
          NOMACHINE_URL="https://download.nomachine.com/download/6.9/Raspberry/nomachine_6.9.2_1_arm64.deb"
          ;;
        *)
          echo "Combination of Model ${MODEL} and Processor ${PROCESSOR} not recognized.  Please install NoMachine manually."
          ;;
      esac
      ;;
    4)
      case $PROCESSOR in
        ARMv8)
          NOMACHINE_URL="https://download.nomachine.com/download/6.9/Raspberry/nomachine_6.9.2_3_armhf.deb"
          ;;
        *)
          echo "Combination of Model ${MODEL} and Processor ${PROCESSOR} not recognized.  Please install NoMachine manually."
          ;;
      esac
      ;;
    *)
      echo "Model ${MODEL} does not have a precompiled package.  Please install NoMachine manually."
      ;;
  esac
  [ -f nomachine_6.9.2_1_amd64.deb ] || curl -k -o ${NOMACHINE_URL}
  dpkg -i "$(echo "${NOMACHINE_URL}" | awk -F/ '{print $NF}')"
  echo "Done."
fi

#optional cleanup
if [ ! "${NOCLEANUP}" = "true" ] ; 
then
  echo "Cleaning up files..."
  rm -f flxmlrpc-0.1.4.tar.gz hamlib-3.3.tar.gz flrig-1.3.49.tar.gz fldigi-4.1.09.tar.gz nomachine_6.9.2_1_amd64.deb
  rm -rf fldigi-4.1.08 flrig-1.3.40 hamlib-3.3 flxmlrpc-0.1.4
  echo "Done."
fi
