#!/usr/bin/env bash
# Simple new installer
my_dir=$(realpath $(dirname 0))
HOME=$HOME
USER=$USER

export my_dir=$my_dir
export HOME=$HOME
export USER=$USER

branch=newbaseos
if ! which git &> /dev/null;then
  sudo apt update
  sudo apt -y install git
fi
git clone -b ${branch} https://github.com/mcguirepr89/BirdNET-Pi.git ${HOME}/BirdNET-Pi &&

${HOME}/BirdNET-Pi/scripts/install_birdnet.sh
if [ ${PIPESTATUS[0]} -eq 0 ];then
  echo "Installation completed successfully"
  sudo reboot
else
  echo "The installation exited unsuccessfully."
  exit 1
fi
