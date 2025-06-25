#!/bin/bash

# Post-installation script for LAMP/LEMP stack
# This script should be run after the main installation completes

# Source utility functions
if [ -f "utils.sh" ]; then
    source utils.sh
else
    echo "Warning: utils.sh not found. Some functions may not work properly."
fi

echo "=========================================="
echo "  LAMP/LEMP Stack Post-Installation      "
echo "=========================================="

# Function to create a test PHP file
create_test_php() {
    local webroot="/var/www/html"
    local test_file="$webroot/info.php"
    
    echo "Creating PHP test file..."
    cat > "$test_file" << 'EOF'
<?php
// LAMP/LEMP Stack Test Page
phpinfo();
?>
EOF
    
    chown www-data:www-data "$test_file"
    chmod 644 "$test_file"
    echo "✓ Test PHP file created at: $test_file"
    echo "  Access it at: http://$(hostname -I | awk '{print $1}')/info.php"
}

# Function to create a sample website
create_sample_website() {
    local webroot="/var/www/html"
    local index_file="$webroot/index.html"
    
    echo "Creating sample website..."
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
    echo "✓ Sample website created"
}

# Function to optimize system
optimize_system() {
    echo "Performing system optimizations..."
    
    # Update system packages
    apt update -y >/dev/null 2>&1
    
    # Install useful development tools
    apt install -y curl wget unzip git htop tree >/dev/null 2>&1
    
    # Set up bash aliases for convenience
    cat >> /root/.bashrc << 'EOF'

# LAMP/LEMP Stack Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias lamp-status='systemctl status apache2 mysql php*-fpm'
alias lemp-status='systemctl status nginx mysql php*-fpm'
alias lamp-restart='systemctl restart apache2 mysql php*-fpm'
alias lemp-restart='systemctl restart nginx mysql php*-fpm'
alias lamp-logs='tail -f /var/log/apache2/error.log'
alias lemp-logs='tail -f /var/log/nginx/error.log'
alias mysql-log='tail -f /var/log/mysql/error.log'
EOF
    
    echo "✓ System optimizations completed"
}

# Function to set up log rotation
setup_log_rotation() {
    echo "Setting up log rotation..."
    
    cat > /etc/logrotate.d/lamp-lemp-installer << 'EOF'
/var/log/lamp_lemp_installer.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    echo "✓ Log rotation configured"
}

# Function to create maintenance script
create_maintenance_script() {
    cat > /usr/local/bin/lamp-lemp-maintenance << 'EOF'
#!/bin/bash

# LAMP/LEMP Stack Maintenance Script

echo "=========================================="
echo "  LAMP/LEMP Stack Maintenance            "
echo "=========================================="

# Update system packages
echo "Updating system packages..."
apt update -y && apt upgrade -y

# Clean up old packages
echo "Cleaning up old packages..."
apt autoremove -y
apt autoclean

# Check disk usage
echo "Disk usage:"
df -h

# Check memory usage
echo "Memory usage:"
free -h

# Check service status
echo "Service status:"
systemctl status apache2 nginx mysql php*-fpm --no-pager

# Check for available updates
echo "Available updates:"
apt list --upgradable

echo "Maintenance completed!"
EOF
    
    chmod +x /usr/local/bin/lamp-lemp-maintenance
    echo "✓ Maintenance script created at /usr/local/bin/lamp-lemp-maintenance"
}

# Main execution
main() {
    echo "Starting post-installation setup..."
    
    create_test_php
    create_sample_website
    optimize_system
    setup_log_rotation
    create_maintenance_script
    
    echo ""
    echo "=========================================="
    echo "  Post-Installation Setup Complete!      "
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Visit http://$(hostname -I | awk '{print $1}')/ to see your website"
    echo "2. Visit http://$(hostname -I | awk '{print $1}')/info.php to check PHP"
    echo "3. Run 'lamp-lemp-maintenance' for system maintenance"
    echo "4. Check logs: tail -f /var/log/lamp_lemp_installer.log"
    echo ""
    echo "Happy coding! 🚀"
}

# Run main function
main "$@"
