#!/bin/bash
#
#   Dante Socks5 Server AutoInstall
#   Supports Dynamic Command-Line Parameters and Uninstall Logic
#

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install"
    exit 1
fi

# Default values
PORT=2016
USER="defaultuser"
PASS="defaultpassword"

# Handle uninstall
if [ "$1" == "uninstall" ] || [ "$1" == "--uninstall" ]; then
    echo "Uninstalling Dante SOCKS5 server..."
    # Stop and disable the service
    systemctl stop danted
    systemctl disable danted

    # Remove configuration and binaries
    apt remove --purge dante-server -y
    rm -rf /etc/danted.conf /usr/sbin/sockd

    # Remove firewall rules
    if command -v ufw >/dev/null; then
        ufw delete allow "$PORT"
    elif command -v iptables >/dev/null; then
        iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT
        iptables-save > /etc/iptables.rules
    fi

    echo "Uninstall complete. Dante SOCKS5 server has been removed."
    exit 0
fi

# Parse command-line arguments
while [ "$1" != "" ]; do
    case $1 in
        --port=* )
            PORT="${1#*=}"
            ;;
        --user=* )
            USER="${1#*=}"
            ;;
        --passwd=* )
            PASS="${1#*=}"
            ;;
        * )
            echo "Invalid option: $1"
            echo "Usage: sudo bash $0 --port=<port> --user=<user> --passwd=<password>"
            echo "       sudo bash $0 uninstall"
            echo "       sudo bash $0 --uninstall"
            exit 1
    esac
    shift
done

# Check for blank user or password
if [ -z "$USER" ] || [ -z "$PASS" ]; then
    echo "Error: User or password can't be blank."
    exit 1
fi

echo "Port: $PORT"
echo "User: $USER"
echo "Password: $PASS"

# Check if Dante is already installed
if command -v sockd >/dev/null; then
    echo "[Warning] Dante SOCKS5 server already installed."

    # Check if configuration file exists
    if [ ! -f /etc/danted.conf ]; then
        echo "Error: Configuration file /etc/danted.conf not found."
        echo "Restoring default configuration..."
        cat > /etc/danted.conf <<EOF
logoutput: syslog

internal: 0.0.0.0 port = $PORT
external: 0.0.0.0

method: username

user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}
EOF
        echo "Default configuration restored. Restarting Dante..."
        systemctl restart danted
    fi

    echo "Dante SOCKS5 server is ready."
    exit 0
fi

# Install Dante
REQUEST_SERVER="https://raw.github.com/Lozy/danted/master"
wget -qO- --no-check-certificate ${REQUEST_SERVER}/install_debian.sh | bash

# Configure Dante
CONF_FILE="/etc/danted.conf"
if [ -f "$CONF_FILE" ]; then
    sed -i "s/^internal:.*/internal: 0.0.0.0 port = $PORT/" $CONF_FILE
    sed -i "s/^external:.*/external: 0.0.0.0/" $CONF_FILE

    # Ensure authentication is set to username
    if ! grep -q "method: username" $CONF_FILE; then
        sed -i "s/^method:.*/method: username/" $CONF_FILE
    fi
else
    echo "Error: Configuration file $CONF_FILE not found."
    exit 1
fi

# Add user
if id "$USER" &>/dev/null; then
    echo "User $USER already exists. Updating password."
else
    useradd -m "$USER"
fi
echo "$USER:$PASS" | chpasswd

# Open firewall
echo "Opening firewall for port $PORT..."
if command -v ufw >/dev/null; then
    ufw allow "$PORT"
elif command -v iptables >/dev/null; then
    iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    iptables-save > /etc/iptables.rules
fi

# Enable and restart service
echo "Enabling and restarting Dante service..."
systemctl enable danted
systemctl restart danted

# Output success message
echo "SOCKS5 proxy installed and configured successfully!"
echo "Port: $PORT"
echo "User: $USER"
echo "Password: $PASS"

exit 0
