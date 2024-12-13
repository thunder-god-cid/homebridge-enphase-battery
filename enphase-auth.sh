#!/bin/bash

# Configuration
CLIENT_ID="CLIENT-ID-HERE"
CLIENT_SECRET="CLIENT-SECRET-HERE"
API_KEY="API-KEY-HERE"
REDIRECT_URI="http://localhost"
AUTH_BASE_URL="https://api.enphaseenergy.com/oauth"
API_BASE_URL="https://api.enphaseenergy.com/api/v4"
CREDS_FILE="$HOME/.enphase_credentials"

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
status() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if credentials file exists and source it
if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
    status "Loaded existing credentials"
fi

# Function to prompt for missing credentials
prompt_credentials() {
    status "Setting up credentials..."
    
    if [ -z "$CLIENT_ID" ]; then
        read -p "Enter your Client ID: " CLIENT_ID
    fi
    
    if [ -z "$CLIENT_SECRET" ]; then
        read -p "Enter your Client Secret: " CLIENT_SECRET
    fi
    
    if [ -z "$API_KEY" ]; then
        read -p "Enter your API Key: " API_KEY
    fi

    # Save credentials
    echo "CLIENT_ID='$CLIENT_ID'" > "$CREDS_FILE"
    echo "CLIENT_SECRET='$CLIENT_SECRET'" >> "$CREDS_FILE"
    echo "API_KEY='$API_KEY'" >> "$CREDS_FILE"
    chmod 600 "$CREDS_FILE"
    success "Credentials saved securely"
}

# Function to create base64 encoded authorization header
create_auth_header() {
    echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64
}

# Function to get authorization URL
get_auth_url() {
    echo "${AUTH_BASE_URL}/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}"
}

# Function to exchange code for token
exchange_token() {
    local auth_code=$1
    local auth_header="Basic $(create_auth_header)"
    
    status "Exchanging authorization code for access token..."
    
    response=$(curl -s -X POST "${AUTH_BASE_URL}/token" \
        -H "Authorization: ${auth_header}" \
        -d "grant_type=authorization_code" \
        -d "redirect_uri=${REDIRECT_URI}" \
        -d "code=${auth_code}")
    
    # Extract tokens directly from JSON response using grep and sed
    access_token=$(echo "$response" | grep -o '"access_token" : "[^"]*"' | sed 's/"access_token" : "\(.*\)"/\1/')
    refresh_token=$(echo "$response" | grep -o '"refresh_token" : "[^"]*"' | sed 's/"refresh_token" : "\(.*\)"/\1/')
    
    if [ -n "$access_token" ]; then
        echo "ACCESS_TOKEN='$access_token'" >> "$CREDS_FILE"
        echo "REFRESH_TOKEN='$refresh_token'" >> "$CREDS_FILE"
        
        success "Tokens received and saved!"
        
        # Test the token
        status "Testing authentication with systems API..."
        test_response=$(curl -s -X GET "${API_BASE_URL}/systems" \
            -H "Authorization: Bearer ${access_token}" \
            -H "key: ${API_KEY}")
        
        echo
        status "API Test Response:"
        echo "$test_response" | python -m json.tool
        
        # Try to extract system ID from response if available
        if echo "$test_response" | grep -q '"system_id"'; then
            system_id=$(echo "$test_response" | grep -o '"system_id":[0-9]*' | cut -d':' -f2 | head -1)
            status "Found system ID: $system_id"
        else
            status "Could not automatically detect system ID"
            system_id="YOUR_SYSTEM_ID"
        fi
        
        echo
        success "Configuration for MagicMirror:"
        echo "----------------------------------------"
        echo "{
    module: \"MMM-EnphaseBattery\",
    position: \"top_right\",
    config: {
        apiKey: \"$API_KEY\",
        accessToken: \"$access_token\",
        systemId: \"$system_id\"
    }
}"
        echo "----------------------------------------"
        echo
        status "To test your credentials manually, run:"
        echo "curl -X GET '${API_BASE_URL}/systems' \\"
        echo "  -H 'Authorization: Bearer ${access_token}' \\"
        echo "  -H 'key: ${API_KEY}'"
    else
        error "Failed to parse tokens from response:"
        echo "$response"
        exit 1
    fi
}

# Main script
echo "========================================="
echo "Enphase OAuth Setup Script (Developer)"
echo "========================================="
echo
status "Before continuing, please ensure:"
echo "1. You have registered an application on developer.enphase.com"
echo "2. You have your Client ID, Client Secret, and API Key"
echo "3. You have added http://localhost as an authorized redirect URI"
echo "4. You have your Enlighten owner account credentials ready"
echo
read -p "Press Enter to continue..."

# Prompt for credentials if needed
prompt_credentials

# Get authorization URL and prompt user
auth_url=$(get_auth_url)
echo
status "Please open this URL in your browser:"
echo "$auth_url"
echo
status "IMPORTANT: Log in with your Enlighten owner account (the account that has access to your system)"
echo "After authorizing, you'll be redirected to localhost with a code parameter."
echo "The URL will look like: http://localhost/?code=SOMETHING"
echo
read -p "Enter the authorization code from the URL: " auth_code

if [ -n "$auth_code" ]; then
    exchange_token "$auth_code"
else
    error "Authorization code is required!"
    exit 1
fi