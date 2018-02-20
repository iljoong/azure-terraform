#!/bin/sh

# net.ipv4.ip_forward = 1
cp /etc/sysctl.conf /tmp/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /tmp/sysctl.conf
sudo cp /tmp/sysctl.conf /etc/sysctl.conf

# firewalld
sudo /etc/init.d/networking restart
sudo apt-get install -y firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld
sudo firewall-cmd --state
sudo firewall-cmd --set-default-zone=external
sudo firewall-cmd --reload