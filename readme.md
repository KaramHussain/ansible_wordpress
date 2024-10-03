# Cloud Deployment with Ansible

This project demonstrates the use of Ansible to automate the deployment and configuration of a small cloud infrastructure on AWS. It involves setting up virtual machines (EC2 instances), installing Docker, and deploying a WordPress container using Ansible playbooks. This comprehensive README file will walk you through each step, showcasing the various configurations and scripts used.

## Table of Contents
- [Project Overview](#project-overview)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
  - [1. Deploying EC2 Instances](#1-deploying-ec2-instances)
  - [2. Installing Ansible on the Control Node](#2-installing-ansible-on-the-control-node)
  - [3. Configuring Ansible Inventory](#3-configuring-ansible-inventory)
  - [4. Running the Docker Playbook](#4-running-the-docker-playbook)
  - [5. Deploying WordPress with MySQL](#5-deploying-wordpress-with-mysql)
- [Dynamic Inventory Configuration](#dynamic-inventory-configuration)
- [Playbook Descriptions](#playbook-descriptions)
  - [docker.yml](#dockeryml)
  - [wordpress.yml](#wordpressyml)
- [Screenshots](#screenshots)
- [Conclusion](#conclusion)

## Project Overview

In this project, we set up a cloud environment on AWS and used Ansible to automate the configuration and deployment process. Ansible allows for simple and efficient automation of repetitive tasks, making cloud management more manageable and scalable. This README provides a comprehensive overview of the project, along with detailed descriptions of the configuration files and playbooks used.

## Prerequisites

- An AWS account with IAM permissions to create EC2 instances.
- A local machine with Ansible installed or an EC2 instance acting as a control node.
- SSH key pair for accessing the EC2 instances.

## Deployment Steps

### 1. Deploying EC2 Instances

Provision three EC2 instances using the AWS console or AWS CLI:
- One instance as the **Control Node** where Ansible will be installed.
- Two instances as **Managed Nodes** that will be controlled by Ansible.

Ensure all instances are in the same VPC for seamless communication. Note down the private IP addresses of the managed nodes.

### 2. Installing Ansible on the Control Node

Create a shell script, `install_ansible.sh`, to install Ansible on the Control Node:

```bash
#!/bin/bash

# Update the package list
sudo apt-get update -y

# Install prerequisite software
sudo apt-get install software-properties-common -y

# Add Ansible's official PPA and install Ansible
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible -y

# Verify the installation
ansible --version


```

This script ensures that Ansible is installed with all required dependencies. Run the script on the Control Node:

```bash
chmod +x install_ansible.sh
./install_ansible.sh
```


### 2. Configuring Ansible Inventory

Create a static inventory file, `inventory`, to define the managed nodes:

```bash
[managed_nodes]
node1 ansible_host=<Managed_Node_1_Private_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/vmkey.pem
node2 ansible_host=<Managed_Node_2_Private_IP> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/vmkey.pem

```

This file specifies the IP addresses of the managed nodes and their corresponding SSH keys, allowing Ansible to access them.

Disable SSH host key checking in the Ansible configuration `(ansible.cfg)` for smoother connectivity:

```bash
[defaults]
host_key_checking = False
```

Testing connectivity using the following command:

```bash
ansible -i inventory -m ping managed_nodes
```

### 4. Running the Docker Playbook

Create a playbook, `docker.yml`, to install Docker on the managed nodes:


```yaml
---
- hosts: managed
  become: true
  tasks:
    - name: Update apt package index
      apt:
        update_cache: yes

    - name: Install Docker
      apt:
        name: docker.io
        state: present

    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: true

    - name: Run Hello World Docker container
      docker_container:
        name: hello-world
        image: hello-world
        state: started
        restart_policy: no

```


This playbook updates the package cache, installs Docker, starts the Docker service, and finally runs a hello-world container to verify the installation.

Execute the playbook:

```bash
ansible-playbook -i inventory docker.yml
```

### 5. Deploying WordPress with MySQL
Create another playbook, `wordpress.yml`, to deploy WordPress and MySQL containers:

```yaml
---
- hosts: managed_nodes
  become: true
  vars_prompt:
    - name: "db_root_password"
      prompt: "Enter MySQL root password"
      private: yes

    - name: "db_name"
      prompt: "Enter WordPress database name"
      private: no

    - name: "db_user"
      prompt: "Enter WordPress database user"
      private: no

    - name: "db_password"
      prompt: "Enter WordPress database password"
      private: yes

  tasks:
    - name: Create a Docker network
      docker_network:
        name: wordpress_network

    - name: Run MySQL container
      docker_container:
        name: mysql
        image: mysql:5.7
        state: started
        restart_policy: always
        env:
          MYSQL_ROOT_PASSWORD: "{{ db_root_password }}"
          MYSQL_DATABASE: "{{ db_name }}"
          MYSQL_USER: "{{ db_user }}"
          MYSQL_PASSWORD: "{{ db_password }}"
        networks:
          - name: wordpress_network

    - name: Run WordPress container
      docker_container:
        name: wordpress
        image: wordpress:latest
        state: started
        restart_policy: always
        ports:
          - "8080:80"
        env:
          WORDPRESS_DB_HOST: mysql
          WORDPRESS_DB_NAME: "{{ db_name }}"
          WORDPRESS_DB_USER: "{{ db_user }}"
          WORDPRESS_DB_PASSWORD: "{{ db_password }}"
        networks:
          - name: wordpress_network
```

This playbook prompts the user for secure database credentials and sets up a Docker network, a MySQL container, and a WordPress container. The two containers communicate within the defined network.

Run the playbook:

```bash
ansible-playbook -i inventory wordpress.yml
```

### 6. Dynamic Inventory Configuration
To automate inventory management, use Ansible’s AWS plugin for dynamic inventory. Update your `aws_ec2.yml` file with the necessary configurations:

```yaml
plugin: aws_ec2
regions:
  - us-east-1  # Specify the region of your instances
filters:
  "tag:ansible": "docker-wordpress"  # Only include instances with this specific tag
keyed_groups:
  - key: tags.ansible
    prefix: docker-wordpress
hostnames:
  - ip-address  # Use public IP address as the hostname
```


### Setting up IAM User with EC2 Describe ACCESS:
Next we will setup an IAM user and attach EC2 Full Access for best practices we will only allow read 
permission of EC2 so ansible can get dynamically information of the EC2 Instances.

After that we will setup ACCESS and SECRET KEYS and then in Ansible Control-Plane we will configure aws CLI if not installed we would install AWS CLI V2.



Run the following command to view the dynamic inventory:

```bash
ansible-inventory -i aws_ec2.yml --graph
```

Now what we need to do is change both playbook and instead of writting managed-nodes to all and then
write the following commands to run playbook.

```bash
ansible-playbook -i aws_ec2.yml -u ubuntu --private-key vmkey.pem docker.yml
ansible-playbook -i aws_ec2.yml -u ubuntu --private-key vmkey.pem wordpress.yml
```


### Playbook Descriptions

**docker.yml**  
The `docker.yml` playbook installs Docker on the managed nodes and runs a test container:

1. **Task 1**: Updates the package list.  
2. **Task 2**: Installs the `docker.io` package.  
3. **Task 3**: Starts and enables the Docker service.  
4. **Task 4**: Runs the `hello-world` container, verifying that Docker is correctly installed.  

**wordpress.yml**  
The `wordpress.yml` playbook deploys a WordPress container connected to a MySQL container, all within a shared Docker network:

1. **Task 1**: Creates a Docker network named `wordpress_network`.  
2. **Task 2**: Runs a MySQL container, using user-provided credentials.  
3. **Task 3**: Deploys WordPress and connects it to the MySQL container.
