# LAMP/LEMP Stack Installation Script

This bash script automates the installation of a LAMP or LEMP stack on a DigitalOcean droplet or Ubuntu server. It includes options for installing various additional components like Composer, and Supervisor.

## Features
- LAMP stack installation (Linux, Apache, MySQL, PHP)
- LEMP stack installation (Linux, Nginx, MySQL, PHP)
- Support for custom PHP versions
- Automatic configuration for MySQL and web servers
- Ability to remove existing web servers

## Requirements
- Ubuntu server (compatible with Ubuntu versions < 22)
- Root or sudo access

## Installation

Run the following one-liner on your server to automatically download and execute the script:

```bash
wget --no-check-certificate -O /tmp/install-lamp.sh https://raw.githubusercontent.com/rifrocket/Lamp-Lemp-Server-Installer/main/install-lamp.sh; sudo bash /tmp/install-lamp.sh
```

## Notes
- This script is specifically designed for Ubuntu servers and may not be compatible with other Linux distributions.
- Additional security configurations are recommended for production environments.
- Ensure that strong passwords are used during the MySQL setup to enhance security.
- The script can be further customized by modifying the default options at the top of the file.
- If any prompts appear, you can keep the default setting by simply pressing the "Enter" key.
