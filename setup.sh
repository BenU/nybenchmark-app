#!/bin/bash
# setup.sh - Hardens a DigitalOcean Droplet for Rails/Kamal
set -e

echo "🛠️  Starting Server Setup..."

# --- 1. Swap Memory (CRITICAL for $6 Droplets) ---
# Prevents the server from crashing during deployments when RAM is full.
if [ ! -f /swapfile ]; then
  echo "📦 Creating 1GB Swap File..."
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  # Add to fstab so it persists after reboot
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
  echo "✅ Swap active."
else
  echo "✅ Swap already exists."
fi

# --- 2. Timezone ---
# Sets logs to New York time for easier debugging.
echo "🕒 Setting Timezone to NYC..."
timedatectl set-timezone America/New_York

# --- 3. Auto-Updates ---
# Installs security patches automatically every night.
echo "🛡️  Enabling Unattended Upgrades..."
apt-get update
apt-get install -y unattended-upgrades
# Configure it to run daily
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
systemctl restart unattended-upgrades

# --- 4. Firewall (UFW) ---
# Locks all ports except SSH (22), HTTP (80), and HTTPS (443).
echo "🔥 Configuring Firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
# Enable without asking for confirmation
echo "y" | ufw enable
echo "✅ Firewall active."

echo "🎉 Server Setup Complete!"