#!/bin/bash
echo "Downloading install script ...."
sleep 2
wget -q -O - https://raw.githubusercontent.com/asheimo/retroflag-picase/master/gpi/install.sh | bash
