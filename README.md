# LAMP/LEMP Stack Installation Script

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/rifrocket/Lamp-Lemp-Server-Installer/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange.svg)]()

This robust bash script automates the installation of LAMP or LEMP stacks on Ubuntu/Debian servers with advanced security features, error handling, and customization options for PHP developers.

## 🚀 Quick Start

### Option 1: Single-File Installation (Recommended for simplicity)
Perfect for quick setups - downloads and runs one self-contained script:

```bash
wget --no-check-certificate -O /tmp/install-lamp.sh https://raw.githubusercontent.com/rifrocket/Lamp-Lemp-Server-Installer/main/install-lamp.sh
chmod +x /tmp/install-lamp.sh
sudo /tmp/install-lamp.sh
```

### Option 2: Full Installation (Recommended for advanced users)
Downloads all components for maximum customization:

```bash
sudo bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/rifrocket/Lamp-Lemp-Server-Installer/main/bootstrap.sh)
```

### Option 3: Manual Download
```bash
git clone https://github.com/rifrocket/Lamp-Lemp-Server-Installer.git
cd Lamp-Lemp-Server-Installer
sudo ./install-lamp.sh
```

## ✨ Features

### Core Stacks
- **LAMP**: Linux + Apache + MySQL + PHP
- **LEMP**: Linux + Nginx + MySQL + PHP

### Security Features
- 🔐 Auto-generated secure passwords
- 🛡️ Automatic firewall configuration
- 🔒 Secure MySQL installation
- 📝 Configuration backups before changes
- 🚫 Input validation and sanitization

### Developer Tools
- 🎼 Composer (PHP dependency manager)
- 👥 Supervisor (process control system)
- 🗄️ phpMyAdmin with secure configuration
- ⚡ PHP performance optimization
- 📊 Multiple PHP version support (7.4, 8.0, 8.1, 8.2, 8.3)

### Advanced Features
- 🔄 Rollback capability on failures
- 📋 Comprehensive logging
- 🧹 Automatic cleanup and removal
- 🌐 Network connectivity testing
- 💾 System requirements validation

## 📋 Requirements

- **OS**: Ubuntu 20.04+ or Debian 10+
- **RAM**: Minimum 1GB (2GB+ recommended)
- **Storage**: Minimum 2GB free space
- **Access**: Root/sudo privileges
- **Network**: Internet connection required

## 🛠️ Installation Options

### Interactive Installation (Recommended)
```bash
sudo ./install-lamp.sh
```

### Command Line Arguments
```bash
# Install LAMP with PHP 8.2 and Composer
sudo ./install-lamp.sh --lamp --php-version=8.2 --composer

# Install LEMP with custom MySQL password
sudo ./install-lamp.sh --lemp --mysql-password=YourSecurePassword123!

# Remove existing installation
sudo ./install-lamp.sh --remove
```

### Available Arguments
| Argument | Description | Example |
|----------|-------------|---------|
| `--lamp` | Install LAMP stack | `--lamp` |
| `--lemp` | Install LEMP stack | `--lemp` |
| `-p, --mysql-password` | Set MySQL root password | `-p SecurePass123!` |
| `-v, --php-version` | Specify PHP version | `-v 8.2` |
| `-c, --composer` | Install Composer | `--composer` |
| `-s, --supervisor` | Install Supervisor | `--supervisor` |
| `-r, --remove` | Remove existing installation | `--remove` |
| `-h, --help` | Show help message | `--help` |

## ⚙️ Configuration

Edit `config.conf` to customize default settings:

```bash
# Default PHP Version
DEFAULT_PHP_VERSION="8.2"

# Security Settings
ENABLE_FIREWALL=true
SECURE_MYSQL_INSTALLATION=true

# Performance Settings
PHP_MEMORY_LIMIT="256M"
PHP_UPLOAD_MAX_FILESIZE="64M"

# Optional Components
INSTALL_COMPOSER=true
INSTALL_SUPERVISOR=false
```

## 🔧 Post-Installation

### Access Your Sites
- **Web Server**: `http://YOUR_SERVER_IP/`
- **phpMyAdmin**: `http://YOUR_SERVER_IP/phpmyadmin`
- **MySQL**: Host: `localhost`, User: `root`, Password: `[displayed at end of installation]`

### Important Files
- **Apache Config**: `/etc/apache2/`
- **Nginx Config**: `/etc/nginx/`
- **PHP Config**: `/etc/php/[version]/`
- **MySQL Config**: `/etc/mysql/`
- **Logs**: `/var/log/lamp_lemp_installer.log`

## 🛡️ Security Best Practices

1. **Change Default Passwords**: Always use strong, unique passwords
2. **Enable Firewall**: Script automatically configures UFW
3. **Regular Updates**: Keep your system and packages updated
4. **SSL Certificates**: Consider installing Let's Encrypt certificates
5. **File Permissions**: Review and secure file permissions

## 🔍 Troubleshooting

### Common Issues

**Installation Fails**
```bash
# Check logs
sudo tail -f /var/log/lamp_lemp_installer.log

# Check system resources
df -h  # Disk space
free -m  # Memory usage
```

**Service Not Starting**
```bash
# Check service status
sudo systemctl status apache2  # or nginx
sudo systemctl status mysql
sudo systemctl status php8.2-fpm
```

**Permission Issues**
```bash
# Fix web directory permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

### Recovery Options

**Rollback Installation**
```bash
# Automatic rollback is triggered on errors
# Manual rollback from backup
sudo cp -r /tmp/lamp_lemp_backup_*/apache2_backup /etc/apache2
```

**Complete Removal**
```bash
sudo ./install-lamp.sh --remove
```

## 📊 System Monitoring

### Check Installation Status
```bash
# Verify services
sudo systemctl status apache2 mysql php8.2-fpm

# Test PHP
php -v

# Test MySQL connection
mysql -u root -p -e "SELECT VERSION();"
```

### Performance Monitoring
```bash
# Web server status
sudo apache2ctl status  # Apache
sudo nginx -t  # Nginx config test

# PHP-FPM status
sudo systemctl status php8.2-fpm
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)  
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

- This script is designed for development and testing environments
- For production use, additional security hardening is recommended
- Always test in a staging environment first
- Review the script before running on important systems

## 🆘 Support

- 📧 **Issues**: [GitHub Issues](https://github.com/rifrocket/Lamp-Lemp-Server-Installer/issues)
- 📖 **Documentation**: This README and inline comments
- 💬 **Community**: [GitHub Discussions](https://github.com/rifrocket/Lamp-Lemp-Server-Installer/discussions)

---

**Made with ❤️ for PHP developers worldwide**
