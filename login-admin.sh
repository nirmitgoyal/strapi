#!/bin/bash

# Try to login with the existing admin user
echo "Attempting to login with admin user..."

LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:1337/admin/login" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "admin@strapi.io",
        "password": "Admin123!"
    }')

JWT=$(echo $LOGIN_RESPONSE | jq -r '.data.token // empty')

if [ ! -z "$JWT" ] && [ "$JWT" != "null" ]; then
    echo ""
    echo "✓ Successfully logged in!"
    echo "JWT Token obtained"
    echo ""
    echo "Export this token:"
    echo "export JWT='$JWT'"
    echo ""
    echo "You can now run tests with:"
    echo "./test-audit-logging.sh"
else
    echo ""
    echo "❌ Login failed."
    echo "Response:"
    echo $LOGIN_RESPONSE | jq '.'
    echo ""
    echo "Make sure you've registered the admin user first:"
    echo "./register-admin.sh"
fi
