#!/bin/bash

# Default values
mysql_pass="testT8080"
php_version="8.2"  # Default PHP version
install_lamp=true
install_lemp=false
install_composer=true    # Set Composer install default to true
install_supervisor=false # Set Supervisor install default to false
remove_web_server=false

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
  echo "| Web Site: http://$ip/                     "
  echo "| PhpMyAdmin: http://$ip/phpmyadmin         "
  echo "| User: root || Pass: $mysql_pass           "
  echo "+-------------------------------------------+"
  
}

# Check OS compatibility and root privileges
check_requirements() {
  if [ "$(id -u)" -ne 0 ]; then
    styled_echo error "Please run this script with sudo or as root."
    exit 1
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    os_name=$ID
    os_version=$VERSION_ID
  else
    styled_echo error "Cannot determine OS. /etc/os-release not found."
    exit 1
  fi

  if [[ "$os_name" != "ubuntu" && "$os_name" != "debian" ]]; then
    styled_echo error "This script only supports Ubuntu and Debian."
    exit 1
  fi

  # For Ubuntu, ensure version is 20 or higher
  if [[ "$os_name" == "ubuntu" ]]; then
    if (( $(echo "$os_version < 20" | bc -l) )); then
      styled_echo error "This script requires Ubuntu 20 or higher."
      exit 1
    fi
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

  # Install phpMyAdmin
  DEBIAN_FRONTEND=noninteractive apt -y install phpmyadmin
  update-alternatives --set php /usr/bin/php$php_version

  # Remove existing symlink if it exists
  if [ -e /var/www/html/phpmyadmin ]; then
    rm -rf /var/www/html/phpmyadmin
  fi

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

  styled_echo success "phpMyAdmin Installed Successfully"
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
  # Prompt for PHP version with default value using read
  read -p "Enter PHP version [default: 8.2]: " input_php_version
  php_version="${input_php_version:-8.2}"
  
  # Prompt for MySQL root password with default value using read
  read -p "Enter MySQL root password [default: testT8080]: " input_mysql_pass
  mysql_pass="${input_mysql_pass:-testT8080}"
  
  # Prompt for installing Supervisor using read Yes/No
  read -p "Do you want to install Supervisor? [default: N] [y/N]: " install_supervisor_input
  if [[ "$install_supervisor_input" =~ ^[Yy]$ ]]; then
    install_supervisor=true
  else
    install_supervisor=false
  fi
  
  # Prompt for installing Composer using read Yes/No
  read -p "Do you want to install Composer? [default: N] [y/N]: " install_composer_input
  if [[ "$install_composer_input" =~ ^[Yy]$ ]]; then
    install_composer=true
  else
    install_composer=false
  fi
  
  update_system
  check_requirements
  
  if [ "$install_lamp" = true ]; then
    install_php "$php_version"
    install_apache "$php_version"
    install_mysql "$mysql_pass"
    install_phpmyadmin "$mysql_pass" "$php_version"
  fi
  
  if [ "$install_lemp" = true ]; then
    install_php "$php_version"
    install_nginx
    install_mysql "$mysql_pass"
    install_phpmyadmin "$mysql_pass" "$php_version"
  fi
  
  if $install_composer; then
    install_composer
  fi
  
  if $install_supervisor; then
    install_supervisor
  fi
  
  # Check if any stack is installed and display completion message
  if ( is_lemp_installed || is_lamp_installed ) && [ "$remove_web_server" = false ]; then
    if [ "$install_lemp" = true ]; then
      DisplayCompletionMessage "LEMP"
    else
      DisplayCompletionMessage "LAMP"
    fi
  fi
fi
