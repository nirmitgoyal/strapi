#!/bin/bash

# Manual tests for audit logging feature
# Run this script after setting: export JWT="YOUR_JWT_TOKEN"
# Or the run-all-audit-tests.sh script will set it automatically

# Use JWT from environment if available, otherwise use TOKEN if set
if [ ! -z "$JWT" ]; then
    TOKEN="Bearer $JWT"
elif [ -z "$TOKEN" ]; then
    echo "Error: No authentication token found"
    echo "Please set JWT environment variable:"
    echo "  export JWT='your_jwt_token'"
    exit 1
fi

BASE_URL="http://localhost:1337"

echo "=== TEST 1: Check server is running ==="
curl -s -I "$BASE_URL/api/articles" | head -2
echo ""

echo "=== TEST 2: Get initial audit log count ==="
INITIAL=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Initial count: $INITIAL"
echo ""

echo "=== TEST 3: Create an article ==="
CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/articles" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "data": {
            "title": "Test Article for Audit",
            "description": "Testing audit logging",
            "content": "Test content"
        }
    }')

ARTICLE_ID=$(echo $CREATE_RESPONSE | jq -r '.data.id // .data.documentId // empty')
echo "Created article with ID: $ARTICLE_ID"
echo ""

sleep 2

echo "=== TEST 4: Check audit log was created ==="
COUNT_AFTER_CREATE=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Count after create: $COUNT_AFTER_CREATE"
if [ "$COUNT_AFTER_CREATE" -gt "$INITIAL" ]; then
    echo "✓ CREATE action logged"
else
    echo "✗ CREATE action NOT logged"
fi
echo ""

echo "=== TEST 5: Get the latest audit log entry ==="
LATEST_LOG=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "sort=timestamp:desc" --data-urlencode "pagination[pageSize]=1" | jq '.data[0]')
echo "$LATEST_LOG" | jq '.'
echo ""

echo "=== TEST 6: Verify log fields ==="
echo "Content Type: $(echo $LATEST_LOG | jq -r '.contentType')"
echo "Record ID: $(echo $LATEST_LOG | jq -r '.recordId')"
echo "Action: $(echo $LATEST_LOG | jq -r '.action')"
echo "Timestamp: $(echo $LATEST_LOG | jq -r '.timestamp')"
echo "User: $(echo $LATEST_LOG | jq -r '.userDisplayName')"
echo ""

echo "=== TEST 7: Update the article ==="
curl -s -X PUT "$BASE_URL/api/articles/$ARTICLE_ID" \
    -H "Authorization: $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "data": {
            "title": "Updated Test Article",
            "description": "Updated description"
        }
    }' > /dev/null

sleep 2

echo "=== TEST 8: Check UPDATE was logged ==="
COUNT_AFTER_UPDATE=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Count after update: $COUNT_AFTER_UPDATE"
if [ "$COUNT_AFTER_UPDATE" -gt "$COUNT_AFTER_CREATE" ]; then
    echo "✓ UPDATE action logged"
else
    echo "✗ UPDATE action NOT logged"
fi
echo ""

echo "=== TEST 9: Delete the article ==="
curl -s -X DELETE "$BASE_URL/api/articles/$ARTICLE_ID" \
    -H "Authorization: $TOKEN" > /dev/null

sleep 2

echo "=== TEST 10: Check DELETE was logged ==="
COUNT_AFTER_DELETE=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Count after delete: $COUNT_AFTER_DELETE"
if [ "$COUNT_AFTER_DELETE" -gt "$COUNT_AFTER_UPDATE" ]; then
    echo "✓ DELETE action logged"
else
    echo "✗ DELETE action NOT logged"
fi
echo ""

echo "=== TEST 11: Filter by action type ==="
CREATE_LOGS=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "filters[action][\$eq]=create" --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Create logs count: $CREATE_LOGS"
if [ "$CREATE_LOGS" -gt 0 ]; then
    echo "✓ Filtering by action works"
else
    echo "✗ Filtering by action failed"
fi
echo ""

echo "=== TEST 12: Filter by content type ==="
ARTICLE_LOGS=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "filters[contentType][\$contains]=article" --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Article logs count: $ARTICLE_LOGS"
if [ "$ARTICLE_LOGS" -gt 0 ]; then
    echo "✓ Filtering by content type works"
else
    echo "✗ Filtering by content type failed"
fi
echo ""

echo "=== TEST 13: Test pagination ==="
PAGE1=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "pagination[page]=1" --data-urlencode "pagination[pageSize]=2" | jq '.data | length')
echo "Page 1 items: $PAGE1"
if [ "$PAGE1" -gt 0 ]; then
    echo "✓ Pagination works"
else
    echo "✗ Pagination failed"
fi
echo ""

echo "=== TEST 14: Test access control (no token) ==="
NO_AUTH=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -G --data-urlencode "pagination[pageSize]=1" | jq -r '.error // empty')
if [ ! -z "$NO_AUTH" ]; then
    echo "✓ Access control works (denied without token)"
else
    echo "✗ Access control failed (should require authentication)"
fi
echo ""

echo "=== TEST 15: Test date range filter ==="
TODAY=$(date -u +"%Y-%m-%d")
TODAY_LOGS=$(curl -s "$BASE_URL/api/audit-logging/audit-logs" -H "Authorization: $TOKEN" -G --data-urlencode "filters[timestamp][\$gte]=$TODAY" --data-urlencode "pagination[pageSize]=1" | jq -r '.meta.pagination.total // 0')
echo "Logs for today: $TODAY_LOGS"
if [ "$TODAY_LOGS" -gt 0 ]; then
    echo "✓ Date range filtering works"
else
    echo "✗ Date range filtering failed"
fi
echo ""

echo "=== All manual tests completed ==="
