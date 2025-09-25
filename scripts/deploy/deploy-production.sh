#!/bin/bash

#
# Production Deployment Script for YendorCats
# Deploys the application to the production environment with safety checks
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
ENVIRONMENT="production"

# Production server configuration
PRODUCTION_HOST="${PRODUCTION_HOST:-yendorcats.com}"
PRODUCTION_USER="${PRODUCTION_USER:-ubuntu}"
PRODUCTION_SSH_KEY="${PRODUCTION_SSH_KEY:-~/.ssh/yendorcats-production.pem}"

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

# Show deployment warning
show_deployment_warning() {
    local image_tag="${1:-latest}"
    
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  PRODUCTION DEPLOYMENT ⚠️                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    print_warning "You are about to deploy to PRODUCTION environment!"
    print_info "Target Host: $PRODUCTION_HOST"
    print_info "Image Tag: $image_tag"
    print_info "This will affect the live website: https://yendorcats.com"
    
    echo -e "\n${YELLOW}Please confirm the following:${NC}"
    echo "1. The staging environment has been tested thoroughly"
    echo "2. All tests are passing"
    echo "3. The deployment has been approved"
    echo "4. You have a rollback plan ready"
    
    echo -e "\n${RED}Type 'DEPLOY TO PRODUCTION' to continue:${NC}"
    read -r confirmation
    
    if [[ "$confirmation" != "DEPLOY TO PRODUCTION" ]]; then
        print_error "Deployment cancelled by user"
        exit 1
    fi
    
    print_success "Production deployment confirmed"
}

# Show deployment information
show_deployment_info() {
    local image_tag="${1:-latest}"
    
    print_header "Deployment Information"
    print_info "Environment: $ENVIRONMENT"
    print_info "Target Host: $PRODUCTION_HOST"
    print_info "Image Tag: $image_tag"
    print_info "ECR Registry: $ECR_REGISTRY"
    print_info "AWS Region: $AWS_REGION"
    print_info "Timestamp: $(date)"
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
    if [[ -f "$PRODUCTION_SSH_KEY" ]]; then
        print_success "SSH key found: $PRODUCTION_SSH_KEY"
    else
        print_warning "SSH key not found: $PRODUCTION_SSH_KEY"
        print_info "Make sure you have the correct SSH key configured"
    fi
    
    # Check if production host is reachable
    if ping -c 1 "$PRODUCTION_HOST" &> /dev/null; then
        print_success "Production host is reachable: $PRODUCTION_HOST"
    else
        print_warning "Cannot ping production host: $PRODUCTION_HOST"
        print_info "This might be normal if ICMP is disabled"
    fi
    
    # Check git status
    if git status --porcelain | grep -q .; then
        print_warning "Working directory has uncommitted changes"
        print_info "Consider committing changes before production deployment"
    else
        print_success "Working directory is clean"
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
            
            # Get image details
            local image_digest=$(aws ecr describe-images --repository-name "$repo_name" --image-ids imageTag="$image_tag" --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
            local image_pushed=$(aws ecr describe-images --repository-name "$repo_name" --image-ids imageTag="$image_tag" --region "$AWS_REGION" --query 'imageDetails[0].imagePushedAt' --output text)
            print_info "$service image pushed: $image_pushed"
        else
            print_error "$service image not found: $image_tag"
            print_info "Available tags for $repo_name:"
            aws ecr list-images --repository-name "$repo_name" --region "$AWS_REGION" --query 'imageIds[*].imageTag' --output table || true
            exit 1
        fi
    done
}

# Create backup of current deployment
create_backup() {
    print_header "Creating Backup of Current Deployment"
    
    local backup_script="production-backup-remote.sh"
    
    cat > "$backup_script" << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/opt/yendorcats/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup in: $BACKUP_DIR"

# Backup current docker-compose file
if [[ -f "docker-compose.production.yml" ]]; then
    cp docker-compose.production.yml "$BACKUP_DIR/"
    echo "✓ Docker compose file backed up"
fi

# Backup environment file
if [[ -f "/opt/yendorcats/.env.production" ]]; then
    cp /opt/yendorcats/.env.production "$BACKUP_DIR/"
    echo "✓ Environment file backed up"
fi

# Backup application data
if [[ -d "/opt/yendorcats/data" ]]; then
    cp -r /opt/yendorcats/data "$BACKUP_DIR/"
    echo "✓ Application data backed up"
fi

# Export current container images
echo "📸 Exporting current container images..."
for service in api uploader frontend; do
    container_name="yendorcats-${service}-production"
    if docker ps -a --filter "name=$container_name" | grep -q "$container_name"; then
        image_id=$(docker inspect --format='{{.Image}}' "$container_name" 2>/dev/null || echo "")
        if [[ -n "$image_id" ]]; then
            docker save "$image_id" | gzip > "$BACKUP_DIR/${service}-image.tar.gz"
            echo "✓ $service image exported"
        fi
    fi
done

echo "✅ Backup completed: $BACKUP_DIR"
echo "$BACKUP_DIR" > /tmp/last_backup_path
EOF
    
    chmod +x "$backup_script"
    
    print_info "Creating backup on production server..."
    scp -i "$PRODUCTION_SSH_KEY" "$backup_script" "${PRODUCTION_USER}@${PRODUCTION_HOST}:~/"
    ssh -i "$PRODUCTION_SSH_KEY" "${PRODUCTION_USER}@${PRODUCTION_HOST}" "bash ~/production-backup-remote.sh"
    
    # Get backup path
    local backup_path=$(ssh -i "$PRODUCTION_SSH_KEY" "${PRODUCTION_USER}@${PRODUCTION_HOST}" "cat /tmp/last_backup_path")
    print_success "Backup created: $backup_path"
    
    # Cleanup local files
    rm -f "$backup_script"
    
    # Store backup path for potential rollback
    echo "$backup_path" > /tmp/yendorcats_backup_path
}

# Generate docker-compose file for production
generate_production_compose() {
    local image_tag="${1:-latest}"
    
    print_header "Generating Production Docker Compose"
    
    local compose_file="docker-compose.production.yml"
    
    cat > "$compose_file" << EOF
version: '3.8'

services:
  # Backend API service
  api:
    image: ${ECR_REGISTRY}/${PROJECT_NAME}-api:${image_tag}
    container_name: ${PROJECT_NAME}-api-production
    restart: unless-stopped
    ports:
      - "5003:80"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - AWS__Region=us-west-004
      - AWS__UseCredentialsFromSecrets=false
      - AWS__S3__BucketName=\${AWS_S3_BUCKET_NAME:-yendor}
      - AWS__S3__UseDirectS3Urls=true
      - AWS__S3__ServiceUrl=https://s3.us-west-004.backblazeb2.com
      - AWS__S3__PublicUrl=https://f004.backblazeb2.com/file/\${AWS_S3_BUCKET_NAME:-yendor}/{key}
      - AWS__S3__UseCdn=true
      - AWS__S3__AccessKey=\${AWS_S3_ACCESS_KEY}
      - AWS__S3__SecretKey=\${AWS_S3_SECRET_KEY}
      - AWS__S3__KeyPrefix=YendorCats-General-SiteAccess/
      - B2_APPLICATION_KEY_ID=\${B2_APPLICATION_KEY_ID}
      - B2_APPLICATION_KEY=\${B2_APPLICATION_KEY}
      - B2_BUCKET_ID=\${B2_BUCKET_ID}
      - ConnectionStrings__DefaultConnection=Data Source=/app/data/yendorcats-production.db
      - JwtSettings__Secret=\${YENDOR_JWT_SECRET}
      - SERVER__ExternalIP=\${PRODUCTION_EXTERNAL_IP}
      - CORS__AdditionalOrigins=https://yendorcats.com,https://www.yendorcats.com
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
    container_name: ${PROJECT_NAME}-uploader-production
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
    container_name: ${PROJECT_NAME}-frontend-production
    ports:
      - "80:80"
      - "443:443"
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
      - NGINX_CONFIG=production

networks:
  yendorcats-network:
    driver: bridge
    name: yendorcats-production

volumes:
  api-data:
    name: yendorcats-production-api-data
  api-logs:
    name: yendorcats-production-api-logs
EOF
    
    print_success "Production compose file generated: $compose_file"
}

# Deploy to production server
deploy_to_production() {
    local image_tag="${1:-latest}"
    local compose_file="docker-compose.production.yml"
    
    print_header "Deploying to Production Server"
    
    # Create deployment script for remote execution
    local deploy_script="production-deploy-remote.sh"
    
    cat > "$deploy_script" << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting production deployment..."

# Load environment variables
if [[ -f "/opt/yendorcats/.env.production" ]]; then
    source /opt/yendorcats/.env.production
    echo "✓ Environment variables loaded"
else
    echo "⚠ Warning: /opt/yendorcats/.env.production not found"
fi

# Login to ECR
echo "📥 Logging into ECR..."
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin 025066273203.dkr.ecr.ap-southeast-2.amazonaws.com

# Pull latest images
echo "🔄 Pulling latest images..."
docker-compose -f docker-compose.production.yml pull

# Graceful shutdown of existing containers
echo "🛑 Gracefully stopping existing containers..."
docker-compose -f docker-compose.production.yml down --timeout 30

# Start new containers
echo "▶️  Starting new containers..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 60

# Show container status
echo "📊 Container status:"
docker-compose -f docker-compose.production.yml ps

# Run health checks
echo "🏥 Running health checks..."
for service in api uploader frontend; do
    container_name="yendorcats-${service}-production"
    if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
        echo "✓ $service is running"
    else
        echo "✗ $service is not running"
        docker logs "$container_name" --tail 20
    fi
done

echo "✅ Production deployment completed!"
EOF
    
    chmod +x "$deploy_script"
    
    # Copy files to production server
    print_info "Copying deployment files to production server..."
    scp -i "$PRODUCTION_SSH_KEY" "$compose_file" "$deploy_script" "${PRODUCTION_USER}@${PRODUCTION_HOST}:/opt/yendorcats/"
    
    # Execute deployment on production server
    print_info "Executing deployment on production server..."
    ssh -i "$PRODUCTION_SSH_KEY" "${PRODUCTION_USER}@${PRODUCTION_HOST}" "cd /opt/yendorcats && bash ./production-deploy-remote.sh"
    
    # Cleanup local files
    rm -f "$deploy_script"
    
    print_success "Deployment to production server completed"
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
    echo "  --skip-backup       Skip backup creation (NOT RECOMMENDED)"
    echo "  --skip-health       Skip health checks after deployment"
    echo "  --force             Skip confirmation prompt (USE WITH CAUTION)"
    echo ""
    echo "Environment Variables:"
    echo "  PRODUCTION_HOST     Production server hostname"
    echo "  PRODUCTION_USER     SSH username for production server"
    echo "  PRODUCTION_SSH_KEY  Path to SSH private key"
    echo ""
    echo "Examples:"
    echo "  $0                  # Deploy latest images with full safety checks"
    echo "  $0 abc123           # Deploy specific git SHA"
    echo "  $0 --force          # Deploy without confirmation (dangerous)"
}

# Main execution
main() {
    local image_tag="latest"
    local skip_backup=false
    local skip_health=false
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --skip-health)
                skip_health=true
                shift
                ;;
            --force)
                force=true
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
    echo "║               YendorCats Production Deployment              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [[ "$force" == false ]]; then
        show_deployment_warning "$image_tag"
    fi
    
    show_deployment_info "$image_tag"
    check_prerequisites
    verify_images "$image_tag"
    
    if [[ "$skip_backup" == false ]]; then
        create_backup
    fi
    
    generate_production_compose "$image_tag"
    deploy_to_production "$image_tag"
    
    print_header "Production Deployment Complete"
    print_success "YendorCats has been deployed to production!"
    
    echo -e "\n${BLUE}Production URLs:${NC}"
    echo "• Website: https://yendorcats.com"
    echo "• API: https://yendorcats.com:5003"
    echo "• Uploader: https://yendorcats.com:5002"
    
    echo -e "\n${BLUE}Monitoring:${NC}"
    echo "• Check health: curl https://yendorcats.com/health"
    echo "• Monitor logs: ssh -i $PRODUCTION_SSH_KEY $PRODUCTION_USER@$PRODUCTION_HOST 'docker-compose -f /opt/yendorcats/docker-compose.production.yml logs -f'"
    
    if [[ "$skip_backup" == false ]]; then
        local backup_path=$(cat /tmp/yendorcats_backup_path 2>/dev/null || echo "unknown")
        echo -e "\n${BLUE}Rollback:${NC}"
        echo "• If issues occur, rollback with: ./scripts/deploy/rollback.sh $backup_path"
    fi
}

# Run main function
main "$@"
