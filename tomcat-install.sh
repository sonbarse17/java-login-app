#!/bin/bash

# Set variables
TOMCAT_VERSION="9.0.102"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
TOMCAT_DIR="/opt/tomcat9"
TOMCAT_USER="ec2-user"

echo "Updating system..."
sudo yum update -y

echo "Checking and enabling Amazon Linux extras..."
sudo yum install -y amazon-linux-extras
sudo amazon-linux-extras enable corretto8

echo "Installing Java..."
sudo yum install -y java-1.8.0-amazon-corretto-devel

# Verify Java installation
if ! java -version &>/dev/null; then
    echo "Java installation failed! Exiting..."
    exit 1
fi

echo "Downloading Apache Tomcat $TOMCAT_VERSION..."
cd /opt

# Try curl first, fallback to wget
if ! sudo curl -O $TOMCAT_URL; then
    echo "Curl failed, trying wget..."
    sudo yum install -y wget
    sudo wget $TOMCAT_URL
fi

sudo tar -xvzf apache-tomcat-$TOMCAT_VERSION.tar.gz
sudo mv apache-tomcat-$TOMCAT_VERSION tomcat9
sudo rm -f apache-tomcat-$TOMCAT_VERSION.tar.gz

echo "Setting permissions..."
sudo chown -R $TOMCAT_USER:$TOMCAT_USER $TOMCAT_DIR
sudo chmod +x $TOMCAT_DIR/bin/*.sh

echo "Creating systemd service..."
sudo bash -c "cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER
ExecStart=$TOMCAT_DIR/bin/startup.sh
ExecStop=$TOMCAT_DIR/bin/shutdown.sh
ExecStopPost=/bin/rm -rf /opt/tomcat9/work/Catalina/localhost/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF"

echo "Enabling and starting Tomcat service..."
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat



# Get EC2 Public IP (if running on AWS)
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Installation complete!"
echo "Access Tomcat at: http://$EC2_PUBLIC_IP:8080"
