#!/bin/bash

# Register a new admin user
RESPONSE=$(curl -s -X POST "http://localhost:1337/admin/register-admin" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "admin@strapi.io",
        "firstname": "Admin",
        "lastname": "User",
        "password": "Admin123!"
    }')

# Check if registration failed because admin already exists
ERROR_MESSAGE=$(echo $RESPONSE | jq -r '.error.message // empty')

if [[ "$ERROR_MESSAGE" == *"cannot register a new super admin"* ]]; then
    echo "Admin already registered, attempting to login..."
else
    echo "Registration response:"
    echo $RESPONSE | jq '.'
fi

# Try to login with the credentials
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:1337/admin/login" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "admin@strapi.io",
        "password": "Admin123!"
    }')

JWT=$(echo $LOGIN_RESPONSE | jq -r '.data.token // empty')

if [ ! -z "$JWT" ]; then
    echo ""
    echo "Successfully logged in!"
    echo "JWT Token: $JWT"
    echo ""
    echo "Export this token:"
    echo "export JWT='$JWT'"
else
    echo ""
    echo "Login failed. Trying existing user..."
    echo $LOGIN_RESPONSE | jq '.'
fi
