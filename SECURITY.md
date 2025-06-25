# Security Policy

## Supported Versions

We actively support the following versions of our LAMP/LEMP installer:

| Version | Supported          |
| ------- | ------------------ |
| 2.x.x   | :white_check_mark: |
| 1.x.x   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in our LAMP/LEMP installer, please report it responsibly.

### How to Report

1. **DO NOT** create a public GitHub issue for security vulnerabilities
2. Send an email to: [security@your-domain.com] (replace with actual email)
3. Include the following information:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if you have one)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Investigation**: We will investigate and assess the severity within 5 business days
- **Resolution**: Critical vulnerabilities will be patched within 7 days
- **Disclosure**: We will coordinate disclosure timeline with you

### Security Best Practices

When using this installer:

1. **Always run on fresh systems** - Don't install on production systems with existing data
2. **Change default passwords** - Use strong, unique passwords
3. **Keep systems updated** - Regularly update your OS and installed packages
4. **Review configurations** - Audit the generated configurations for your environment
5. **Use HTTPS** - Install SSL certificates for production use
6. **Regular backups** - Maintain regular backups of your configurations and data

### Known Security Considerations

- The installer requires root privileges
- Default configurations may not be suitable for production
- Network services are exposed after installation
- Log files may contain sensitive information

### Scope

This security policy covers:
- The main installation script (`install-lamp.sh`)
- Configuration files and utilities
- Documentation and examples

This policy does not cover:
- Third-party packages installed by the script
- Operating system vulnerabilities
- Network infrastructure security
- User-generated content or configurations

## Thanks

We appreciate the security research community and welcome responsible disclosure of security issues.
