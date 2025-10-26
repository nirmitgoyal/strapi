#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API Base URL
BASE_URL="http://localhost:1337"
API_URL="${BASE_URL}/api"
ADMIN_URL="${BASE_URL}/admin"
AUDIT_LOG_BASE="${BASE_URL}/audit-logging/audit-logs"

AUTH_HEADER=""

normalize_token() {
    local token="$1"
    token="${token#Bearer }"
    token="${token#bearer }"
    token="$(printf '%s' "$token" | tr -d '\r' | xargs)"
    echo "$token"
}

set_auth_header() {
    local raw_token="$1"
    local normalized
    normalized=$(normalize_token "$raw_token")

    if [ -z "$normalized" ]; then
        AUTH_HEADER=""
        JWT=""
        return 1
    fi

    JWT="$normalized"
    AUTH_HEADER="Authorization: Bearer $normalized"
    return 0
}

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print test header
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print test result
print_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$2" = "PASS" ]; then
        echo -e "${GREEN}✓ TEST $TOTAL_TESTS: $1${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ TEST $TOTAL_TESTS: $1${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ ! -z "$3" ]; then
            echo -e "${RED}  Error: $3${NC}"
        fi
    fi
}

# Function to get admin JWT token
get_admin_token() {
    echo -e "${YELLOW}Getting authentication token...${NC}"
    
    # First, try using API token from environment
    if [ ! -z "$API_TOKEN" ]; then
        if set_auth_header "$API_TOKEN"; then
            echo -e "${GREEN}Using API token from environment${NC}"
            return 0
        fi
    fi
    
    # Try to use JWT from environment
    if [ ! -z "$JWT" ]; then
        local existing_token="$JWT"
        if set_auth_header "$existing_token"; then
            echo -e "${GREEN}Using JWT token from environment${NC}"
            return 0
        fi
    fi
    
    # Try to login with default admin credentials
    RESPONSE=$(curl -s -X POST "${ADMIN_URL}/login" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@strapi.io",
            "password": "Admin123!"
        }')
    
    local token
    token=$(echo "$RESPONSE" | jq -r '.data.token // empty')
    
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo -e "${RED}Failed to get JWT token.${NC}"
        echo -e "${YELLOW}Please set JWT or API_TOKEN environment variable:${NC}"
        echo -e "${YELLOW}  export JWT='your_jwt_token'${NC}"
        echo -e "${YELLOW}  export API_TOKEN='your_api_token'${NC}"
        echo -e "${YELLOW}Or ensure Strapi admin credentials are correct${NC}"
        exit 1
    fi
    
    set_auth_header "$token"
    echo -e "${GREEN}Successfully obtained JWT token${NC}"
}

# Function to check if audit logging plugin is loaded
check_plugin_loaded() {
    print_header "TEST 1: PLUGIN INITIALIZATION"
    
    # Try to access the audit logs endpoint to check if server is running
    local curl_args=(-s -o /dev/null -w "%{http_code}" "${AUDIT_LOG_BASE}?pagination%5BpageSize%5D=1")
    if [ -n "$AUTH_HEADER" ]; then
        curl_args+=(-H "$AUTH_HEADER")
    fi

    RESPONSE=$(curl "${curl_args[@]}")
    
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "403" ]; then
        print_test "Strapi server is running" "PASS"
    else
        print_test "Strapi server is running" "FAIL" "Server returned HTTP $RESPONSE"
        exit 1
    fi
}

# Function to create a test content type entry
create_article() {
    # Use Content Manager API (admin route) with correct article schema fields
    RESPONSE=$(curl -s -X POST "${BASE_URL}/admin/content-manager/collection-types/api::article.article" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d '{
            "title": "Test Article for Audit Log",
            "authorName": "Test Author"
        }')
    
    # Try to get ID from different possible response structures
    ARTICLE_ID=$(echo "$RESPONSE" | jq -r '.data.id // .data.documentId // .id // .documentId // empty' 2>/dev/null)
    echo "$ARTICLE_ID"
}

# Function to update an article
update_article() {
    ARTICLE_ID=$1
    RESPONSE=$(curl -s -X PUT "${BASE_URL}/admin/content-manager/collection-types/api::article.article/${ARTICLE_ID}" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d '{
            "title": "Updated Test Article",
            "authorName": "Updated Author"
        }')
    echo "$RESPONSE"
}

# Function to delete an article
delete_article() {
    ARTICLE_ID=$1
    RESPONSE=$(curl -s -X DELETE "${BASE_URL}/admin/content-manager/collection-types/api::article.article/${ARTICLE_ID}" \
        -H "$AUTH_HEADER")
    echo "$RESPONSE"
}

# Function to get audit logs
get_audit_logs() {
    QUERY=$1
    local url="${AUDIT_LOG_BASE}${QUERY}"
    local curl_cmd=(curl -s "$url")
    if [ -n "$AUTH_HEADER" ]; then
        curl_cmd+=(-H "$AUTH_HEADER")
    fi
    RESPONSE=$(timeout 10 "${curl_cmd[@]}" 2>/dev/null || echo '{"data":[],"meta":{"pagination":{"total":0}}}')
    echo "$RESPONSE"
}

# Function to test automatic log creation
test_automatic_logging() {
    print_header "TEST 2: AUTOMATIC AUDIT LOG CREATION"
    
    # Refresh token to ensure it's valid
    echo -e "${YELLOW}Refreshing authentication token...${NC}"
    RESPONSE=$(curl -s -X POST "${ADMIN_URL}/login" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@strapi.io",
            "password": "Admin123!"
        }')
    
    local refreshed_token
    refreshed_token=$(echo "$RESPONSE" | jq -r '.data.token // empty')
    
    if [ -z "$refreshed_token" ] || [ "$refreshed_token" = "null" ]; then
        print_test "Refresh authentication token" "FAIL" "Could not refresh token"
        return
    fi
    
    set_auth_header "$refreshed_token"
    
    # Get initial count
    INITIAL_LOGS=$(get_audit_logs "?pagination[pageSize]=1")
    INITIAL_COUNT=$(echo "$INITIAL_LOGS" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure INITIAL_COUNT is a valid number
    if ! [[ "$INITIAL_COUNT" =~ ^[0-9]+$ ]]; then
        INITIAL_COUNT=0
    fi
    
    echo "Initial audit log count: $INITIAL_COUNT"
    
    # Create an article
    echo -e "${YELLOW}Creating test article...${NC}"
    ARTICLE_ID=$(create_article)
    
    if [ -z "$ARTICLE_ID" ] || [ "$ARTICLE_ID" = "null" ]; then
        print_test "Create operation generates audit log" "FAIL" "Failed to create article"
        return
    fi
    
    echo "Created article with ID: $ARTICLE_ID"
    sleep 1
    
    # Check if audit log was created
    LOGS_AFTER_CREATE=$(get_audit_logs "?pagination[pageSize]=1")
    COUNT_AFTER_CREATE=$(echo "$LOGS_AFTER_CREATE" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure COUNT_AFTER_CREATE is a valid number
    if ! [[ "$COUNT_AFTER_CREATE" =~ ^[0-9]+$ ]]; then
        COUNT_AFTER_CREATE=0
    fi
    
    if [ "$COUNT_AFTER_CREATE" -gt "$INITIAL_COUNT" ]; then
        print_test "Create operation generates audit log" "PASS"
    else
        print_test "Create operation generates audit log" "FAIL" "Count did not increase"
    fi
    
    # Update the article
    echo -e "${YELLOW}Updating test article...${NC}"
    update_article "$ARTICLE_ID" > /dev/null
    sleep 1
    
    LOGS_AFTER_UPDATE=$(get_audit_logs "?pagination[pageSize]=1")
    COUNT_AFTER_UPDATE=$(echo "$LOGS_AFTER_UPDATE" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure COUNT_AFTER_UPDATE is a valid number
    if ! [[ "$COUNT_AFTER_UPDATE" =~ ^[0-9]+$ ]]; then
        COUNT_AFTER_UPDATE=0
    fi
    
    if [ "$COUNT_AFTER_UPDATE" -gt "$COUNT_AFTER_CREATE" ]; then
        print_test "Update operation generates audit log" "PASS"
    else
        print_test "Update operation generates audit log" "FAIL"
    fi
    
    # Delete the article
    echo -e "${YELLOW}Deleting test article...${NC}"
    delete_article "$ARTICLE_ID" > /dev/null
    sleep 1
    
    LOGS_AFTER_DELETE=$(get_audit_logs "?pagination[pageSize]=1")
    COUNT_AFTER_DELETE=$(echo "$LOGS_AFTER_DELETE" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure COUNT_AFTER_DELETE is a valid number
    if ! [[ "$COUNT_AFTER_DELETE" =~ ^[0-9]+$ ]]; then
        COUNT_AFTER_DELETE=0
    fi
    
    if [ "$COUNT_AFTER_DELETE" -gt "$COUNT_AFTER_UPDATE" ]; then
        print_test "Delete operation generates audit log" "PASS"
    else
        print_test "Delete operation generates audit log" "FAIL"
    fi
    
    echo "$ARTICLE_ID"
}

# Function to test log entry fields
test_log_fields() {
    print_header "TEST 3: LOG ENTRY FIELDS"
    
    # Get the latest audit log
    LATEST_LOG=$(get_audit_logs "?sort=timestamp:desc&pagination[pageSize]=1")
    FIRST_LOG=$(echo $LATEST_LOG | jq -r '.data[0] // empty')
    
    if [ -z "$FIRST_LOG" ] || [ "$FIRST_LOG" = "null" ]; then
        print_test "Retrieve audit log entry" "FAIL" "No audit logs found"
        return
    fi
    
    print_test "Retrieve audit log entry" "PASS"
    
    # Check required fields
    CONTENT_TYPE=$(echo $FIRST_LOG | jq -r '.contentType // empty')
    if [ ! -z "$CONTENT_TYPE" ] && [ "$CONTENT_TYPE" != "null" ]; then
        print_test "Field 'contentType' exists" "PASS"
    else
        print_test "Field 'contentType' exists" "FAIL"
    fi
    
    RECORD_ID=$(echo $FIRST_LOG | jq -r '.recordId // empty')
    if [ ! -z "$RECORD_ID" ] && [ "$RECORD_ID" != "null" ]; then
        print_test "Field 'recordId' exists" "PASS"
    else
        print_test "Field 'recordId' exists" "FAIL"
    fi
    
    ACTION=$(echo $FIRST_LOG | jq -r '.action // empty')
    if [ ! -z "$ACTION" ] && [ "$ACTION" != "null" ]; then
        print_test "Field 'action' exists (value: $ACTION)" "PASS"
    else
        print_test "Field 'action' exists" "FAIL"
    fi
    
    TIMESTAMP=$(echo $FIRST_LOG | jq -r '.timestamp // empty')
    if [ ! -z "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
        print_test "Field 'timestamp' exists" "PASS"
    else
        print_test "Field 'timestamp' exists" "FAIL"
    fi
    
    USER_DISPLAY_NAME=$(echo $FIRST_LOG | jq -r '.userDisplayName // empty')
    if [ ! -z "$USER_DISPLAY_NAME" ] && [ "$USER_DISPLAY_NAME" != "null" ]; then
        print_test "Field 'userDisplayName' exists (value: $USER_DISPLAY_NAME)" "PASS"
    else
        print_test "Field 'userDisplayName' exists" "FAIL"
    fi
    
    # Check for payload or changedFields based on action
    if [ "$ACTION" = "create" ] || [ "$ACTION" = "delete" ]; then
        PAYLOAD=$(echo $FIRST_LOG | jq -r '.payload // empty')
        if [ ! -z "$PAYLOAD" ] && [ "$PAYLOAD" != "null" ]; then
            print_test "Field 'payload' exists for $ACTION action" "PASS"
        else
            print_test "Field 'payload' exists for $ACTION action" "FAIL"
        fi
    elif [ "$ACTION" = "update" ]; then
        CHANGED_FIELDS=$(echo $FIRST_LOG | jq -r '.changedFields // empty')
        if [ ! -z "$CHANGED_FIELDS" ] && [ "$CHANGED_FIELDS" != "null" ]; then
            print_test "Field 'changedFields' exists for update action" "PASS"
        else
            print_test "Field 'changedFields' exists for update action" "FAIL"
        fi
    fi
}

# Function to test filtering
test_filtering() {
    print_header "TEST 4: REST API FILTERING"
    
    # Test filter by action type
    CREATE_LOGS=$(get_audit_logs "?filters[action][\$eq]=create&pagination[pageSize]=1")
    CREATE_COUNT=$(echo "$CREATE_LOGS" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure CREATE_COUNT is a valid number
    if ! [[ "$CREATE_COUNT" =~ ^[0-9]+$ ]]; then
        CREATE_COUNT=0
    fi
    
    if [ "$CREATE_COUNT" -gt 0 ]; then
        FIRST_ACTION=$(echo $CREATE_LOGS | jq -r '.data[0].action // empty')
        if [ "$FIRST_ACTION" = "create" ]; then
            print_test "Filter by action type (create)" "PASS"
        else
            print_test "Filter by action type (create)" "FAIL" "Action mismatch: $FIRST_ACTION"
        fi
    else
        print_test "Filter by action type (create)" "FAIL" "No results"
    fi
    
    # Test filter by content type
    ARTICLE_LOGS=$(get_audit_logs "?filters[contentType][\$contains]=article&pagination[pageSize]=1")
    ARTICLE_COUNT=$(echo "$ARTICLE_LOGS" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure ARTICLE_COUNT is a valid number
    if ! [[ "$ARTICLE_COUNT" =~ ^[0-9]+$ ]]; then
        ARTICLE_COUNT=0
    fi
    
    if [ "$ARTICLE_COUNT" -gt 0 ]; then
        FIRST_CONTENT_TYPE=$(echo $ARTICLE_LOGS | jq -r '.data[0].contentType // empty')
        if echo "$FIRST_CONTENT_TYPE" | grep -q "article"; then
            print_test "Filter by content type" "PASS"
        else
            print_test "Filter by content type" "FAIL"
        fi
    else
        print_test "Filter by content type" "FAIL" "No results"
    fi
    
    # Test date range filter
    TODAY=$(date -u +"%Y-%m-%d")
    DATE_LOGS=$(get_audit_logs "?filters[timestamp][\$gte]=${TODAY}&pagination[pageSize]=1")
    DATE_COUNT=$(echo "$DATE_LOGS" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure DATE_COUNT is a valid number
    if ! [[ "$DATE_COUNT" =~ ^[0-9]+$ ]]; then
        DATE_COUNT=0
    fi
    
    if [ "$DATE_COUNT" -gt 0 ]; then
        print_test "Filter by date range" "PASS"
    else
        print_test "Filter by date range" "FAIL" "No results for today"
    fi
}

# Function to test pagination and sorting
test_pagination_sorting() {
    print_header "TEST 5: PAGINATION AND SORTING"
    
    # Test pagination
    PAGE1=$(get_audit_logs "?pagination[page]=1&pagination[pageSize]=2")
    PAGE1_COUNT=$(echo "$PAGE1" | jq -r '.data | length' 2>/dev/null || echo "0")
    
    # Ensure PAGE1_COUNT is a valid number
    if ! [[ "$PAGE1_COUNT" =~ ^[0-9]+$ ]]; then
        PAGE1_COUNT=0
    fi
    
    if [ "$PAGE1_COUNT" -gt 0 ]; then
        print_test "Pagination works (page 1)" "PASS"
    else
        print_test "Pagination works (page 1)" "FAIL"
    fi
    
    # Test sorting by timestamp descending
    SORTED_DESC=$(get_audit_logs "?sort=timestamp:desc&pagination[pageSize]=2")
    FIRST_TIMESTAMP=$(echo $SORTED_DESC | jq -r '.data[0].timestamp // empty')
    SECOND_TIMESTAMP=$(echo $SORTED_DESC | jq -r '.data[1].timestamp // empty')
    
    if [ ! -z "$FIRST_TIMESTAMP" ] && [ ! -z "$SECOND_TIMESTAMP" ]; then
        if [[ "$FIRST_TIMESTAMP" > "$SECOND_TIMESTAMP" ]] || [[ "$FIRST_TIMESTAMP" == "$SECOND_TIMESTAMP" ]]; then
            print_test "Sorting by timestamp:desc" "PASS"
        else
            print_test "Sorting by timestamp:desc" "FAIL"
        fi
    else
        print_test "Sorting by timestamp:desc" "FAIL" "Insufficient data"
    fi
    
    # Check pagination metadata
    TOTAL=$(echo "$PAGE1" | jq -r '.meta.pagination.total // 0' 2>/dev/null || echo "0")
    PAGE=$(echo "$PAGE1" | jq -r '.meta.pagination.page // 0' 2>/dev/null || echo "0")
    PAGE_SIZE=$(echo "$PAGE1" | jq -r '.meta.pagination.pageSize // 0' 2>/dev/null || echo "0")
    
    # Ensure values are valid numbers
    if ! [[ "$TOTAL" =~ ^[0-9]+$ ]]; then TOTAL=0; fi
    if ! [[ "$PAGE" =~ ^[0-9]+$ ]]; then PAGE=0; fi
    if ! [[ "$PAGE_SIZE" =~ ^[0-9]+$ ]]; then PAGE_SIZE=0; fi
    
    if [ "$TOTAL" -gt 0 ] && [ "$PAGE" -eq 1 ] && [ "$PAGE_SIZE" -eq 2 ]; then
        print_test "Pagination metadata correct" "PASS"
    else
        print_test "Pagination metadata correct" "FAIL"
    fi
}

# Function to test access control
test_access_control() {
    print_header "TEST 6: ACCESS CONTROL"
    
    # Test with valid JWT
    WITH_AUTH=$(get_audit_logs "?pagination[pageSize]=1")
    if echo "$WITH_AUTH" | jq -e '.data' > /dev/null 2>&1; then
        print_test "Access with valid JWT token" "PASS"
    else
        print_test "Access with valid JWT token" "FAIL"
    fi
    
    # Test without JWT (should fail)
    WITHOUT_AUTH=$(curl -s "${AUDIT_LOG_BASE}?pagination[pageSize]=1")
    if echo "$WITHOUT_AUTH" | jq -e '.error' > /dev/null 2>&1; then
        print_test "Access denied without JWT token" "PASS"
    else
        print_test "Access denied without JWT token" "FAIL" "Should require authentication"
    fi
}

# Function to test database storage and indexing
test_database_storage() {
    print_header "TEST 7: DATABASE STORAGE"
    
    # Check that logs are persisted
    ALL_LOGS=$(get_audit_logs "")
    TOTAL_LOGS=$(echo "$ALL_LOGS" | jq -r '.meta.pagination.total // .results // 0' 2>/dev/null || echo "0")
    
    # Ensure TOTAL_LOGS is a valid number
    if ! [[ "$TOTAL_LOGS" =~ ^[0-9]+$ ]]; then
        TOTAL_LOGS=0
    fi
    
    if [ "$TOTAL_LOGS" -gt 0 ]; then
        print_test "Audit logs persisted in database" "PASS"
        echo "  Total logs in database: $TOTAL_LOGS"
    else
        print_test "Audit logs persisted in database" "FAIL"
    fi
}

# Function to print summary
print_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}TEST SUMMARY${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
    
    if [ "$FAILED_TESTS" -eq 0 ]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
    else
        echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting Comprehensive Audit Logging Tests${NC}"
    echo ""
    
    # Get admin token
    get_admin_token
    
    # Run all tests
    check_plugin_loaded
    test_automatic_logging
    test_log_fields
    test_filtering
    test_pagination_sorting
    test_access_control
    test_database_storage
    
    # Print summary
    print_summary
}

# Run main
main
