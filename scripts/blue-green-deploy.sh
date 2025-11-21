#!/bin/bash

# Blue-Green Deployment Script for Farmers Bank Microservices

set -e

NAMESPACE_PREFIX="farmersbank"
BLUE_SUFFIX="-blue"
GREEN_SUFFIX="-green"

echo "🚀 Starting Blue-Green Deployment..."

# Function to check if deployment exists
deployment_exists() {
    local deployment_name=$1
    local namespace=$2
    kubectl get deployment "$deployment_name" -n "$namespace" &> /dev/null
}

# Function to get current active color
get_active_color() {
    local service_name=$1
    local namespace=$2
    
    # Check which deployment the service is pointing to
    local selector=$(kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.spec.selector.version}')
    
    if [ "$selector" = "blue" ]; then
        echo "blue"
    elif [ "$selector" = "green" ]; then
        echo "green"
    else
        echo "none"
    fi
}

# Function to deploy to inactive environment
deploy_to_inactive() {
    local service=$1
    local namespace=$2
    local active_color=$3
    local inactive_color=$4
    
    echo "Deploying $service to $inactive_color environment..."
    
    # Get the current image tag
    IMAGE_TAG=$(cat artifacts/${service}-image-tag/${service}-image-tag.txt)
    
    # Create deployment for inactive environment
    cat k8s/${service}/deployment.yaml | \
    sed "s|name: ${service}-service|name: ${service}-service${inactive_color}|g" | \
    sed "s|app: ${service}-service|app: ${service}-service\n        version: ${inactive_color#-}|g" | \
    sed "s|image: .*|image: ${IMAGE_TAG}|g" | \
    kubectl apply -n "$namespace" -f -
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=600s \
        deployment "${service}-service${inactive_color}" -n "$namespace"
    
    echo "✅ $service deployed to $inactive_color environment"
}

# Function to switch traffic
switch_traffic() {
    local service=$1
    local namespace=$2
    local new_color=$3
    
    echo "Switching traffic for $service to $new_color environment..."
    
    # Update service selector
    kubectl patch svc "${service}-service" -n "$namespace" \
        -p '{"spec":{"selector":{"version":"'${new_color#-}'"}}}'
    
    echo "✅ Traffic switched for $service"
}

# Function to cleanup old environment
cleanup_old() {
    local service=$1
    local namespace=$2
    local old_color=$3
    
    echo "Cleaning up old $service deployment ($old_color)..."
    
    # Scale down old deployment
    kubectl scale deployment "${service}-service${old_color}" --replicas=0 -n "$namespace"
    
    # Wait a bit for graceful shutdown
    sleep 30
    
    # Delete old deployment
    kubectl delete deployment "${service}-service${old_color}" -n "$namespace"
    
    echo "✅ Cleaned up old $service deployment"
}

# Function to rollback
rollback() {
    local service=$1
    local namespace=$2
    local rollback_color=$3
    
    echo "Rolling back $service to $rollback_color..."
    
    # Switch traffic back
    switch_traffic "$service" "$namespace" "$rollback_color"
    
    echo "❌ Rollback completed for $service"
}

# Function to run health check
health_check() {
    local service=$1
    local namespace=$2
    local max_attempts=30
    local attempt=1
    
    echo "Running health check for $service..."
    
    # Get service external IP
    SERVICE_IP=$(kubectl get svc "${service}-service" -n "$namespace" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://$SERVICE_IP/health" > /dev/null; then
            echo "✅ $service health check passed"
            return 0
        else
            echo "⏳ Attempt $attempt/$max_attempts: waiting for $service..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo "❌ $service health check failed"
    return 1
}

# Main deployment logic
SERVICES=("memberservices" "loansunderwriting" "payments" "fraudrisk")
NAMESPACES=("member-services" "loans-underwriting" "payments" "fraud-risk")

for i in "${!SERVICES[@]}"; do
    service=${SERVICES[$i]}
    namespace=${NAMESPACES[$i]}
    
    echo ""
    echo "🔄 Processing $service in namespace $namespace..."
    
    # Get current active color
    active_color=$(get_active_color "${service}-service" "$namespace")
    
    if [ "$active_color" = "blue" ]; then
        inactive_color="green"
        inactive_suffix=$GREEN_SUFFIX
        active_suffix=$BLUE_SUFFIX
    elif [ "$active_color" = "green" ]; then
        inactive_color="blue"
        inactive_suffix=$BLUE_SUFFIX
        active_suffix=$GREEN_SUFFIX
    else
        # First deployment - start with blue
        inactive_color="blue"
        inactive_suffix=$BLUE_SUFFIX
        active_color="none"
    fi
    
    echo "Active: $active_color, Deploying to: $inactive_color"
    
    # Deploy to inactive environment
    if ! deploy_to_inactive "$service" "$namespace" "$active_color" "$inactive_suffix"; then
        echo "❌ Deployment failed for $service"
        exit 1
    fi
    
    # Run health check on new deployment
    if ! health_check "$service" "$namespace"; then
        echo "❌ Health check failed for $service, cleaning up..."
        kubectl delete deployment "${service}-service${inactive_suffix}" -n "$namespace" || true
        exit 1
    fi
    
    # Switch traffic to new environment
    switch_traffic "$service" "$namespace" "$inactive_suffix"
    
    # Run post-switch health check
    if ! health_check "$service" "$namespace"; then
        echo "❌ Post-switch health check failed, rolling back..."
        if [ "$active_color" != "none" ]; then
            rollback "$service" "$namespace" "$active_suffix"
        fi
        exit 1
    fi
    
    # Cleanup old environment (if exists)
    if [ "$active_color" != "none" ]; then
        cleanup_old "$service" "$namespace" "$active_suffix"
    fi
    
    echo "✅ Blue-green deployment completed for $service"
done

echo ""
echo "🎉 Blue-green deployment completed successfully for all services!"