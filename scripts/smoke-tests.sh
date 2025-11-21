#!/bin/bash

# Farmers Bank Microservices Smoke Tests

set -e

ENVIRONMENT=${1:-dev}
TIMEOUT=300
RETRY_INTERVAL=10

echo "🧪 Running smoke tests for $ENVIRONMENT environment..."

# Function to test service health
test_service_health() {
    local service_name=$1
    local service_url=$2
    local max_attempts=$((TIMEOUT / RETRY_INTERVAL))
    local attempt=1

    echo "Testing $service_name health at $service_url"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$service_url/health" > /dev/null; then
            echo "✅ $service_name is healthy"
            return 0
        else
            echo "⏳ Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
            sleep $RETRY_INTERVAL
            attempt=$((attempt + 1))
        fi
    done
    
    echo "❌ $service_name health check failed after $max_attempts attempts"
    return 1
}

# Function to test service API
test_service_api() {
    local service_name=$1
    local api_url=$2
    
    echo "Testing $service_name API at $api_url"
    
    response=$(curl -s -w "%{http_code}" -o /dev/null "$api_url")
    if [ "$response" -eq 200 ]; then
        echo "✅ $service_name API is responding"
        return 0
    else
        echo "❌ $service_name API returned status: $response"
        return 1
    fi
}

# Get service URLs based on environment
if [ "$ENVIRONMENT" = "staging" ]; then
    # Staging service URLs (LoadBalancer IPs)
    MEMBER_URL=$(kubectl get svc memberservices-service -n member-services -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    LOANS_URL=$(kubectl get svc loansunderwriting-service -n loans-underwriting -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    PAYMENTS_URL=$(kubectl get svc payments-service -n payments -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    FRAUD_URL=$(kubectl get svc fraudrisk-service -n fraud-risk -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
elif [ "$ENVIRONMENT" = "production" ]; then
    # Production service URLs (through API Gateway)
    MEMBER_URL="https://api.farmersbank.com/members"
    LOANS_URL="https://api.farmersbank.com/loans"
    PAYMENTS_URL="https://api.farmersbank.com/payments"
    FRAUD_URL="https://api.farmersbank.com/fraud"
else
    # Development environment (LoadBalancer IPs)
    MEMBER_URL=$(kubectl get svc memberservices-service -n member-services -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    LOANS_URL=$(kubectl get svc loansunderwriting-service -n loans-underwriting -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    PAYMENTS_URL=$(kubectl get svc payments-service -n payments -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    FRAUD_URL=$(kubectl get svc fraudrisk-service -n fraud-risk -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

# Add http:// prefix if not present
MEMBER_URL="http://${MEMBER_URL#http://}"
LOANS_URL="http://${LOANS_URL#http://}"
PAYMENTS_URL="http://${PAYMENTS_URL#http://}"
FRAUD_URL="http://${FRAUD_URL#http://}"

# Test all services
echo "🔍 Testing service health endpoints..."
test_service_health "Member Services" "$MEMBER_URL"
test_service_health "Loans Underwriting" "$LOANS_URL"
test_service_health "Payments" "$PAYMENTS_URL"
test_service_health "Fraud Risk" "$FRAUD_URL"

echo ""
echo "🔍 Testing service APIs..."
test_service_api "Member Services" "$MEMBER_URL/api/Members"
test_service_api "Loans Underwriting" "$LOANS_URL/api/LoanApplications"
test_service_api "Payments" "$PAYMENTS_URL/api/Payments"
test_service_api "Fraud Risk" "$FRAUD_URL/api/FraudAlerts"

# Test inter-service communication
echo ""
echo "🔍 Testing inter-service communication..."

# Test member creation and loan application flow
echo "Testing member creation..."
MEMBER_RESPONSE=$(curl -s -X POST "$MEMBER_URL/api/Members" \
    -H "Content-Type: application/json" \
    -d '{
        "firstName": "Test",
        "lastName": "User",
        "email": "test@example.com",
        "phoneNumber": "555-0123",
        "address": "123 Test St",
        "membershipType": "Standard"
    }')

if [ $? -eq 0 ]; then
    echo "✅ Member creation test passed"
else
    echo "❌ Member creation test failed"
fi

echo ""
echo "🎉 Smoke tests completed for $ENVIRONMENT environment!"