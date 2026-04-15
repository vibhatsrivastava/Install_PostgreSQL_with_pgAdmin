# Apache Reverse Proxy Setup for pgAdmin

Configure Apache as a reverse proxy to access pgAdmin through a custom local domain (e.g., `https://postgresql.local`) with optional SSL support.

## Overview

After installing PostgreSQL and pgAdmin, you can optionally configure Apache as a reverse proxy for:

- **Custom Domain**: Access pgAdmin with a friendly domain name
- **SSL/HTTPS**: Secure your pgAdmin access with self-signed certificates
- **Professional Setup**: Mimics production-like environments for development
- **Easier Access**: Remember `https://postgresql.local` instead of `http://192.168.1.x/pgadmin4`

## Prerequisites

Before running the reverse proxy setup:

1. ✅ PostgreSQL and pgAdmin must be already installed (run `install_postgresql_pgadmin.sh` first)
2. ✅ Apache must be running
3. ✅ Root/sudo privileges

## Quick Start

### 1. Configure Reverse Proxy Settings

Edit the configuration file:

```bash
nano configs/install_config_proxy.conf
```

**Key settings:**

```bash
# Domain name for local access
DOMAIN_NAME="postgresql.local"

# Enable SSL with self-signed certificate
ENABLE_SSL="yes"

# SSL certificate details
SSL_COUNTRY="US"
SSL_STATE="California"
SSL_CITY="San Francisco"
SSL_ORG="Development"
```

### 2. Secure Configuration File

```bash
chmod 600 configs/install_config_proxy.conf
```

### 3. Run the Reverse Proxy Setup Script

```bash
chmod +x install_apache_reverse_proxy.sh
sudo ./install_apache_reverse_proxy.sh
```

The script will:
- Check that PostgreSQL and pgAdmin are installed and running
- Enable required Apache modules (proxy, ssl, headers)
- Generate a self-signed SSL certificate (if enabled)
- Create Apache VirtualHost configuration
- Add the domain to `/etc/hosts`
- Verify the reverse proxy is working

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `DOMAIN_NAME` | Local domain name | postgresql.local |
| `ENABLE_SSL` | Enable HTTPS with self-signed cert | yes |
| `SSL_COUNTRY` | Certificate country code | US |
| `SSL_STATE` | Certificate state/province | California |
| `SSL_CITY` | Certificate city | San Francisco |
| `SSL_ORG` | Certificate organization | Development |
| `SSL_DAYS_VALID` | Certificate validity in days | 365 |
| `APACHE_CONFIG_NAME` | VirtualHost config file name | pgadmin-proxy |
| `HTTP_PORT` | HTTP port | 80 |
| `HTTPS_PORT` | HTTPS port | 443 |

## Accessing pgAdmin Through Reverse Proxy

### With SSL (HTTPS)

Open your browser and navigate to:
```
https://postgresql.local/
```

**⚠️ Certificate Warning**: Your browser will show a security warning because the SSL certificate is self-signed. This is normal for local development. Click "Advanced" or "Proceed" to continue.

### Without SSL (HTTP)

```
http://postgresql.local/
```

**Login credentials**: Use the same pgAdmin credentials from the main installation (`PGADMIN_EMAIL` and `PGADMIN_PASSWORD`).

## SSL Certificate Management

When `ENABLE_SSL="yes"`, the script generates a self-signed SSL certificate:

- **Certificate location**: `/etc/apache2/ssl/postgresql.local/postgresql.local.crt`
- **Private key location**: `/etc/apache2/ssl/postgresql.local/postgresql.local.key`
- **Validity**: 365 days by default (configurable)

### Accepting Self-Signed Certificates

**Chrome/Edge:**
1. When you see the warning, click "Advanced"
2. Click "Proceed to postgresql.local (unsafe)"

**Firefox:**
1. Click "Advanced"
2. Click "Accept the Risk and Continue"

### Permanently Trust Certificate (Optional)

```bash
# Export the certificate
sudo cp /etc/apache2/ssl/postgresql.local/postgresql.local.crt ~/

# Import to system trust store (Ubuntu)
sudo cp /etc/apache2/ssl/postgresql.local/postgresql.local.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

## Management Commands

### Apache VirtualHost Management

```bash
# Check Apache virtual host configuration
sudo apache2ctl -S

# View reverse proxy access logs
sudo tail -f /var/log/apache2/pgadmin-proxy_access.log

# View SSL access logs
sudo tail -f /var/log/apache2/pgadmin-proxy_ssl_access.log

# Test configuration
sudo apache2ctl configtest

# Reload Apache after manual config changes
sudo systemctl reload apache2

# Disable reverse proxy
sudo a2dissite pgadmin-proxy
sudo systemctl reload apache2

# Re-enable reverse proxy
sudo a2ensite pgadmin-proxy
sudo systemctl reload apache2
```

## Troubleshooting

### Domain Not Resolving

**Symptom:** Browser cannot find `postgresql.local`

1. Check `/etc/hosts` file:
   ```bash
   cat /etc/hosts | grep postgresql.local
   ```
   Should show: `127.0.0.1    postgresql.local`

2. If missing, add manually:
   ```bash
   echo "127.0.0.1    postgresql.local" | sudo tee -a /etc/hosts
   ```

### SSL Certificate Errors

**Symptom:** SSL certificate not working

1. Verify certificate files exist:
   ```bash
   ls -la /etc/apache2/ssl/postgresql.local/
   ```

2. Check certificate details:
   ```bash
   openssl x509 -in /etc/apache2/ssl/postgresql.local/postgresql.local.crt -text -noout
   ```

3. Verify Apache SSL module is enabled:
   ```bash
   apache2ctl -M | grep ssl
   ```

### Proxy Not Working

**Symptom:** Cannot access pgAdmin through proxy

1. Check if proxy modules are enabled:
   ```bash
   apache2ctl -M | grep proxy
   ```
   Should show: `proxy_module`, `proxy_http_module`

2. Check VirtualHost configuration:
   ```bash
   sudo nano /etc/apache2/sites-available/pgadmin-proxy.conf
   ```

3. Test Apache configuration:
   ```bash
   sudo apache2ctl configtest
   ```

4. Check if site is enabled:
   ```bash
   ls -la /etc/apache2/sites-enabled/ | grep pgadmin-proxy
   ```

### HTTP 503 or 502 Errors

**Symptom:** Proxy returns error codes

1. Ensure pgAdmin is running on Apache:
   ```bash
   curl -I http://127.0.0.1/pgadmin4/
   ```

2. Check Apache error logs:
   ```bash
   sudo tail -f /var/log/apache2/pgadmin-proxy_error.log
   ```

3. Restart Apache:
   ```bash
   sudo systemctl restart apache2
   ```

## Removal

To remove the reverse proxy configuration:

```bash
# Disable the site
sudo a2dissite pgadmin-proxy

# Remove configuration file
sudo rm /etc/apache2/sites-available/pgadmin-proxy.conf

# Remove SSL certificates
sudo rm -rf /etc/apache2/ssl/postgresql.local

# Remove from /etc/hosts
sudo sed -i '/postgresql.local/d' /etc/hosts

# Reload Apache
sudo systemctl reload apache2
```

## Advanced Configuration

### Custom VirtualHost Configuration

Edit the generated configuration:

```bash
sudo nano /etc/apache2/sites-available/pgadmin-proxy.conf
```

**Example customizations:**
- Add custom headers
- Configure logging options
- Set up basic authentication
- Add rate limiting

### Using Let's Encrypt Certificate

For production environments, replace self-signed certificate with Let's Encrypt:

```bash
# Install Certbot
sudo apt install certbot python3-certbot-apache

# Obtain certificate
sudo certbot --apache -d yourdomain.com

# Certificate will be automatically configured
```

### Multiple Domains

To serve pgAdmin on multiple domains:

```bash
# Add ServerAlias to VirtualHost
sudo nano /etc/apache2/sites-available/pgadmin-proxy.conf

# Add this line inside <VirtualHost>
ServerAlias postgresql2.local

# Add to /etc/hosts
echo "127.0.0.1    postgresql2.local" | sudo tee -a /etc/hosts

# Reload Apache
sudo systemctl reload apache2
```

---

**Related Documentation:**
- [Configuration Reference](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Back to Main README](../README.md)
