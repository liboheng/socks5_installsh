#!/bin/bash
#
#   Dante Socks5 Server AutoInstall
#   -- Owner:       https://www.inet.no/dante
#   -- Provider:    https://sockd.info
#   -- Author:      Lozy (Modified for dynamic IP by ChatGPT)
#

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install"
    exit 1
fi

REQUEST_SERVER="https://raw.github.com/Lozy/danted/master"
SCRIPT_SERVER="https://public.sockd.info"
SYSTEM_RECOGNIZE=""

[ "$1" == "--no-github" ] && REQUEST_SERVER=${SCRIPT_SERVER}

# Detect system
if [ -s "/etc/os-release" ]; then
    os_name=$(sed -n 's/PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release)

    if [[ "${os_name}" =~ (Debian|Ubuntu) ]]; then
        printf "Current OS: %s\n" "${os_name}"
        SYSTEM_RECOGNIZE="debian"

    elif [[ "${os_name}" =~ (CentOS) ]]; then
        printf "Current OS: %s\n" "${os_name}"
        SYSTEM_RECOGNIZE="centos"
    else
        printf "Current OS: %s is not supported.\n" "${os_name}"
    fi
elif [ -s "/etc/issue" ]; then
    if [[ $(grep -Ei 'CentOS' /etc/issue) ]]; then
        printf "Current OS: %s\n" "$(grep -Ei 'CentOS' /etc/issue)"
        SYSTEM_RECOGNIZE="centos"
    else
        printf "+++++++++++++++++++++++\n"
        cat /etc/issue
        printf "+++++++++++++++++++++++\n"
        printf "[Error] Current OS is not supported.\n"
    fi
else
    printf "[Error] (/etc/os-release) OR (/etc/issue) not found!\n"
    printf "[Error] Current OS is not supported.\n"
fi

if [ -n "$SYSTEM_RECOGNIZE" ]; then
    # Install Dante
    wget -qO- --no-check-certificate ${REQUEST_SERVER}/install_${SYSTEM_RECOGNIZE}.sh | \
        bash -s -- $* | tee /tmp/danted_install.log
    
    # Dynamically set the configuration
    echo "Configuring Dante for dynamic IP..."
    
    # Detect the primary IP address
    PRIMARY_IP=$(hostname -I | awk '{print $1}')
    
    # Create or overwrite the configuration file
    cat > /etc/danted.conf <<EOF
logoutput: syslog

internal: ${PRIMARY_IP} port = 1080
external: ${PRIMARY_IP}

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

    echo "Primary IP detected as ${PRIMARY_IP}. Configuration updated."

    # Restart the Dante service
    systemctl restart danted
    systemctl enable danted

    echo "Dante SOCKS5 proxy is installed and configured successfully!"
    echo "Address: ${PRIMARY_IP}:1080"
else
    printf "[Error] Installation terminated\n"
    exit 1
fi

exit 0
