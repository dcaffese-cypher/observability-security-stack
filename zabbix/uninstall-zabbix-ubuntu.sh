#!/bin/bash

# Stop Zabbix agent service
sudo systemctl stop zabbix-agent

# Uninstall Zabbix agent
sudo apt-get remove --purge -y zabbix-agent

# Remove configuration files and logs
sudo rm -rf /etc/zabbix
sudo rm -rf /var/log/zabbix

# Update package list
sudo apt-get update
