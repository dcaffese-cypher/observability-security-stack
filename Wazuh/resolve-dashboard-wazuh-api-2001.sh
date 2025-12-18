#!/bin/bash

# Stop Wazuh dashboard service
echo "Stopping Wazuh dashboard service..."
sudo systemctl stop wazuh-dashboard

# Remove wazuh-registry.json file
echo "Removing wazuh-registry.json file..."
sudo rm /usr/share/wazuh-dashboard/data/wazuh/config/wazuh-registry.json

# Start Wazuh dashboard service
echo "Starting Wazuh dashboard service..."
sudo systemctl start wazuh-dashboard

# Browser instructions
echo "Please perform the following actions in your browser:"
echo "- Clear browser cache, local storage, etc."
echo "- Try accessing the Wazuh dashboard again"
