#!/bin/bash

# Simple script to test and get a working JWT token
# Tries multiple methods to obtain a valid token

BASE_URL="http://localhost:1337"

echo "🔍 Finding valid JWT token..."
echo ""

# Method 1: Check environment
if [ ! -z "$JWT" ]; then
    echo "Testing JWT from environment..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/users/me" \
        -H "Authorization: Bearer $JWT")
    
    if [ "$RESPONSE" = "200" ]; then
        echo "✓ JWT from environment is valid!"
        echo ""
        echo "export JWT='$JWT'"
        exit 0
    fi
fi

# Method 2: Try common credentials
echo "Trying to login with default credentials..."

CREDENTIALS=(
    '{"email":"admin@strapi.io","password":"Admin123!"}'
    '{"email":"admin@example.com","password":"Admin123!"}'
    '{"email":"test@strapi.io","password":"Test123!"}'
)

for cred in "${CREDENTIALS[@]}"; do
    RESPONSE=$(curl -s -X POST "$BASE_URL/admin/login" \
        -H "Content-Type: application/json" \
        -d "$cred")
    
    TOKEN=$(echo $RESPONSE | jq -r '.data.token // empty' 2>/dev/null)
    
    if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        EMAIL=$(echo $cred | jq -r '.email')
        echo "✓ Login successful with: $EMAIL"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "export JWT='$TOKEN'"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Run tests with:"
        echo "  export JWT='$TOKEN'"
        echo "  ./run-all-audit-tests.sh"
        echo ""
        exit 0
    fi
done

# Method 3: Try to create a new admin
echo ""
echo "No valid credentials found. Checking if we can create admin..."

HAS_ADMIN=$(curl -s "$BASE_URL/admin/init" | jq -r '.data.hasAdmin')

if [ "$HAS_ADMIN" = "false" ]; then
    echo "No admin exists. Creating one..."
    
    REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/admin/register-admin" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@strapi.io",
            "firstname": "Admin",
            "lastname": "User",
            "password": "Admin123!"
        }')
    
    TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.data.token // empty' 2>/dev/null)
    
    if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        echo "✓ Admin created successfully!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "export JWT='$TOKEN'"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        exit 0
    fi
fi

# All methods failed
echo ""
echo "❌ Could not obtain a valid JWT token"
echo ""
echo "Manual steps:"
echo ""
echo "1. Reset database (fresh start):"
echo "   rm examples/getstarted/.tmp/data.db"
echo "   cd examples/getstarted && yarn develop"
echo ""
echo "2. Or get token from browser:"
echo "   - Open http://localhost:1337/admin"
echo "   - Login/register"
echo "   - Open DevTools Console (F12)"
echo "   - Run: localStorage.getItem('jwtToken')"
echo "   - Export: export JWT='paste_token_here'"
echo ""
echo "3. Then run: ./run-all-audit-tests.sh"
echo ""

exit 1
