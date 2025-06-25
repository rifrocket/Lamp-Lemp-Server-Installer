#!/bin/bash

# Common utility functions for LAMP/LEMP installer

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
    
    # Enable OPcache
    echo "opcache.enable=1" >> "$ini_file"
    echo "opcache.memory_consumption=128" >> "$ini_file"
    echo "opcache.max_accelerated_files=10000" >> "$ini_file"
    
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
