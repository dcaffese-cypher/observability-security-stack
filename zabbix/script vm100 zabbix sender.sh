#!/bin/bash

# Zabbix server address
# Replace ZABBIX_SERVER_IP with your Zabbix server IP or hostname
ZABBIX_SERVER="ZABBIX_SERVER_IP"
# Host name in Zabbix
# Replace HOSTNAME with your server hostname
HOST="HOSTNAME"

# Function to send data to Zabbix
send_to_zabbix() {
    key=$1
    value=$2
    zabbix_sender -z $ZABBIX_SERVER -s $HOST -k $key -o $value
}

# Check firewalld status
firewalld_status=$(systemctl is-active firewalld) # This assigns the current firewalld status to the firewalld_status variable

# Check if firewalld service is active or not
if [ "$firewalld_status" != "active" ]; then
    # If firewalld is NOT active, send 1 to Zabbix
    send_to_zabbix "service.firewalld.status" 1
else
    # If firewalld IS active, send 0 to Zabbix
    send_to_zabbix "service.firewalld.status" 0
fi

# Check systemd-nspawn@data-access service status
nspawn_status=$(systemctl is-active systemd-nspawn@data-access.service)

# If service is NOT active, then send value 1 to Zabbix
if [ "$nspawn_status" != "active" ]; then
    send_to_zabbix "service.nspawn.status" 1
# If service is active, then send value 0 to Zabbix
else
    send_to_zabbix "service.nspawn.status" 0
fi

# Check bond70 IP
# Replace EXPECTED_IP with your expected IP address
if ! /usr/sbin/ip -br a | grep bond70 | grep -q "EXPECTED_IP"; then
    send_to_zabbix "network.bond70.ip" 1
else
    send_to_zabbix "network.bond70.ip" 0
fi

# Check GPFS state on host
# Replace HOSTNAME with your server hostname
if ! /usr/lpp/mmfs/bin/mmgetstate | grep -q "HOSTNAME.*active"; then
    send_to_zabbix "gpfs.HOSTNAME.state" 1
else
    send_to_zabbix "gpfs.HOSTNAME.state" 0
fi

# Check default route
# Replace DEFAULT_GATEWAY_IP and INTERFACE_NAME with your actual values
if ! /usr/sbin/ip route | grep -q "default via DEFAULT_GATEWAY_IP dev INTERFACE_NAME proto static"; then
    send_to_zabbix "network.default.route" 1  # Not active, send value 1
else
    send_to_zabbix "network.default.route" 0  # Active, send value 0
fi

# Check Data Access Service
# Replace EXPECTED_SERVICE_TITLE with your expected service title
if [ "$(curl -SsL --unix-socket /opt/data-access/shared/http_data_access.sock http:/data | jq -r .title)" != "EXPECTED_SERVICE_TITLE" ]; then
    send_to_zabbix "service.data_access.title" 1
else
    send_to_zabbix "service.data_access.title" 0
fi

# Check ib0 interface
if ! /usr/sbin/ip -br a | grep -qE 'ib0\s+UP'; then
    # If ib0 interface is not UP, send status 1
    send_to_zabbix "ib0.interface.status" 1
else
    # If ib0 interface is UP, send status 0
    send_to_zabbix "ib0.interface.status" 0
fi

# Check ib1 interface
if ! /usr/sbin/ip -br a | grep -qE 'ib1\s+UP'; then
    # If ib1 interface is not UP, send status 1
    send_to_zabbix "ib1.interface.status" 1
else
    # If ib1 interface is UP, send status 0
    send_to_zabbix "ib1.interface.status" 0
fi


# Check bond70 status
if ! /usr/sbin/ip -br a | grep -qE 'bond70\s+UP.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/'; then
    send_to_zabbix "network.bond70.status" 1
else
    send_to_zabbix "network.bond70.status" 0
fi

echo "All checks have been performed and alerts sent if needed."
