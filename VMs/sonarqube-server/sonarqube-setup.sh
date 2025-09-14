#!/bin/bash

# ==============================================================================
# SonarQube Server Setup Guide (Community Edition)
# - Installs and configures SonarQube CE, PostgreSQL, Java
# - Tested on Debian/Ubuntu
# ==============================================================================

set -euo pipefail  # Exit on error, unset variable, or failed pipeline

# ------------------------------------------------------------------------------
# Step 1: OS Prerequisites
#   - Set required kernel and user limits for SonarQube
# ------------------------------------------------------------------------------

echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null
sudo sysctl --system

sudo tee /etc/security/limits.d/99-sonarqube.conf >/dev/null <<'EOF'
sonar   soft   nofile  65536
sonar   hard   nofile  65536
sonar   soft   nproc   4096
sonar   hard   nproc   4096
EOF

# ------------------------------------------------------------------------------
# Step 2: Install Java 17 and Tools
#   - SonarQube requires Java 17+
# ------------------------------------------------------------------------------

sudo apt-get update -y
sudo apt-get install -y openjdk-17-jdk unzip curl ca-certificates
java -version

# ------------------------------------------------------------------------------
# Step 3: Install and Configure PostgreSQL
#   - SonarQube uses PostgreSQL as its database backend
# ------------------------------------------------------------------------------

sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create SonarQube database and user
sudo -u postgres psql <<'PSQL'
CREATE ROLE sonar WITH LOGIN ENCRYPTED PASSWORD 'ChangeMe_SonarDB_#2025';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
\q
PSQL

# ------------------------------------------------------------------------------
# Step 4: Create User/Group and Install SonarQube CE
#   - Add dedicated system user/group for SonarQube
#   - Download and extract SonarQube binaries
# ------------------------------------------------------------------------------

sudo groupadd --force sonar
sudo useradd -r -s /bin/false -g sonar -d /opt/sonarqube sonar
id sonar

cd /tmp
curl -fL -o sonarqube-25.9.0.112764.zip \
    https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.9.0.112764.zip

sudo unzip -q sonarqube-25.9.0.112764.zip -d /opt/
sudo rm -rf /opt/sonarqube
sudo mv /opt/sonarqube-25.9.0.112764 /opt/sonarqube

sudo chown -R sonar:sonar /opt/sonarqube
sudo chmod -R 755 /opt/sonarqube

# ------------------------------------------------------------------------------
# Step 5: Configure SonarQube
#   - Set database connection, web server, logging, and JVM options
#   - All configuration is done in /opt/sonarqube/conf/sonar.properties
#   - Key settings:
#       * sonar.jdbc.username/password/url: Database credentials and location
#       * sonar.web.host/port: Web server binding and port
#       * sonar.search.javaOpts: JVM heap and error handling for Elasticsearch
#       * sonar.log.level: Logging verbosity
#       * sonar.path.logs: Log file directory
# ------------------------------------------------------------------------------

sudo tee /opt/sonarqube/conf/sonar.properties >/dev/null <<'EOF'
# Database configuration
sonar.jdbc.username=sonar
sonar.jdbc.password=ChangeMe_SonarDB_#2025
sonar.jdbc.url=jdbc:postgresql://127.0.0.1/sonarqube

# Web server configuration
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Elasticsearch JVM options (search engine)
sonar.search.javaOpts=-Xms1G -Xmx1G -XX:+HeapDumpOnOutOfMemoryError

# Logging configuration
sonar.log.level=INFO
sonar.path.logs=logs
EOF

sudo chown sonar:sonar /opt/sonarqube/conf/sonar.properties

# Create systemd service for SonarQube
sudo tee /etc/systemd/system/sonarqube.service >/dev/null <<'EOF'
[Unit]
Description=SonarQube service (Community Edition)
After=network.target syslog.target
Wants=network.target

[Service]
Type=forking
User=sonar
Group=sonar
WorkingDirectory=/opt/sonarqube
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
Restart=on-failure
LimitNOFILE=65536
LimitNPROC=4096
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube
sudo systemctl status sonarqube

# ------------------------------------------------------------------------------
# Step 6: (Optional) Nginx Reverse Proxy
#   - Use Nginx to proxy SonarQube and enable SSL (optional)
#   - Uncomment this section if you want to enable reverse proxy + SSL
# ------------------------------------------------------------------------------

#: <<'NGINX'
# sudo apt-get install -y nginx
# sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
#
# sudo tee /etc/nginx/sites-available/sonarqube >/dev/null <<'EOF'
# server {
#     listen 80;
#     server_name sonarqube.example.com;
#
#     access_log /var/log/nginx/sonar.access.log;
#     error_log  /var/log/nginx/sonar.error.log;
#
#     location / {
#         proxy_set_header Host              $host;
#         proxy_set_header X-Real-IP         $remote_addr;
#         proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto http;
#         proxy_pass http://127.0.0.1:9000;
#         proxy_read_timeout 300;
#     }
# }
# EOF
#
# sudo ln -sf /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
# sudo nginx -t
# sudo systemctl enable nginx
# sudo systemctl restart nginx
# sudo systemctl status nginx
#
# sudo ufw allow 80/tcp || true
# sudo ufw enable
# sudo ufw status verbose
# NGINX

# ------------------------------------------------------------------------------
# Step 7: Access Information
#   - SonarQube UI is available at http://<server-ip>:9000/
#   - Default login: admin / admin
#   - Change the admin password after first login
# ------------------------------------------------------------------------------
echo "UI:  http://192.168.56.52:9000/"
echo "Default login: admin / admin"
echo "Change password to: Sonarqube!123"
