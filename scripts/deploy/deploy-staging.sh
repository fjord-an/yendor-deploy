#!/bin/bash

#
# Staging Deployment Script for YendorCats
# Deploys the application to the staging environment
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-025066273203}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
PROJECT_NAME="yendorcats"
ENVIRONMENT="staging"

# Staging server configuration
STAGING_HOST="${STAGING_HOST:-staging.yendorcats.com}"
STAGING_USER="${STAGING_USER:-ubuntu}"
STAGING_SSH_KEY="${STAGING_SSH_KEY:-~/.ssh/yendorcats-staging.pem}"

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Show deployment information
show_deployment_info() {
    local image_tag="${1:-latest}"
    
    print_header "Deployment Information"
    print_info "Environment: $ENVIRONMENT"
    print_info "Target Host: $STAGING_HOST"
    print_info "Image Tag: $image_tag"
    print_info "ECR Registry: $ECR_REGISTRY"
    print_info "AWS Region: $AWS_REGION"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    print_success "AWS CLI is available"
    
    # Check AWS authentication
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not authenticated"
        exit 1
    fi
    print_success "AWS CLI is authenticated"
    
    # Check SSH key
    if [[ -f "$STAGING_SSH_KEY" ]]; then
        print_success "SSH key found: $STAGING_SSH_KEY"
    else
        print_warning "SSH key not found: $STAGING_SSH_KEY"
        print_info "Make sure you have the correct SSH key configured"
    fi
    
    # Check if staging host is reachable
    if ping -c 1 "$STAGING_HOST" &> /dev/null; then
        print_success "Staging host is reachable: $STAGING_HOST"
    else
        print_warning "Cannot ping staging host: $STAGING_HOST"
        print_info "This might be normal if ICMP is disabled"
    fi
}

# Verify images exist in ECR
verify_images() {
    local image_tag="${1:-latest}"
    
    print_header "Verifying Images in ECR"
    
    SERVICES=("api" "uploader" "frontend")
    
    for service in "${SERVICES[@]}"; do
        local repo_name="${PROJECT_NAME}-${service}"
        local image_uri="${ECR_REGISTRY}/${repo_name}:${image_tag}"
        
        print_info "Checking $service image..."
        if aws ecr describe-images --repository-name "$repo_name" --image-ids imageTag="$image_tag" --region "$AWS_REGION" &> /dev/null; then
            print_success "$service image exists: $image_tag"
        else
            print_error "$service image not found: $image_tag"
            print_info "Available tags for $repo_name:"
            aws ecr list-images --repository-name "$repo_name" --region "$AWS_REGION" --query 'imageIds[*].imageTag' --output table || true
            exit 1
        fi
    done
}

# Generate docker-compose file for staging
generate_staging_compose() {
    local image_tag="${1:-latest}"
    
    print_header "Generating Staging Docker Compose"
    
    local compose_file="docker-compose.staging.yml"
    
    cat > "$compose_file" << EOF
version: '3.8'

services:
  # Backend API service
  api:
    image: ${ECR_REGISTRY}/${PROJECT_NAME}-api:${image_tag}
    container_name: ${PROJECT_NAME}-api-staging
    restart: unless-stopped
    ports:
      - "5003:80"
    environment:
      - ASPNETCORE_ENVIRONMENT=Staging
      - ASPNETCORE_URLS=http://+:80
      - AWS__Region=us-west-004
      - AWS__UseCredentialsFromSecrets=false
      - AWS__S3__BucketName=\${AWS_S3_BUCKET_NAME:-yendor}
      - AWS__S3__UseDirectS3Urls=true
      - AWS__S3__ServiceUrl=https://s3.us-west-004.backblazeb2.com
      - AWS__S3__PublicUrl=https://f004.backblazeb2.com/file/\${AWS_S3_BUCKET_NAME:-yendor}/{key}
      - AWS__S3__UseCdn=false
      - AWS__S3__AccessKey=\${AWS_S3_ACCESS_KEY}
      - AWS__S3__SecretKey=\${AWS_S3_SECRET_KEY}
      - AWS__S3__KeyPrefix=YendorCats-General-SiteAccess/
      - B2_APPLICATION_KEY_ID=\${B2_APPLICATION_KEY_ID}
      - B2_APPLICATION_KEY=\${B2_APPLICATION_KEY}
      - B2_BUCKET_ID=\${B2_BUCKET_ID}
      - ConnectionStrings__DefaultConnection=Data Source=/app/data/yendorcats-staging.db
      - JwtSettings__Secret=\${YENDOR_JWT_SECRET}
      - SERVER__ExternalIP=\${STAGING_EXTERNAL_IP}
      - CORS__AdditionalOrigins=https://staging.yendorcats.com,http://staging.yendorcats.com
    volumes:
      - api-data:/app/data
      - api-logs:/app/Logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - yendorcats-network

  # File Upload Service
  uploader:
    image: ${ECR_REGISTRY}/${PROJECT_NAME}-uploader:${image_tag}
    container_name: ${PROJECT_NAME}-uploader-staging
    restart: unless-stopped
    ports:
      - "5002:80"
    environment:
      - AWS_S3_BUCKET_NAME=\${AWS_S3_BUCKET_NAME:-yendor}
      - AWS_S3_REGION=us-west-004
      - AWS_S3_ENDPOINT=https://s3.us-west-004.backblazeb2.com
      - AWS_S3_ACCESS_KEY=\${AWS_S3_ACCESS_KEY}
      - AWS_S3_SECRET_KEY=\${AWS_S3_SECRET_KEY}
      - API_BASE_URL=http://api
    depends_on:
      - api
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - yendorcats-network

  # Frontend with Nginx
  frontend:
    image: ${ECR_REGISTRY}/${PROJECT_NAME}-frontend:${image_tag}
    container_name: ${PROJECT_NAME}-frontend-staging
    ports:
      - "80:80"
    depends_on:
      api:
        condition: service_healthy
      uploader:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - yendorcats-network
    environment:
      - API_HOST=api
      - UPLOADER_HOST=uploader
      - NGINX_CONFIG=staging

networks:
  yendorcats-network:
    driver: bridge
    name: yendorcats-staging

volumes:
  api-data:
    name: yendorcats-staging-api-data
  api-logs:
    name: yendorcats-staging-api-logs
EOF
    
    print_success "Staging compose file generated: $compose_file"
}

# Deploy to staging server
deploy_to_staging() {
    local image_tag="${1:-latest}"
    local compose_file="docker-compose.staging.yml"
    
    print_header "Deploying to Staging Server"
    
    # Create deployment script for remote execution
    local deploy_script="staging-deploy-remote.sh"

    cat > "$deploy_script" << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting staging deployment..."

# Load environment variables
if [[ -f "/opt/yendorcats/.env.staging" ]]; then
    source /opt/yendorcats/.env.staging
    echo "✓ Environment variables loaded"
else
    echo "⚠ Warning: /opt/yendorcats/.env.staging not found"
fi

# Login to ECR
echo "📥 Logging into ECR..."
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin 025066273203.dkr.ecr.ap-southeast-2.amazonaws.com

# Pull latest images
echo "🔄 Pulling latest images..."
docker-compose -f docker-compose.staging.yml pull

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.staging.yml down

# Start new containers
echo "▶️  Starting new containers..."
docker-compose -f docker-compose.staging.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Show container status
echo "📊 Container status:"
docker-compose -f docker-compose.staging.yml ps

# Run health checks
echo "🏥 Running health checks..."
for service in api uploader frontend; do
    container_name="yendorcats-${service}-staging"
    if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
        echo "✓ $service is running"
    else
        echo "✗ $service is not running"
        docker logs "$container_name" --tail 20
    fi
done

echo "✅ Staging deployment completed!"
EOF
    
    chmod +x "$deploy_script"
    
    # Copy files to staging server
    print_info "Copying deployment files to staging server..."
    scp -i "$STAGING_SSH_KEY" "$compose_file" "$deploy_script" "${STAGING_USER}@${STAGING_HOST}:~/"
    
    # Execute deployment on staging server
    print_info "Executing deployment on staging server..."
    ssh -i "$STAGING_SSH_KEY" "${STAGING_USER}@${STAGING_HOST}" "bash ~/staging-deploy-remote.sh"
    
    # Cleanup local files
    rm -f "$deploy_script"
    
    print_success "Deployment to staging server completed"
}

# Run health checks
run_health_checks() {
    print_header "Running Health Checks"
    
    local base_url="http://${STAGING_HOST}"
    
    # Wait for services to start
    print_info "Waiting for services to start..."
    sleep 30
    
    # Check frontend
    print_info "Checking frontend health..."
    if curl -f -s "${base_url}/health" > /dev/null; then
        print_success "Frontend is healthy"
    else
        print_warning "Frontend health check failed"
    fi
    
    # Check API
    print_info "Checking API health..."
    if curl -f -s "${base_url}:5003/health" > /dev/null; then
        print_success "API is healthy"
    else
        print_warning "API health check failed"
    fi
    
    # Check uploader
    print_info "Checking uploader health..."
    if curl -f -s "${base_url}:5002/health" > /dev/null; then
        print_success "Uploader is healthy"
    else
        print_warning "Uploader health check failed"
    fi
}

# Show deployment summary
show_deployment_summary() {
    local image_tag="${1:-latest}"
    
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Staging deployment completed successfully!${NC}\n"
    
    echo -e "${BLUE}Deployment Details:${NC}"
    echo "• Environment: $ENVIRONMENT"
    echo "• Host: $STAGING_HOST"
    echo "• Image Tag: $image_tag"
    echo "• Timestamp: $(date)"
    
    echo -e "\n${BLUE}Service URLs:${NC}"
    echo "• Frontend: http://${STAGING_HOST}"
    echo "• API: http://${STAGING_HOST}:5003"
    echo "• Uploader: http://${STAGING_HOST}:5002"
    
    echo -e "\n${BLUE}Health Check URLs:${NC}"
    echo "• Frontend: http://${STAGING_HOST}/health"
    echo "• API: http://${STAGING_HOST}:5003/health"
    echo "• Uploader: http://${STAGING_HOST}:5002/health"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "• Test the staging environment thoroughly"
    echo "• If everything looks good, deploy to production:"
    echo "  ./scripts/deploy/deploy-production.sh $image_tag"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [IMAGE_TAG] [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  IMAGE_TAG           Docker image tag to deploy (default: latest)"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --skip-health       Skip health checks after deployment"
    echo ""
    echo "Environment Variables:"
    echo "  STAGING_HOST        Staging server hostname"
    echo "  STAGING_USER        SSH username for staging server"
    echo "  STAGING_SSH_KEY     Path to SSH private key"
    echo ""
    echo "Examples:"
    echo "  $0                  # Deploy latest images"
    echo "  $0 abc123           # Deploy specific git SHA"
    echo "  $0 --skip-health    # Deploy without health checks"
}

# Main execution
main() {
    local image_tag="latest"
    local skip_health=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --skip-health)
                skip_health=true
                shift
                ;;
            -*)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                image_tag="$1"
                shift
                ;;
        esac
    done
    
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                YendorCats Staging Deployment                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    show_deployment_info "$image_tag"
    check_prerequisites
    verify_images "$image_tag"
    generate_staging_compose "$image_tag"
    deploy_to_staging "$image_tag"
    
    if [[ "$skip_health" == false ]]; then
        run_health_checks
    fi
    
    show_deployment_summary "$image_tag"
    
    print_header "Staging Deployment Complete"
    print_success "YendorCats has been deployed to staging environment!"
}

# Run main function
main "$@"
