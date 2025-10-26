#!/bin/bash

# Setup script to create a fresh admin user with known credentials
# This resets the database and creates an admin for testing

set -e

echo "🔄 Setting up fresh Strapi instance for testing..."
echo ""

# Navigate to the test Strapi instance
cd examples/getstarted

echo "1. Stopping any running Strapi instances..."
pkill -f "strapi develop" 2>/dev/null || true
sleep 2

echo "2. Backing up and resetting database..."
if [ -f ".tmp/data.db" ]; then
    cp .tmp/data.db .tmp/data.db.backup.$(date +%s) 2>/dev/null || true
    rm .tmp/data.db
    echo "   ✓ Database reset"
else
    echo "   ✓ No existing database found"
fi

echo "3. Starting Strapi in background..."
yarn develop > /tmp/strapi-dev.log 2>&1 &
STRAPI_PID=$!
echo "   ✓ Strapi started (PID: $STRAPI_PID)"

echo "4. Waiting for Strapi to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:1337 > /dev/null 2>&1; then
        echo "   ✓ Strapi is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "   ✗ Timeout waiting for Strapi"
        kill $STRAPI_PID 2>/dev/null || true
        exit 1
    fi
    sleep 2
    echo "   Waiting... ($i/30)"
done

cd ../..

echo "5. Registering admin user..."
RESPONSE=$(curl -s -X POST "http://localhost:1337/admin/register-admin" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "admin@strapi.io",
        "firstname": "Admin",
        "lastname": "User",
        "password": "Admin123!"
    }')

JWT=$(echo $RESPONSE | jq -r '.data.token // empty')

if [ ! -z "$JWT" ] && [ "$JWT" != "null" ]; then
    echo "   ✓ Admin user created successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "Admin credentials:"
    echo "  Email: admin@strapi.io"
    echo "  Password: Admin123!"
    echo ""
    echo "JWT Token:"
    echo "  $JWT"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Export the token:"
    echo "  export JWT='$JWT'"
    echo ""
    echo "Or run tests directly:"
    echo "  JWT='$JWT' ./run-all-audit-tests.sh"
    echo ""
    echo "Strapi is running in background (PID: $STRAPI_PID)"
    echo "View logs: tail -f /tmp/strapi-dev.log"
    echo "Stop it: kill $STRAPI_PID"
    echo ""
else
    echo "   ✗ Failed to create admin user"
    echo ""
    echo "Response:"
    echo $RESPONSE | jq '.'
    kill $STRAPI_PID 2>/dev/null || true
    exit 1
fi
