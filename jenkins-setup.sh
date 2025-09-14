#!/bin/bash

# ------------------------------------------------------------------------------
# Jenkins LTS Installation & Configuration Guide (Ubuntu/Debian)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Step 1: Install Java 21 (Required for Jenkins LTS >= 2.426.1)
#   - Update package lists
#   - Install OpenJDK 21, CA certificates, curl, and gnupg
# ------------------------------------------------------------------------------

sudo apt-get update -y
sudo apt-get install -y openjdk-21-jdk ca-certificates curl gnupg

# ------------------------------------------------------------------------------
# Step 2: Add Jenkins Repository and Import Signing Key
#   - Create keyring directory for Jenkins
#   - Download Jenkins repository signing key
#   - Add Jenkins repository to apt sources
# ------------------------------------------------------------------------------

sudo mkdir -p /usr/share/keyrings
sudo chmod 755 /usr/share/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
    sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

# ------------------------------------------------------------------------------
# Step 3: Install Jenkins LTS
#   - Update package lists
#   - Install Jenkins package
# ------------------------------------------------------------------------------

sudo apt-get update -y
sudo apt-get install -y jenkins

# ------------------------------------------------------------------------------
# Step 4: Enable and Start Jenkins Service
#   - Reload systemd manager configuration
#   - Start Jenkins service
#   - Enable Jenkins to start on boot
#   - Display Jenkins service status
# ------------------------------------------------------------------------------

sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo systemctl status jenkins

# ------------------------------------------------------------------------------
# Step 5: Retrieve Jenkins Initial Admin Password
#   - Attempt to access Jenkins web interface (optional)
#   - List Jenkins home directory contents
#   - Display initial admin password for first login
# ------------------------------------------------------------------------------

curl http://192.168.56.50:8080 || true
ls -l /var/lib/jenkins/
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# ------------------------------------------------------------------------------
# Step 6: Install Docker and Docker Compose
#   - Install Docker using official convenience script
#   - Add current user and Jenkins user to 'docker' group
#   - Start and enable Docker and containerd services
#   - Install Docker Compose plugin
#   - Set permissions for /opt/docker directory
#   - Restart Docker and Jenkins services to apply group changes
# ------------------------------------------------------------------------------

sudo apt update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo groupadd docker || true
sudo usermod -aG docker "$USER"

sudo systemctl start containerd.service
sudo systemctl enable docker.service
sudo systemctl start containerd.service
sudo systemctl enable containerd.service

sudo apt-get update -y
sudo apt-get install -y docker-compose-plugin

sudo chown -R root:jenkins /opt/docker
sudo usermod -aG docker jenkins
sudo systemctl restart docker
sudo systemctl restart jenkins
# Generate SSH Key for Jenkins Server
ssh-keygen -t rsa -b 4096 -C "jenkins-server" 
# copy public key to clipboard:
cat ~/.ssh/id_rsa.pub | xclip -selection clipboard


# ------------------------------------------------------------------------------
# Step 7: Install Go (golang-go) for Build Environments
#   - Install Go programming language
# ------------------------------------------------------------------------------

sudo apt update 
sudo apt install -y golang-go

# ------------------------------------------------------------------------------
# Step 8: Jenkins Plugins (Manual via UI)
#   - Recommended plugins: Go, SonarQube Scanner, Pipeline, Docker, git, GitHub, GitHub Branch Source
#   - Navigate to: Manage Jenkins → Plugins → Install without restart
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Step 9: Jenkins Tools (Manual via UI)
#   - Add Go Tool (e.g., name: go1.22.0, path: /usr/local/go)
#   - Add SonarQube Scanner Tool (e.g., name: SonarQubeServer, version: 7.2.0.5079)
#   - Navigate to: Manage Jenkins → Global Tool Configuration
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Step 10: Add SonarQube Token Credential (Manual via UI)
#   - Go to: Manage Jenkins → Credentials → Global → Add Credentials
#   - Kind: Secret text
#   - Secret: <your-sonarqube-token>
#   - ID: sonar-token (used in pipeline via credentials('sonar-token'))
#   - Description: SonarQube authentication token
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Step 11: Configure SonarQube Server in Jenkins (Manual via UI)
#   - Go to: Manage Jenkins → System → SonarQube servers → Add SonarQube
#   - Name: SonarQube-Server (used in pipeline with withSonarQubeEnv('SonarQube-Server'))
#   - Server URL: http(s)://<your-sonarqube-host>
#   - Server authentication token: Select Jenkins credential ID (see step 10)
#   - Enable injection of SonarQube server configuration as build environment
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Step 12: (Optional) Install SonarScanner CLI
#   - Download sonar-scanner-cli-7.2.0.5079
#   - Unzip to ~/.sonar
#   - Add to PATH
# ------------------------------------------------------------------------------