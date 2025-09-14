#!/bin/bash

# ------------------------------------------------------------------------------
# Deployment Server Setup & Configuration Guide (Ubuntu/Debian)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Step 1: Install Docker and Docker Compose
#   - Install Docker using official convenience script
#   - Add current user to 'docker' group
#   - Enable and start Docker + containerd services
#   - Install Docker Compose plugin
#   - Verify Docker installation
# ------------------------------------------------------------------------------

sudo apt update
curl -fsSL https://get.docker.sh -o get-docker.sh
sudo sh get-docker.sh

sudo groupadd docker || true
sudo usermod -aG docker "$USER"

sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo systemctl enable containerd.service
sudo systemctl start containerd.service

sudo apt-get update -y
sudo apt-get install -y docker-compose-plugin

docker --version
docker compose version

# ------------------------------------------------------------------------------
# Step 2: Generate SSH Key for Jenkins Connection
#   - Create SSH key pair
#   - Copy public key to clipboard
#   - Add this key in Jenkins (Manage Jenkins → Credentials → SSH)
# ------------------------------------------------------------------------------

ssh-keygen -t rsa -b 4096 -C "deploy-server"
cat ~/.ssh/id_rsa.pub | xclip -selection clipboard

# ------------------------------------------------------------------------------
# Step 3: Install GitLab Runner
#   - Download GitLab Runner binary
#   - Give execute permission
#   - Create a GitLab Runner user
#   - Install and run GitLab Runner as a service
#   - Register the runner with GitLab instance (provide URL + token)
# ------------------------------------------------------------------------------

# Download the binary for your system
sudo curl -L --output /usr/local/bin/gitlab-runner \
    https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

# Give it permission to execute
sudo chmod +x /usr/local/bin/gitlab-runner

# Create a GitLab Runner user
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

# Install and run as a service
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
sudo gitlab-runner start

# Register the runner (you will need your GitLab instance URL and registration token)
# sudo gitlab-runner register
# Follow the prompts to complete the registration
gitlab-runner register --url https://gitlab.com --token <Your-Registration-Token>
gitlab-runner run

# ------------------------------------------------------------------------------
# Step 4: Configure GitLab Runner with Docker Access
#   - Add gitlab-runner user to docker group
#   - Restart GitLab Runner service
#   - Reboot system if required
# ------------------------------------------------------------------------------

sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
sudo reboot

sudo gitlab-runner start
gitlab-runner run
# ------------------------------------------------------------------------------