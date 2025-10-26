#!/bin/bash

# =============================================================================
# Comprehensive Audit Logging Plugin Test Runner
# =============================================================================
# This script runs all test suites for the audit logging plugin:
# 1. Unit tests (Jest)
# 2. Automated integration tests (test-audit-logging.sh)
# 3. Manual test scenarios (manual-tests.sh)
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Test suite tracking
SUITE_TOTAL=0
SUITE_PASSED=0
SUITE_FAILED=0
SUITE_SKIPPED=0

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print banner
print_banner() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}║       AUDIT LOGGING PLUGIN - COMPREHENSIVE TEST SUITE        ║${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to print test suite result
print_suite_result() {
    SUITE_TOTAL=$((SUITE_TOTAL + 1))
    if [ "$2" = "PASS" ]; then
        echo -e "${GREEN}✓ TEST SUITE $SUITE_TOTAL: $1 - PASSED${NC}"
        SUITE_PASSED=$((SUITE_PASSED + 1))
    elif [ "$2" = "SKIP" ]; then
        echo -e "${YELLOW}⊘ TEST SUITE $SUITE_TOTAL: $1 - SKIPPED${NC}"
        SUITE_SKIPPED=$((SUITE_SKIPPED + 1))
        if [ ! -z "$3" ]; then
            echo -e "${YELLOW}  Reason: $3${NC}"
        fi
    else
        echo -e "${RED}✗ TEST SUITE $SUITE_TOTAL: $1 - FAILED${NC}"
        SUITE_FAILED=$((SUITE_FAILED + 1))
        if [ ! -z "$3" ]; then
            echo -e "${RED}  Error: $3${NC}"
        fi
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    local missing_deps=()
    
    # Check for required commands
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if ! command -v yarn &> /dev/null; then
        missing_deps+=("yarn")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq (for JSON parsing)")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${RED}  - $dep${NC}"
        done
        echo ""
        echo -e "${YELLOW}Please install missing dependencies and try again.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
    
    # Check if we're in the correct directory
    if [ ! -f "$SCRIPT_DIR/package.json" ]; then
        echo -e "${RED}Error: Not in Strapi monorepo root directory${NC}"
        exit 1
    fi
    
    # Check if audit logging plugin exists
    if [ ! -d "$SCRIPT_DIR/packages/plugins/audit-logging" ]; then
        echo -e "${RED}Error: Audit logging plugin not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Directory structure validated${NC}"
}

# Function to run unit tests
run_unit_tests() {
    print_section "TEST SUITE 1: UNIT TESTS (Jest)"
    
    echo -e "${YELLOW}Running Jest unit tests for audit-logging plugin...${NC}"
    echo ""
    
    cd "$SCRIPT_DIR/packages/plugins/audit-logging"
    
    # Run tests and capture output
    TEST_OUTPUT=$(yarn test:unit 2>&1)
    TEST_EXIT_CODE=$?
    
    # Check if no tests were found
    if echo "$TEST_OUTPUT" | grep -q "No tests found"; then
        echo -e "${YELLOW}No unit tests found in the audit-logging plugin${NC}"
        echo -e "${YELLOW}Consider adding tests in: packages/plugins/audit-logging/server/src/__tests__/${NC}"
        print_suite_result "Unit Tests (Jest)" "SKIP" "No tests found"
        cd "$SCRIPT_DIR"
        return 0
    fi
    
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        echo "$TEST_OUTPUT"
        print_suite_result "Unit Tests (Jest)" "PASS"
        cd "$SCRIPT_DIR"
        return 0
    else
        echo "$TEST_OUTPUT"
        print_suite_result "Unit Tests (Jest)" "FAIL" "Jest tests failed"
        cd "$SCRIPT_DIR"
        return 1
    fi
}

# Function to check if Strapi server is running
check_server_running() {
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:1337" 2>&1)
    # Strapi returns various codes when running: 200, 302 (redirect), 401, 403, 404
    if echo "$HTTP_CODE" | grep -q "200\|302\|404\|401\|403"; then
        return 0
    else
        return 1
    fi
}

# Function to get authentication token
get_auth_token() {
    # Check if JWT or API_TOKEN is already set
    if [ ! -z "$JWT" ]; then
        echo -e "${GREEN}✓ Using JWT token from environment${NC}"
        export JWT="$JWT"
        return 0
    fi
    
    if [ ! -z "$API_TOKEN" ]; then
        echo -e "${GREEN}✓ Using API token from environment${NC}"
        export JWT="$API_TOKEN"
        return 0
    fi
    
    # Try to get JWT from admin login
    echo -e "${YELLOW}Attempting to authenticate with Strapi admin...${NC}"
    
    LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:1337/admin/login" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@strapi.io",
            "password": "Admin123!"
        }' 2>&1)
    
    JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token // empty' 2>/dev/null)
    
    if [ ! -z "$JWT_TOKEN" ] && [ "$JWT_TOKEN" != "null" ]; then
        export JWT="$JWT_TOKEN"
        echo -e "${GREEN}✓ Successfully obtained JWT token${NC}"
        return 0
    else
        # Check if it's an authentication error
        ERROR_MSG=$(echo "$LOGIN_RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
        
        echo -e "${YELLOW}⚠ Could not automatically obtain JWT token${NC}"
        if [ ! -z "$ERROR_MSG" ] && [ "$ERROR_MSG" != "null" ]; then
            echo -e "${YELLOW}  Error: $ERROR_MSG${NC}"
        fi
        echo ""
        echo -e "${YELLOW}To fix this, try one of the following:${NC}"
        echo ""
        echo -e "${YELLOW}1. Register/reset admin user:${NC}"
        echo -e "${YELLOW}   ./register-admin.sh${NC}"
        echo ""
        echo -e "${YELLOW}2. Or export an existing JWT token:${NC}"
        echo -e "${YELLOW}   export JWT='your_jwt_token'${NC}"
        echo ""
        echo -e "${YELLOW}3. Or use an API token:${NC}"
        echo -e "${YELLOW}   export API_TOKEN='your_api_token'${NC}"
        echo ""
        return 1
    fi
}

# Function to run automated integration tests
run_integration_tests() {
    print_section "TEST SUITE 2: AUTOMATED INTEGRATION TESTS"
    
    # Check if server is running
    if ! check_server_running; then
        echo -e "${RED}Error: Strapi server is not running on http://localhost:1337${NC}"
        echo -e "${YELLOW}Please start your Strapi server with: yarn develop${NC}"
        echo -e "${YELLOW}Or run: cd examples/getstarted && yarn develop${NC}"
        print_suite_result "Automated Integration Tests" "SKIP" "Server not running"
        return 1
    fi
    
    echo -e "${GREEN}✓ Strapi server is running${NC}"
    
    # Try to get authentication token
    get_auth_token
    echo ""
    
    if [ -f "$SCRIPT_DIR/test-audit-logging.sh" ]; then
        echo -e "${YELLOW}Running automated integration tests...${NC}"
        echo ""
        
        # Make script executable if not already
        chmod +x "$SCRIPT_DIR/test-audit-logging.sh"
        
        if bash "$SCRIPT_DIR/test-audit-logging.sh"; then
            print_suite_result "Automated Integration Tests" "PASS"
            return 0
        else
            print_suite_result "Automated Integration Tests" "FAIL"
            return 1
        fi
    else
        echo -e "${RED}Error: test-audit-logging.sh not found${NC}"
        print_suite_result "Automated Integration Tests" "FAIL" "Script not found"
        return 1
    fi
}

# Function to run manual tests
run_manual_tests() {
    print_section "TEST SUITE 3: MANUAL TEST SCENARIOS"
    
    # Check if server is running
    if ! check_server_running; then
        echo -e "${RED}Error: Strapi server is not running on http://localhost:1337${NC}"
        echo -e "${YELLOW}Please start your Strapi server with: yarn develop${NC}"
        print_suite_result "Manual Test Scenarios" "SKIP" "Server not running"
        return 1
    fi
    
    # Try to get authentication token if not already obtained
    if [ -z "$JWT" ]; then
        get_auth_token
        echo ""
    fi
    
    if [ -f "$SCRIPT_DIR/manual-tests.sh" ]; then
        echo -e "${YELLOW}Running manual test scenarios...${NC}"
        echo ""
        
        # Make script executable if not already
        chmod +x "$SCRIPT_DIR/manual-tests.sh"
        
        if bash "$SCRIPT_DIR/manual-tests.sh"; then
            print_suite_result "Manual Test Scenarios" "PASS"
            return 0
        else
            print_suite_result "Manual Test Scenarios" "FAIL"
            return 1
        fi
    else
        echo -e "${RED}Error: manual-tests.sh not found${NC}"
        print_suite_result "Manual Test Scenarios" "FAIL" "Script not found"
        return 1
    fi
}

# Function to print final summary
print_summary() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}║                      TEST SUMMARY                             ║${NC}"
    echo -e "${MAGENTA}║                                                               ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Total Test Suites: ${SUITE_TOTAL}"
    echo -e "${GREEN}Passed: ${SUITE_PASSED}${NC}"
    echo -e "${YELLOW}Skipped: ${SUITE_SKIPPED}${NC}"
    echo -e "${RED}Failed: ${SUITE_FAILED}${NC}"
    echo ""
    
    if [ "$SUITE_FAILED" -eq 0 ] && [ "$SUITE_PASSED" -gt 0 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                               ║${NC}"
        echo -e "${GREEN}║        ✓ ALL TEST SUITES PASSED SUCCESSFULLY! ✓              ║${NC}"
        echo -e "${GREEN}║                                                               ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        if [ "$SUITE_SKIPPED" -gt 0 ]; then
            echo -e "${YELLOW}Note: Some test suites were skipped.${NC}"
        fi
        exit 0
    elif [ "$SUITE_FAILED" -eq 0 ] && [ "$SUITE_PASSED" -eq 0 ]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                                                               ║${NC}"
        echo -e "${YELLOW}║          ⊘ ALL TEST SUITES WERE SKIPPED ⊘                    ║${NC}"
        echo -e "${YELLOW}║                                                               ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}No tests were executed. Please check the requirements.${NC}"
        exit 0
    else
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                               ║${NC}"
        echo -e "${RED}║          ✗ SOME TEST SUITES FAILED ✗                         ║${NC}"
        echo -e "${RED}║                                                               ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Please review the output above for details.${NC}"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run comprehensive test suite for the Audit Logging plugin."
    echo ""
    echo "Options:"
    echo "  --unit-only           Run only unit tests"
    echo "  --integration-only    Run only integration tests"
    echo "  --manual-only         Run only manual test scenarios"
    echo "  --skip-unit           Skip unit tests"
    echo "  --skip-integration    Skip integration tests"
    echo "  --skip-manual         Skip manual test scenarios"
    echo "  --help                Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Unit tests: No prerequisites (can run standalone)"
    echo "  - Integration/Manual tests: Requires Strapi server running on http://localhost:1337"
    echo ""
    echo "Authentication:"
    echo "  The script will automatically attempt to authenticate with:"
    echo "    Email: admin@strapi.io"
    echo "    Password: Admin123!"
    echo ""
    echo "  Or you can set authentication manually:"
    echo "    export JWT='your_jwt_token'"
    echo "    export API_TOKEN='your_api_token'"
    echo ""
    echo "To start the Strapi server:"
    echo "  cd examples/getstarted && yarn develop"
    echo ""
    echo "Examples:"
    echo "  $0                              # Run all tests"
    echo "  $0 --unit-only                  # Run only unit tests (no server needed)"
    echo "  $0 --skip-unit                  # Run integration and manual tests only"
    echo "  $0 --integration-only           # Run only integration tests"
    echo ""
}

# Main function
main() {
    # Parse command line arguments
    RUN_UNIT=true
    RUN_INTEGRATION=true
    RUN_MANUAL=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit-only)
                RUN_INTEGRATION=false
                RUN_MANUAL=false
                shift
                ;;
            --integration-only)
                RUN_UNIT=false
                RUN_MANUAL=false
                shift
                ;;
            --manual-only)
                RUN_UNIT=false
                RUN_INTEGRATION=false
                shift
                ;;
            --skip-unit)
                RUN_UNIT=false
                shift
                ;;
            --skip-integration)
                RUN_INTEGRATION=false
                shift
                ;;
            --skip-manual)
                RUN_MANUAL=false
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Print banner
    print_banner
    
    # Check prerequisites
    check_prerequisites
    
    # Track start time
    START_TIME=$(date +%s)
    
    # Run test suites based on flags
    if [ "$RUN_UNIT" = true ]; then
        run_unit_tests
    fi
    
    if [ "$RUN_INTEGRATION" = true ]; then
        run_integration_tests
    fi
    
    if [ "$RUN_MANUAL" = true ]; then
        run_manual_tests
    fi
    
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    echo -e "${CYAN}Total execution time: ${DURATION} seconds${NC}"
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
