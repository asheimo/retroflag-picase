#!/bin/bash
echo "Downloading install script .... for BATOCERA"
sleep 2
wget -q -O - https://raw.githubusercontent.com/asheimo/retroflag-picase/master/gpi/batocera_install.sh | bash
