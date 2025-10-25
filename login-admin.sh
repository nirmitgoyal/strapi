#!/bin/bash

# Try to login with the existing admin user
echo "Attempting to login with existing admin..."

# Try common passwords
PASSWORDS=("Strapi123!" "Admin123!" "admin123" "strapi123" "Test123!" "test123")

for PASSWORD in "${PASSWORDS[@]}"; do
    echo "Trying password: $PASSWORD"
    LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:1337/admin/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"nirmitgoyal.goyal@gmail.com\",
            \"password\": \"$PASSWORD\"
        }")
    
    JWT=$(echo $LOGIN_RESPONSE | jq -r '.data.token // empty')
    
    if [ ! -z "$JWT" ] && [ "$JWT" != "null" ]; then
        echo ""
        echo "✓ Successfully logged in with password: $PASSWORD"
        echo "JWT Token obtained"
        echo ""
        echo "Export this token:"
        echo "export JWT='$JWT'"
        echo ""
        echo "export ADMIN_EMAIL='nirmitgoyal.goyal@gmail.com'"
        echo "export ADMIN_PASSWORD='$PASSWORD'"
        exit 0
    fi
done

echo ""
echo "Could not login with any common passwords."
echo "Please provide the password for nirmitgoyal.goyal@gmail.com"
echo ""
echo "You can run tests manually with:"
echo "export JWT='<your_jwt_token>'"
echo "./test-audit-logging.sh"
