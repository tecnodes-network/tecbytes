#!/bin/bash
# in case of caddy this script checks the expiry date of the certificates and copies them from the caddy dir to the local dir where rbbc has access to

# Variables
LOCAL_CERT_FOLDER="~/redbellynetwork/certs"
SOURCE_CERT_FOLDER="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/your_domain"
CERT_FILE="rbn.xx.crt"
KEY_FILE="rbn.xx.key"
DAYS_THRESHOLD=${1:-3}  # Default to 3 days if not provided
DISCORD_WEBHOOK="https://discord.com/api/webhooks/xxxx/xxxxx"

# Function to send a Discord notification
send_discord_notification() {
    local expiry_date=$1
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"# Redbelly-certs: \`on Server\`\n \`cert copied, new expiry date:\` <t:$expiry_timestamp>\"}" $DISCORD_WEBHOOK
}

# Check certificate expiry in the local cert folder
expiry_date=$(openssl x509 -enddate -noout -in "$LOCAL_CERT_FOLDER/$CERT_FILE" | cut -d= -f2)
expiry_seconds=$(date -d "$expiry_date" +%s)
current_seconds=$(date +%s)
days_to_expiry=$(( (expiry_seconds - current_seconds) / 86400 ))

# Check if the certificate is expiring within the threshold
if [ $days_to_expiry -le $DAYS_THRESHOLD ]; then
    # Copy the certificate and key
    sudo cp "$SOURCE_CERT_FOLDER/$CERT_FILE" "$LOCAL_CERT_FOLDER/"
    sudo cp "$SOURCE_CERT_FOLDER/$KEY_FILE" "$LOCAL_CERT_FOLDER/"

    # Send a notification
    expiry_date=$(openssl x509 -enddate -noout -in "$LOCAL_CERT_FOLDER/$CERT_FILE" | cut -d= -f2)
    expiry_timestamp=$(date -d "$expiry_date" +%s)
    send_discord_notification "$expiry_date"
else
    # Print message if not expiring within the threshold
    echo "Certificates are not expiring within the threshold."
    echo "Expiry date: $expiry_date"
    echo "Days left to expire: $days_to_expiry"
fi
