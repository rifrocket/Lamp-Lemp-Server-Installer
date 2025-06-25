#!/bin/bash

# LAMP/LEMP Stack Installer
# Version: 2.0.0
# Author: RifRocket
# Description: Robust installer for LAMP/LEMP stacks with advanced security and error handling
# License: MIT
# Single-file version - all dependencies embedded

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Disable exit on error when being sourced for testing
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    set +e
fi

# ============================================================================
# EMBEDDED CONFIGURATION (can be overridden by external config.conf)
# ============================================================================

# Default Configuration Values
DEFAULT_PHP_VERSION="8.2"
DEFAULT_MYSQL_PASSWORD=""
MYSQL_DATABASE_NAME="default_db"
ENABLE_FIREWALL=true
SECURE_MYSQL_INSTALLATION=true
DISABLE_ROOT_LOGIN=false
INSTALL_COMPOSER=false
INSTALL_SUPERVISOR=false
CREATE_BACKUP=true
BACKUP_RETENTION_DAYS=7
PHP_MEMORY_LIMIT="256M"
PHP_MAX_EXECUTION_TIME=30
PHP_UPLOAD_MAX_FILESIZE="64M"
ENABLE_GZIP=true
ENABLE_SSL_REDIRECT=false
DEFAULT_DOCUMENT_ROOT="/var/www/html"
ADMIN_EMAIL=""
SEND_COMPLETION_EMAIL=false

# Load external configuration if exists (optional)
if [ -f "config.conf" ]; then
    source config.conf
fi

# ============================================================================
# EMBEDDED UTILITY FUNCTIONS
# ============================================================================

# Check if a service is running
is_service_running() {
  local service=$1
  systemctl is-active --quiet "$service"
}

# Check if a package is installed
is_package_installed() {
  local package=$1
  dpkg -l | grep -q "^ii.*$package"
}

# Safe service restart with validation
safe_service_restart() {
  local service=$1
  local max_attempts=3
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    styled_echo info "Attempting to restart $service (attempt $attempt/$max_attempts)"
    
    if systemctl restart "$service"; then
      if systemctl is-active --quiet "$service"; then
        styled_echo success "$service restarted successfully"
        return 0
      fi
    fi
    
    attempt=$((attempt + 1))
    sleep 2
  done
  
  log_error "Failed to restart $service after $max_attempts attempts"
  return 1
}

# Generate secure password
generate_secure_password() {
  local length=${1:-16}
  openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Test network connectivity
test_connectivity() {
  local urls=("google.com" "github.com" "packages.sury.org")
  
  for url in "${urls[@]}"; do
    if ping -c 1 -W 5 "$url" >/dev/null 2>&1; then
      return 0
    fi
  done
  
  styled_echo warning "Network connectivity issues detected"
  return 1
}

# Cleanup temporary files
cleanup_temp_files() {
  styled_echo info "Cleaning up temporary files..."
  rm -f /tmp/composer-setup.php
  rm -f /tmp/phpMyAdmin-*.tar.gz
  apt autoremove -y >/dev/null 2>&1
  apt autoclean >/dev/null 2>&1
}

# Configure firewall rules
configure_firewall() {
  if [ "$ENABLE_FIREWALL" = true ]; then
    styled_echo info "Configuring firewall..."
    
    # Install UFW if not present
    if ! command -v ufw >/dev/null 2>&1; then
      apt install -y ufw
    fi
    
    # Configure basic rules
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    styled_echo success "Firewall configured successfully"
  fi
}

# Performance optimization for PHP
optimize_php() {
  local php_version=$1
  local ini_file="/etc/php/$php_version/apache2/php.ini"
  
  if [ -f "$ini_file" ]; then
    styled_echo info "Optimizing PHP configuration..."
    
    # Backup original
    cp "$ini_file" "$ini_file.backup"
    
    # Apply optimizations
    sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" "$ini_file"
    sed -i "s/max_execution_time = .*/max_execution_time = $PHP_MAX_EXECUTION_TIME/" "$ini_file"
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = $PHP_UPLOAD_MAX_FILESIZE/" "$ini_file"
    sed -i "s/post_max_size = .*/post_max_size = $PHP_UPLOAD_MAX_FILESIZE/" "$ini_file"
    
    styled_echo success "PHP optimized successfully"
  fi
}

# Send notification email (if configured)
send_notification() {
  local subject="$1"
  local message="$2"
  
  if [ "$SEND_COMPLETION_EMAIL" = true ] && [ -n "$ADMIN_EMAIL" ]; then
    if command -v mail >/dev/null 2>&1; then
      echo "$message" | mail -s "$subject" "$ADMIN_EMAIL"
    fi
  fi
}

# ============================================================================
# MAIN SCRIPT CONTINUES...
# ============================================================================

# Default values - SECURITY WARNING: Change default password!
mysql_pass="$(openssl rand -base64 12)_Aa1!"  # Generate secure random password
php_version="8.2"  # Default PHP version
install_lamp=true
install_lemp=false
install_composer=false    # Set Composer install default to false
install_supervisor=false # Set Supervisor install default to false
remove_web_server=false

# Backup directory for configuration files
BACKUP_DIR="/tmp/lamp_lemp_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup function
create_backup() {
  styled_echo info "Creating backup of existing configurations..."
  mkdir -p "$BACKUP_DIR"
  
  # Backup existing configurations if they exist
  [ -d /etc/apache2 ] && cp -r /etc/apache2 "$BACKUP_DIR/apache2_backup" 2>/dev/null
  [ -d /etc/nginx ] && cp -r /etc/nginx "$BACKUP_DIR/nginx_backup" 2>/dev/null
  [ -d /etc/mysql ] && cp -r /etc/mysql "$BACKUP_DIR/mysql_backup" 2>/dev/null
  [ -d /etc/php ] && cp -r /etc/php "$BACKUP_DIR/php_backup" 2>/dev/null
  
  styled_echo success "Backup created at: $BACKUP_DIR"
}

# Rollback function in case of failure
rollback_installation() {
  styled_echo warning "Rolling back installation due to error..."
  if [ -d "$BACKUP_DIR" ]; then
    # Restore backups if they exist
    [ -d "$BACKUP_DIR/apache2_backup" ] && cp -r "$BACKUP_DIR/apache2_backup" /etc/apache2 2>/dev/null
    [ -d "$BACKUP_DIR/nginx_backup" ] && cp -r "$BACKUP_DIR/nginx_backup" /etc/nginx 2>/dev/null
    [ -d "$BACKUP_DIR/mysql_backup" ] && cp -r "$BACKUP_DIR/mysql_backup" /etc/mysql 2>/dev/null
    [ -d "$BACKUP_DIR/php_backup" ] && cp -r "$BACKUP_DIR/php_backup" /etc/php 2>/dev/null
    styled_echo info "Backup restored from: $BACKUP_DIR"
  fi
}

# Improved error handling with logging
log_error() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] ERROR: $message" >> /var/log/lamp_lemp_installer.log
  styled_echo error "$message"
}

# Define a function to display styled messages
styled_echo() {
  local type="$1"
  local message="$2"
  case "$type" in
    info)
      echo -e "\e[34m[INFO] $message\e[0m"  # Blue color
      ;;
    success)
      echo -e "\e[32m[SUCCESS] $message\e[0m"  # Green color
      ;;
    warning)
      echo -e "\e[33m[WARNING] $message\e[0m"  # Yellow color
      ;;
    error)
      echo -e "\e[31m[ERROR] $message\e[0m"    # Red color
      ;;
    *)
      echo "$message"
      ;;
  esac
}

# Get server IP
get_server_ip() {
  hostname -I | awk '{print $1}' || echo "localhost"
}

# Display completion message
DisplayCompletionMessage() {
  clear
cat << "EOF"
██████╗ ██╗███████╗██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗
██╔══██╗██║██╔════╝██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝
██████╔╝██║█████╗  ██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   
██╔══██╗██║██╔══╝  ██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   
██║  ██║██║██║     ██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   
╚═╝  ╚═╝╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝ 

EOF

  ip=$(get_server_ip)
  local stack=$1
  echo "+-------------------------------------------+"
  echo "|    $stack Stack Installed Successfully    "
  echo "+-------------------------------------------+"
  echo "| Web Site: http://$ip/      "               
  if $install_php_flag; then
    echo "| PhpMyAdmin: http://$ip/phpmyadmin   "      
  fi
  if $install_mysql_flag; then
    echo "| MySQL User: root || Pass: $mysql_pass"      
  fi
  echo "+-------------------------------------------+"
}

# Check OS compatibility and root privileges
check_requirements() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Script must be run with sudo or as root"
    exit 1
  fi

  # Check if running in a container or virtual environment
  if [ -f /.dockerenv ] || [ -n "${container}" ]; then
    styled_echo warning "Running in containerized environment - some features may not work properly"
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    os_name=$ID
    os_version=$VERSION_ID
  else
    log_error "Cannot determine OS. /etc/os-release not found"
    exit 1
  fi

  if [[ "$os_name" != "ubuntu" && "$os_name" != "debian" ]]; then
    log_error "This script only supports Ubuntu and Debian distributions"
    exit 1
  fi

  # For Ubuntu, ensure version is 20 or higher
  if [[ "$os_name" == "ubuntu" ]]; then
    if (( $(echo "$os_version < 20" | bc -l) )); then
      log_error "This script requires Ubuntu 20.04 or higher"
      exit 1
    fi
  fi

  # Check available disk space (minimum 2GB)
  available_space=$(df / | awk 'NR==2 {print $4}')
  if [ "$available_space" -lt 2097152 ]; then  # 2GB in KB
    styled_echo warning "Less than 2GB free space available. Installation may fail."
  fi

  # Check memory (minimum 1GB)
  total_memory=$(free -m | awk 'NR==2{print $2}')
  if [ "$total_memory" -lt 1024 ]; then
    styled_echo warning "Less than 1GB RAM available. Performance may be affected."
  fi
}

# Check if Apache, MySQL, and PHP are installed
is_lamp_installed() {
  apache_status=$(systemctl is-active apache2)
  mysql_status=$(systemctl is-active mysql)
  php_installed=$(php --version 2>/dev/null)

  if [[ "$apache_status" == "active" && "$mysql_status" == "active" && -n "$php_installed" ]]; then
    return 0  # LAMP is installed
  else
    return 1  # LAMP is not installed
  fi
}

is_lemp_installed() {
  nginx_status=$(systemctl is-active nginx)
  mysql_status=$(systemctl is-active mysql)
  php_installed=$(php --version 2>/dev/null)

  if [[ "$nginx_status" == "active" && "$mysql_status" == "active" && -n "$php_installed" ]]; then
    return 0  # LEMP is installed
  else
    return 1  # LEMP is not installed
  fi
}

# Remove existing Apache, Nginx, MySQL, PHP, and phpMyAdmin
remove_existing_installation() {
  styled_echo info "Removing Existing Web Server Installation"

  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $mysql_pass" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $mysql_pass" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $mysql_pass" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

  # Stop and purge Apache if installed
  if command -v apache2 > /dev/null 2>&1; then
    styled_echo info "Removing Apache"
    systemctl stop apache2
    DEBIAN_FRONTEND=noninteractive apt -y purge apache2 apache2-utils apache2-bin apache2.2-common
    apt -y autoremove
    apt -y autoclean
    rm -rf /etc/apache2
    rm -rf /var/log/apache2
    rm -rf /etc/apache2/conf-enabled/phpmyadmin.conf
    rm -rf /etc/apache2/conf-available/phpmyadmin.conf
    styled_echo success "Apache Removed Successfully."
  fi

  # Stop and purge Nginx if installed
  if command -v nginx > /dev/null 2>&1; then
    styled_echo info "Removing Nginx"
    systemctl stop nginx 
    DEBIAN_FRONTEND=noninteractive apt -y purge nginx nginx-common nginx-full
    apt -y autoremove
    apt -y autoclean
    rm -rf /etc/nginx /var/www/html /var/log/nginx
    rm -rf /etc/nginx/sites-enabled/phpmyadmin.conf
    rm -rf /etc/nginx/sites-available/phpmyadmin.conf
    styled_echo success "Nginx Removed Successfully."
  fi

  # Stop and purge MySQL if installed
  if command -v mysql > /dev/null 2>&1; then
    styled_echo info "Removing MySQL"
    systemctl stop mysql
    killall -9 mysqld  # Forcefully kill any remaining MySQL processes
    DEBIAN_FRONTEND=noninteractive apt -y purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
    apt -y autoremove
    apt -y autoclean
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/run/mysqld
    update-rc.d -f mysql remove
    systemctl disable mysql
    rm -rf /etc/systemd/system/mysql.service
    styled_echo success "MySQL Removed Successfully."
  fi

  # Stop and purge PHP-FPM if installed
  if command -v php-fpm > /dev/null 2>&1; then
    styled_echo info "Removing PHP-FPM"
    systemctl stop php-fpm
    DEBIAN_FRONTEND=noninteractive apt -y purge php-fpm
  fi

  styled_echo info "Removing PHP"
  DEBIAN_FRONTEND=noninteractive apt -y purge 'php*'    
  apt -y autoremove
  apt -y autoclean
  rm -rf /etc/php /var/lib/php /var/log/php

  # Purge PHP and phpMyAdmin
  styled_echo info "Removing phpMyAdmin"
  apt --fix-broken install
  DEBIAN_FRONTEND=noninteractive apt -y purge phpmyadmin javascript-common libjs-popper.js libjs-bootstrap5
  rm -rf /etc/phpmyadmin /var/lib/phpmyadmin /usr/share/phpmyadmin
  apt -y autoremove
  apt -y autoclean
  dpkg --remove --force-remove-reinstreq javascript-common libjs-popper.js libjs-bootstrap5 phpmyadmin

  # Check if Supervisor is installed
  if command -v supervisorctl > /dev/null 2>&1; then
    read -p "Supervisor is installed. Do you want to remove it? [y/N]: " remove_supervisor_input
    if [[ "$remove_supervisor_input" =~ ^[Yy]$ ]]; then
      styled_echo info "Removing Supervisor"
      systemctl stop supervisor
      DEBIAN_FRONTEND=noninteractive apt -y purge supervisor
      apt -y autoremove
      apt -y autoclean
      systemctl disable supervisor
      styled_echo success "Supervisor Removed Successfully"
    else
      styled_echo info "Supervisor was not removed."
    fi
  fi

  # Remove Composer if installed
  if command -v composer > /dev/null 2>&1; then
    styled_echo info "Removing Composer"
    rm /usr/local/bin/composer
    styled_echo success "Composer Removed Successfully"
  fi

  # Clean up
  styled_echo info "Cleaning up"
  apt -y autoremove
  apt -y autoclean
  apt clean
  unset DEBIAN_FRONTEND

  check_ports_and_processes
  styled_echo success "Existing Installation Removed"
}

# Validate PHP version compatibility
validate_php_version() {
  local version=$1
  local valid_versions=("7.4" "8.0" "8.1" "8.2" "8.3")
  
  for valid_version in "${valid_versions[@]}"; do
    if [[ "$version" == "$valid_version" ]]; then
      return 0
    fi
  done
  
  log_error "Unsupported PHP version: $version. Supported versions: ${valid_versions[*]}"
  return 1
}

# Validate MySQL password strength
validate_mysql_password() {
  local password=$1
  local length=${#password}
  
  if [ $length -lt 8 ]; then
    styled_echo error "MySQL password must be at least 8 characters long"
    return 1
  fi
  
  # Check for at least one uppercase, lowercase, digit, and special character
  if [[ ! "$password" =~ [A-Z] ]] || [[ ! "$password" =~ [a-z] ]] || [[ ! "$password" =~ [0-9] ]] || [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
    styled_echo warning "Password should contain uppercase, lowercase, numbers, and special characters for better security"
  fi
  
  return 0
}

# Function to validate OS codename
validate_codename() {
  case "$(lsb_release -sc)" in
    focal|jammy)
      # Supported codenames
      ;;
    *)
      styled_echo error "Unsupported Ubuntu codename '$(lsb_release -sc)'."
      styled_echo error "Please use Ubuntu 20.04 (focal) or 22.04 (jammy)."
      exit 1
      ;;
  esac
}

# Add PHP repository based on OS
add_php_repository() {
  styled_echo info "Adding PHP Repository"

  validate_codename

  if [[ "$os_name" == "ubuntu" ]]; then
    # Ubuntu: Use ppa:ondrej/php
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
  elif [[ "$os_name" == "debian" ]]; then
    # Debian: Use sury.org
    apt install -y apt-transport-https lsb-release ca-certificates wget
    wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
  fi

  apt update -y
  styled_echo info "PHP Repository Added Successfully"
}

# Install PHP and required extensions
install_php() {
  local php_version=$1
  styled_echo info "Installing PHP $php_version"

  # Add the PHP repository before installation
  add_php_repository

  apt install -y \
    php$php_version-fpm \
    php$php_version-cli \
    php$php_version-zip \
    php$php_version-gd \
    php$php_version-common \
    php$php_version-xml \
    php$php_version-bcmath \
    php$php_version-mbstring \
    php$php_version-curl \
    php$php_version-mysql \
    php$php_version-ldap

  update-alternatives --set php /usr/bin/php$php_version
  styled_echo info "PHP $php_version Installed"
}

# Install Apache
install_apache() {
  local php_version=$1
  styled_echo info "Installing Apache..."
  DEBIAN_FRONTEND=noninteractive apt install -y apache2 libapache2-mod-php$php_version
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to install Apache."
    exit 1
  fi

  ufw allow in "Apache Full"

  systemctl start apache2 && systemctl enable apache2
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to start or enable Apache."
    exit 1
  fi

  apache2ctl configtest
  if [ $? -ne 0 ]; then
    styled_echo error "Apache configuration test failed."
    exit 1
  fi

  # Enable PHP module and restart the web server
  a2enmod php$php_version
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to enable PHP module."
    exit 1
  fi

  systemctl restart apache2
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to restart Apache."
    exit 1
  fi

  styled_echo success "Apache Installed Successfully."
}

# Install Nginx
install_nginx() {
  styled_echo info "Installing Nginx"
  apt install -y nginx
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to install Nginx."
    exit 1
  fi

  ufw allow "Nginx Full"
  systemctl enable nginx && systemctl start nginx
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to enable or start Nginx."
    exit 1
  fi

  systemctl restart nginx
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to restart Nginx."
    exit 1
  fi

  styled_echo success "Nginx installed and configured"
}

# Install MySQL
install_mysql() {
  local pass=$1
  styled_echo info "Installing MySQL"

  echo "mysql-server mysql-server/root_password password $pass" | debconf-set-selections
  echo "mysql-server mysql-server/root_password_again password $pass" | debconf-set-selections

  apt install -y mysql-server
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to install MySQL."
    exit 1
  fi

  systemctl start mysql && systemctl enable mysql
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to start or enable MySQL."
    exit 1
  fi

  styled_echo success "MySQL Installed Successfully"
}

# Install phpMyAdmin
install_phpmyadmin() {
  local pass=$1
  local php_version=$2

  styled_echo info "Installing phpMyAdmin"

  # Pre-configure debconf selections for non-interactive installation
  echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/app-password-confirm password $pass" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/admin-pass password $pass" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/mysql/app-pass password $pass" | debconf-set-selections
  echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

  # Download the latest phpMyAdmin
  styled_echo info "Downloading latest phpMyAdmin"
  wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -P /tmp
  tar xzf /tmp/phpMyAdmin-latest-all-languages.tar.gz -C /usr/share/
  mv /usr/share/phpMyAdmin-*-all-languages /usr/share/phpmyadmin

  # Configure phpMyAdmin
  styled_echo info "Configuring phpMyAdmin"
  cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php

  # Set a 32-character hexadecimal blowfish_secret
  sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg['blowfish_secret'] = '$(openssl rand -hex 16)';/" /usr/share/phpmyadmin/config.inc.php

  # Set permissions
  chown -R www-data:www-data /usr/share/phpmyadmin
  chmod -R 755 /usr/share/phpmyadmin

  # Configure phpMyAdmin storage
  styled_echo info "Setting up phpMyAdmin configuration storage"

  # Create phpMyAdmin database and import tables
  mysql -u root -p"$pass" -e "CREATE DATABASE IF NOT EXISTS phpmyadmin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -p"$pass" phpmyadmin < /usr/share/phpmyadmin/sql/create_tables.sql

  # Create phpMyAdmin control user
  CONTROL_USER="pma"
  CONTROL_PASS="$(openssl rand -base64 16)"  # Generates a 24-character string
  mysql -u root -p"$pass" -e "CREATE USER '$CONTROL_USER'@'localhost' IDENTIFIED BY '$CONTROL_PASS';"
  mysql -u root -p"$pass" -e "GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO '$CONTROL_USER'@'localhost';"
  mysql -u root -p"$pass" -e "FLUSH PRIVILEGES;"

  # Update config.inc.php with control user credentials
  sed -i "s/\$cfg\['Servers'\]\[\$i\]\['controluser'\] = '';/\$cfg['Servers'][\$i]['controluser'] = '$CONTROL_USER';/" /usr/share/phpmyadmin/config.inc.php
  sed -i "s/\$cfg\['Servers'\]\[\$i\]\['controlpass'\] = '';/\$cfg['Servers'][\$i]['controlpass'] = '$CONTROL_PASS';/" /usr/share/phpmyadmin/config.inc.php

  # For Nginx configuration
  if command -v nginx > /dev/null 2>&1; then
    styled_echo info "Configuring phpMyAdmin for Nginx..."
    ln -s /usr/share/phpmyadmin /var/www/html/

    # Set permissions for the phpMyAdmin directory
    chown -R www-data:www-data /var/www/html/phpmyadmin
    chmod -R 755 /var/www/html/phpmyadmin

    # Create Nginx configuration for phpMyAdmin
    NGINX_CONF="/etc/nginx/sites-available/default"
    cat <<EOL > "$NGINX_CONF"
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name localhost;
    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /phpmyadmin {
        alias /usr/share/phpmyadmin/;
        index index.php index.html index.htm;
    }

    location ~ ^/phpmyadmin/(.+\.php)$ {
        alias /usr/share/phpmyadmin/\$1;
        fastcgi_pass unix:/run/php/php${php_version}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        include fastcgi_params;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL
    phpenmod mbstring
    systemctl restart php$php_version-fpm
    systemctl restart nginx
    nginx -t
    if [ $? -ne 0 ]; then
      styled_echo error "Nginx configuration test failed. Please check your settings."
      exit 1
    fi
  fi

  # For Apache configuration
  if command -v apache2 > /dev/null 2>&1; then
    styled_echo info "Configuring phpMyAdmin for Apache..."
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
    ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
    a2enconf phpmyadmin
    phpenmod mbstring
    systemctl restart apache2
    apache2ctl configtest
    if [ $? -eq 0 ]; then
      systemctl reload apache2
    else
      styled_echo error "Apache2 configuration test failed. Please check your settings."
      exit 1
    fi
  fi

  styled_echo success "phpMyAdmin Installed and Configured Successfully"
}

# Install Supervisor
install_supervisor() {
  styled_echo info "Installing Supervisor"

  apt install -y supervisor
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to install Supervisor."
    exit 1
  fi

  systemctl start supervisor && systemctl enable supervisor
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to start or enable Supervisor."
    exit 1
  fi

  styled_echo success "Supervisor Installed Successfully"
}

# Install Composer
install_composer() {
  styled_echo info "Installing Composer"
  curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to download Composer installer."
    exit 1
  fi

  HASH=$(curl -sS https://composer.github.io/installer.sig)
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to retrieve Composer installer hash."
    exit 1
  fi

  php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); exit(1); } echo PHP_EOL;"
  if [ $? -ne 0 ]; then
    styled_echo error "Composer installer verification failed."
    exit 1
  fi

  # Install Composer globally
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  if [ $? -ne 0 ]; then
    styled_echo error "Failed to install Composer."
    exit 1
  fi

  styled_echo success "Composer Installed Successfully"
}

# Function to check if any ports are still in use by Apache, Nginx, MySQL
check_ports_and_processes() {
  styled_echo info "Checking for Running Services"

  # Check if any processes are still running on web server ports
  services=(80 443 3306)
  for port in "${services[@]}"; do
    if lsof -i :$port > /dev/null; then
      echo "ERROR: Port $port is still in use. Killing processes..."
      fuser -k $port/tcp
    else
      echo "Port $port is free."
    fi
  done

  # Check for any remaining broken installations
  styled_echo info "Checking for Broken Installations"
  dpkg --configure -a
  apt --fix-broken install
  apt -y autoremove
  apt -y autoclean

  styled_echo success "System is Clean"
}

# Define update_system function
update_system() {
  styled_echo info "Updating system packages..."
  apt update -y && apt upgrade -y
  if [ $? -ne 0 ]; then
    styled_echo error "System update failed."
    exit 1
  fi
  styled_echo success "System packages updated successfully."
}

# Show help message
show_help() {
  cat << EOF
Usage: install-lamp.sh [options]

Options:
  --lamp                    Install LAMP stack (Apache, MySQL, PHP)
  --lemp                    Install LEMP stack (Nginx, MySQL, PHP)
  
Customization Options:
  -p, --mysql-password       Set MySQL root password (default: testT8080)
  -v, --php-version          Specify PHP version to install (default: 8.2)
  -s, --supervisor           Install Supervisor (default: false)
  -c, --composer             Install Composer (default: false)
  -r, --remove               Remove existing LAMP or LEMP stack
  -h, --help                 Show this help message

Examples:
  ./install-lamp.sh --lamp --php-version=8.2
  ./install-lamp.sh --lemp --php-version=8.2 --mysql-password=mysecurepassword
  
EOF
}

# Parse arguments
while [ "$1" != "" ]; do
  case "$1" in
    --lamp ) install_lamp=true; install_lemp=false; shift ;;
    --lemp ) install_lemp=true; install_lamp=false; shift ;;
    -p | --mysql-password ) mysql_pass="$2"; shift 2 ;;
    -v | --php-version ) php_version="$2"; shift 2 ;;
    -c | --composer ) install_composer=true; shift ;;
    -s | --supervisor ) install_supervisor=true; shift ;;
    -r | --remove ) remove_web_server=true; shift ;;
    -h | --help ) show_help; exit ;;

    * ) styled_echo error "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Display Welcome Banner
clear

cat << "EOF"
██████╗ ██╗███████╗██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗
██╔══██╗██║██╔════╝██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝
██████╔╝██║█████╗  ██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   
██╔══██╗██║██╔══╝  ██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   
██║  ██║██║██║     ██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   
╚═╝  ╚═╝╚═╝╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝ 

EOF

styled_echo info "Welcome to the RifRocket Web Server Installer."
styled_echo info "This installer will help you set up or remove LAMP or LEMP stacks on your system."

# Replace whiptail menu with shell-native select menu
styled_echo info "Select an option:"
options=(
    "Install LAMP stack (Apache, MySQL, PHP)"
    "Install LEMP stack (Nginx, MySQL, PHP)"
    "Remove existing web server"
    "Exit Installer"
)

PS3="Enter your choice [1-4]: "
select opt in "${options[@]}"
do
  case "$REPLY" in
    1)
      install_lamp=true
      install_lemp=false
      remove_web_server=false
      break
      ;;
    2)
      install_lemp=true
      install_lamp=false
      remove_web_server=false
      break
      ;;
    3)
      remove_web_server=true
      install_lamp=false
      install_lemp=false
      break
      ;;
    4)
      styled_echo info "Exiting Installer."
      exit 0
      ;;
    *)
      styled_echo error "Invalid option selected."
      ;;
  esac
done

# Run the installation steps based on selections
if $remove_web_server; then
  remove_existing_installation
else
  # Prompt whether to install PHP
  read -p "Do you want to install PHP? [Y/n]: " install_php_input
  install_php_input="${install_php_input:-Y}"  # Default to Y
  if [[ "$install_php_input" =~ ^[Yy]$ ]]; then
    install_php_flag=true
    while true; do
      read -p "Enter PHP version [default: 8.2]: " input_php_version
      php_version="${input_php_version:-8.2}"
      if validate_php_version "$php_version"; then
        break
      fi
      styled_echo error "Please enter a valid PHP version"
    done
  else
    install_php_flag=false
  fi

  # New: Prompt whether to install MySQL
  read -p "Do you want to install MySQL? [Y/n]: " install_mysql_input
  install_mysql_input="${install_mysql_input:-Y}"  # Default to Y
  if [[ "$install_mysql_input" =~ ^[Yy]$ ]]; then
    install_mysql_flag=true
    while true; do
      read -s -p "Enter MySQL root password [press Enter for auto-generated secure password]: " input_mysql_pass
      echo ""
      if [ -z "$input_mysql_pass" ]; then
        # Use the auto-generated secure password
        styled_echo info "Using auto-generated secure password"
        break
      else
        if validate_mysql_password "$input_mysql_pass"; then
          mysql_pass="$input_mysql_pass"
          break
        fi
        styled_echo error "Please enter a stronger password or press Enter for auto-generated one"
      fi
    done
  else
    install_mysql_flag=false
  fi
  
  # Prompt for installing Supervisor
  read -p "Do you want to install Supervisor? [default: N] [y/N]: " install_supervisor_input
  if [[ "$install_supervisor_input" =~ ^[Yy]$ ]]; then
    install_supervisor=true
  else
    install_supervisor=false
  fi
  
  # Prompt for installing Composer
  read -p "Do you want to install Composer? [default: N] [y/N]: " install_composer_input
  if [[ "$install_composer_input" =~ ^[Yy]$ ]]; then
    install_composer=true
  else
    install_composer=false
  fi
  
  update_system
  check_requirements
  create_backup
  
  # Set up error handling
  trap 'rollback_installation; exit 1' ERR
  
  if [ "$install_lamp" = true ]; then
    # Conditionally install PHP and MySQL (and phpMyAdmin)
    if $install_php_flag; then
      install_php "$php_version"
    fi
    install_apache "$php_version"
    if $install_mysql_flag; then
      install_mysql "$mysql_pass"
      if $install_php_flag; then
        install_phpmyadmin "$mysql_pass" "$php_version"
      fi
    fi
  fi
  
  if [ "$install_lemp" = true ]; then
    if $install_php_flag; then
      install_php "$php_version"
    fi
    install_nginx
    if $install_mysql_flag; then
      install_mysql "$mysql_pass"
      if $install_php_flag; then
        install_phpmyadmin "$mysql_pass" "$php_version"
      fi
    fi
  fi
  
  if $install_composer; then
    install_composer
  fi
  
  if $install_supervisor; then
    install_supervisor
  fi
  
  if ( is_lemp_installed || is_lamp_installed ) && [ "$remove_web_server" = false ]; then
    # Run embedded post-installation tasks
    styled_echo info "Running post-installation tasks..."
    create_embedded_post_install_content
    
    # Send completion notification
    if [ "$install_lemp" = true ]; then
      DisplayCompletionMessage "LEMP"
      send_notification "LEMP Stack Installation Complete" "LEMP stack has been successfully installed on $(hostname)"
    else
      DisplayCompletionMessage "LAMP"  
      send_notification "LAMP Stack Installation Complete" "LAMP stack has been successfully installed on $(hostname)"
    fi
    
    # Clean up
    cleanup_temp_files
  fi
fi

# ============================================================================
# EMBEDDED POST-INSTALLATION FUNCTIONS
# ============================================================================

create_embedded_post_install_content() {
    # Create test PHP file
    local webroot="/var/www/html"
    local test_file="$webroot/info.php"
    
    styled_echo info "Creating PHP test file..."
    cat > "$test_file" << 'EOF'
<?php
// LAMP/LEMP Stack Test Page
phpinfo();
?>
EOF
    
    chown www-data:www-data "$test_file"
    chmod 644 "$test_file"
    
    # Create sample website
    local index_file="$webroot/index.html"
    styled_echo info "Creating sample website..."
    cat > "$index_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP/LEMP Stack - Welcome</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 2rem;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .status {
            font-size: 1.2rem;
            margin: 1rem 0;
            padding: 0.5rem;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 5px;
        }
        .links {
            margin-top: 2rem;
        }
        .links a {
            color: #ffd700;
            text-decoration: none;
            margin: 0 1rem;
            padding: 0.5rem 1rem;
            border: 2px solid #ffd700;
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        .links a:hover {
            background: #ffd700;
            color: #333;
        }
        .server-info {
            margin-top: 2rem;
            font-size: 0.9rem;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 LAMP/LEMP Stack</h1>
        <div class="status">✅ Installation Successful!</div>
        <p>Your web server is now running and ready for development.</p>
        
        <div class="links">
            <a href="/info.php" target="_blank">PHP Info</a>
            <a href="/phpmyadmin" target="_blank">phpMyAdmin</a>
        </div>
        
        <div class="server-info">
            <p>Server Time: <span id="time"></span></p>
            <p>Ready to start coding! 💻</p>
        </div>
    </div>
    
    <script>
        function updateTime() {
            document.getElementById('time').textContent = new Date().toLocaleString();
        }
        updateTime();
        setInterval(updateTime, 1000);
    </script>
</body>
</html>
EOF
    
    chown www-data:www-data "$index_file"
    chmod 644 "$index_file"
    
    # Optimize PHP if installed
    if $install_php_flag; then
        optimize_php "$php_version"
    fi
    
    # Configure firewall
    configure_firewall
    
    styled_echo success "Post-installation setup completed!"
}

# Final cleanup and success message
styled_echo success "Installation completed successfully!"
styled_echo info "Check the logs at: /var/log/lamp_lemp_installer.log"
