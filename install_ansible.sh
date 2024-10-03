#!/bin/bash

# This script installs Ansible on Ubuntu

# Function to display error message and exit
function error_exit {
    echo "$1" 1>&2
    exit 1
}

# Update the package list
echo "Updating the package list..."
sudo apt-get update -y || error_exit "Failed to update package list."

# Install prerequisite software
echo "Installing prerequisite software..."
sudo apt-get install -y software-properties-common || error_exit "Failed to install prerequisite software."

# Add Ansible's official PPA (Personal Package Archive)
echo "Adding Ansible's official PPA..."
sudo add-apt-repository --yes --update ppa:ansible/ansible || error_exit "Failed to add Ansible's PPA."

# Install Ansible
echo "Installing Ansible..."
sudo apt-get install -y ansible || error_exit "Failed to install Ansible."

# Verify Ansible installation
echo "Verifying Ansible installation..."
ansible --version || error_exit "Ansible installation verification failed."

echo "Ansible has been successfully installed!"
