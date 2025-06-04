#!/bin/bash

#--------------------------------------
# RetroFlag Pi Case Setup Script
# Installs SafeShutdown.py as a systemd service
#--------------------------------------

LOG_FILE="/var/log/retroflag-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Step 1: Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

# Ensure log file exists with proper permissions
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Step 2: Update package repository
echo "Updating package list..."
apt-get update -y

# Step 3: Disable UART in /boot/config.txt
CONFIG_FILE="/boot/config.txt"
if grep -q "^enable_uart=1" "$CONFIG_FILE"; then
    echo "UART is enabled. Disabling it now..."
    sed -i 's/^enable_uart=1/#enable_uart=1/' "$CONFIG_FILE"
else
    echo "UART is already disabled."
fi

# Step 4: Install gpiozero module
echo "Installing python3-gpiozero..."
apt-get install -y python3-gpiozero

# Step 5: Download Python scripts
INSTALL_DIR="/opt/RetroFlag"
SCRIPT_URL_BASE="https://raw.githubusercontent.com/asheimo/retroflag-picase/master"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "Downloading SafeShutdown.py..."
wget -N --show-progress "$SCRIPT_URL_BASE/SafeShutdown.py"
if [[ $? -ne 0 ]]; then
    echo "Failed to download SafeShutdown.py. Exiting."
    exit 1
fi

echo "Downloading multi_switch.sh..."
wget -N --show-progress "$SCRIPT_URL_BASE/multi_switch.sh"
if [[ $? -ne 0 ]]; then
    echo "Failed to download multi_switch.sh. Exiting."
    exit 1
fi

chmod +x multi_switch.sh

# Step 6: Create and enable systemd service
SERVICE_FILE="/etc/systemd/system/retroflag-safe-shutdown.service"

echo "Creating systemd service..."

cat << EOF > "$SERVICE_FILE"
[Unit]
Description=RetroFlag Safe Shutdown Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/RetroFlag/SafeShutdown.py
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable retroflag-safe-shutdown.service
systemctl start retroflag-safe-shutdown.service

echo "Systemd service 'retroflag-safe-shutdown' created and started."

# Step 7: Enable overlay for proper shutdown via GPIO
if ! grep -q "^dtoverlay=gpio-poweroff,gpiopin=4,active_low=1,input=1" "$CONFIG_FILE"; then
    echo "Adding overlay for proper powercut support..."
    {
        echo ""
        echo "# Overlay setup for proper powercut, needed for Retroflag cases"
        echo "dtoverlay=gpio-poweroff,gpiopin=4,active_low=1,input=1"
    } >> "$CONFIG_FILE"
else
    echo "Overlay already configured in config.txt."
fi

# Step 8: Prompt to reboot
echo
echo "RetroFlag Pi Case installation is complete."

read -rp "Would you like to reboot now? (y/n): " answer
case "${answer,,}" in
    y|yes)
        echo "Rebooting system..."
        sleep 2
        reboot
        ;;
    *)
        echo "Installation complete. Please reboot manually later."
        ;;
esac
