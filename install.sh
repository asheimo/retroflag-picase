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

# Step 5: Install Python scripts from local repo
INSTALL_DIR="/opt/RetroFlag"
REPO_DIR="$(pwd)"

echo "Installing SafeShutdown.py and multi_switch.sh from local clone..."
mkdir -p "$INSTALL_DIR"

for script in SafeShutdown.py multi_switch.sh; do
    if [[ ! -f "$REPO_DIR/$script" ]]; then
        echo "Error: $script not found in $REPO_DIR"
        exit 1
    fi
    cp "$REPO_DIR/$script" "$INSTALL_DIR/"
done

chmod +x "$INSTALL_DIR/multi_switch.sh"

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
read -rp "Would you like to reboot now? [y/n]: " choice
case "$choice" in
    y|Y|yes|YES)
        echo "Rebooting system..."
        sleep 2
        reboot
        ;;
    n|N|no|NO)
        echo "Reboot skipped. Please reboot manually to apply all changes."
        ;;
    *)
        echo "Invalid choice. Reboot skipped."
        ;;
esac
