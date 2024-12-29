#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Check if the public key is set in the environment variable
if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "Error: Public key not found in the SSH_PUBLIC_KEY environment variable."
    echo "Please export the key using the following command:"
    echo 'export SSH_PUBLIC_KEY="your public key"'
    exit 1
fi

# 1. Create the admin user
echo "Creating admin user..."
useradd -m -s /bin/bash admin
if [ $? -ne 0 ]; then
    echo "Error creating admin user. It may already exist."
else
    echo "Admin user successfully created."
fi

# 2. Add the public key to the admin user
echo "Adding the public key to ~/.ssh/authorized_keys for admin..."
mkdir -p /home/admin/.ssh
echo "$SSH_PUBLIC_KEY" > /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys
chmod 700 /home/admin/.ssh
chown -R admin:admin /home/admin/.ssh
echo "Public key successfully added for admin."

# 3. Grant the admin user sudo access without a password
echo "Configuring sudo for admin user..."
echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/admin
echo "Admin user granted sudo access without a password."

# 4. Disable password-based authentication for SSH
echo "Disabling password authentication for SSH..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd
echo "Password authentication disabled, root SSH access disabled."

# 5. Remove the root user's password
echo "Removing the root user's password..."
passwd -l root
echo "Root user's password successfully removed."

# 6. Update and upgrade installed packages
apt update

# 7. Install and configure ufw
echo "Installing and configuring ufw..."
apt install -y ufw
ufw default deny incoming  # Deny all incoming connections by default
ufw default allow outgoing  # Allow all outgoing connections
ufw allow OpenSSH  # Allow only SSH access
ufw --force enable  # Enable ufw
echo "ufw installed and configured: only SSH access is allowed."

# 8. Install and configure Fail2Ban
echo "Installing and configuring Fail2Ban..."
apt install -y fail2ban

# Create a custom Fail2Ban configuration for SSH
cat > /etc/fail2ban/jail.local <<EOL
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 600
findtime = 600
EOL

# Restart Fail2Ban to apply the new configuration
systemctl restart fail2ban
echo "Fail2Ban installed and configured for SSH protection."

# Completion
echo "Server setup complete!"
echo "Please make sure to test your SSH connection with the admin user before closing the current session."

# End of script
