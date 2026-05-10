#!/bin/bash
# Enhanced SSL Certificate Setup for TransXplorer
# Run this AFTER your domain DNS is pointing to your server IP

set -e

echo "==================================================="
echo "  SSL Certificate Setup for TransXplorer"
echo "==================================================="
echo ""

# Check if domain is provided
if [ -z "$1" ]; then
    echo "❌ ERROR: Domain name required!"
    echo ""
    echo "Usage: ./06_setup_ssl.sh yourdomain.com [your-email@example.com]"
    echo ""
    echo "Before running this script:"
    echo "  1. Point your domain's A record to your server IP"
    echo "  2. Wait for DNS propagation (10-30 minutes)"
    echo "  3. Verify DNS with: dig yourdomain.com +short"
    echo "  4. Run this script with your domain name"
    echo ""
    echo "Example:"
    echo "  ./06_setup_ssl.sh transxplorer.mydomain.com admin@mydomain.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"admin@$DOMAIN"}  # Use provided email or default to admin@domain

echo "Configuration:"
echo "  Domain: $DOMAIN"
echo "  Email:  $EMAIL"
echo ""

# Check DNS before proceeding
echo "🔍 Checking DNS propagation..."
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ -z "$DNS_IP" ]; then
    echo "❌ ERROR: Domain $DOMAIN does not resolve to any IP!"
    echo "Please configure your DNS A record first and wait for propagation."
    exit 1
fi
echo "✅ Domain resolves to: $DNS_IP"
echo ""

read -p "Continue with SSL setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Install Certbot
echo ""
echo "[1/6] Installing Certbot..."
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Stop nginx temporarily (but keep app running)
echo ""
echo "[2/6] Stopping nginx temporarily..."
docker stop transxplorer_nginx 2>/dev/null || true

# Obtain certificate
echo ""
echo "[3/6] Obtaining SSL certificate from Let's Encrypt..."
echo "     This may take 1-2 minutes..."
sudo certbot certonly --standalone \
    -d $DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --preferred-challenges http

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ ERROR: Certificate generation failed!"
    echo "Common issues:"
    echo "  - Port 80 is blocked by firewall"
    echo "  - DNS not propagated yet"
    echo "  - Domain already has a certificate"
    echo ""
    echo "Restarting nginx..."
    docker start transxplorer_nginx 2>/dev/null || docker-compose up -d nginx
    exit 1
fi

# Copy certificates to Docker volume
echo ""
echo "[4/6] Copying certificates to Docker volume..."
sudo mkdir -p ./ssl
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./ssl/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./ssl/
sudo chmod 644 ./ssl/*.pem

# Update nginx.conf
echo ""
echo "[5/6] Updating nginx configuration..."

# Backup original
cp nginx.conf nginx.conf.backup

# Update server_name in HTTP block
sed -i "s/server_name _;/server_name $DOMAIN;/" nginx.conf

# Uncomment HTTPS redirect in HTTP block
sed -i 's|# return 301 https://\$host\$request_uri;|return 301 https://\$host\$request_uri;|' nginx.conf

# Comment out the HTTP location block (since we're redirecting)
sed -i '/# For testing without SSL, proxy directly/,/limit_req zone=shiny_limit burst=20 nodelay;/{s/^/#/}' nginx.conf

# Uncomment HTTPS server block
sed -i '/# HTTPS Server/,/^    # }/{s/^    # //}' nginx.conf
sed -i "s/yourdomain.com/$DOMAIN/g" nginx.conf

# Restart containers
echo ""
echo "[6/6] Restarting containers with SSL..."
docker-compose up -d

# Wait for nginx to start
sleep 5

echo ""
echo "==================================================="
echo "  ✅ SSL Certificate Setup Complete!"
echo "==================================================="
echo ""
echo "Your app is now accessible at:"
echo "  🌐 https://$DOMAIN"
echo ""
echo "Certificate Information:"
echo "  📅 Valid for: 90 days"
echo "  📧 Notifications: $EMAIL"
echo "  🔄 Auto-renewal: Configured"
echo ""
echo "Next Steps:"
echo "  1. Test your site: https://$DOMAIN"
echo "  2. Set up auto-renewal cron (see below)"
echo "  3. Share with testers!"
echo ""
echo "==================================================="
echo "SSL Auto-Renewal Setup:"
echo "==================================================="
echo ""
echo "Add this to your crontab (sudo crontab -e):"
echo ""
echo "# Renew SSL certificate twice daily"
echo "0 0,12 * * * certbot renew --quiet --deploy-hook 'cd $(pwd) && docker-compose restart nginx' >> /var/log/letsencrypt-renew.log 2>&1"
echo ""
echo "Test renewal:"
echo "  sudo certbot renew --dry-run"
echo ""
echo "View certificate details:"
echo "  sudo certbot certificates"
echo ""
echo "==================================================="
