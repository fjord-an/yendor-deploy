#!/bin/bash

#
# Server-side Pull and Deploy Script for YendorCats
# This script runs on the server to pull images from ECR and deploy them
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

# Default environment (can be overridden)
ENVIRONMENT="${ENVIRONMENT:-production}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.${ENVIRONMENT}.yml}"

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
    print_info "Compose File: $COMPOSE_FILE"
    print_info "Image Tag: $image_tag"
    print_info "ECR Registry: $ECR_REGISTRY"
    print_info "Server: $(hostname)"
    print_info "User: $(whoami)"
    print_info "Timestamp: $(date)"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if running as correct user
    if [[ "$(whoami)" == "root" ]]; then
        print_warning "Running as root user"
    else
        print_success "Running as non-root user: $(whoami)"
    fi
    
    # Check AWS CLI
    if command -v aws &> /dev/null; then
        print_success "AWS CLI is available"
        
        # Check AWS authentication
        if aws sts get-caller-identity &> /dev/null; then
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            print_success "AWS CLI is authenticated (Account: $account_id)"
        else
            print_error "AWS CLI is not authenticated"
            print_info "Configure AWS credentials on this server"
            exit 1
        fi
    else
        print_error "AWS CLI is not installed"
        print_info "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker is available"
        
        # Check Docker daemon
        if docker info &> /dev/null; then
            print_success "Docker daemon is running"
        else
            print_error "Docker daemon is not running"
            print_info "Start Docker service: sudo systemctl start docker"
            exit 1
        fi
        
        # Check Docker permissions
        if docker ps &> /dev/null; then
            print_success "Docker permissions are correct"
        else
            print_warning "Docker permissions may be incorrect"
            print_info "Add user to docker group: sudo usermod -aG docker $(whoami)"
        fi
    else
        print_error "Docker is not installed"
        print_info "Install Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Check docker-compose
    if command -v docker-compose &> /dev/null; then
        print_success "docker-compose is available"
    else
        print_error "docker-compose is not installed"
        print_info "Install docker-compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check compose file exists
    if [[ -f "$COMPOSE_FILE" ]]; then
        print_success "Compose file exists: $COMPOSE_FILE"
    else
        print_error "Compose file not found: $COMPOSE_FILE"
        print_info "Make sure the compose file is uploaded to this server"
        exit 1
    fi
    
    # Check environment file
    local env_file=".env.${ENVIRONMENT}"
    if [[ -f "$env_file" ]]; then
        print_success "Environment file exists: $env_file"
    else
        print_warning "Environment file not found: $env_file"
        print_info "Create environment file with required variables"
    fi
}

# Load environment variables
load_environment() {
    print_header "Loading Environment Variables"
    
    local env_file=".env.${ENVIRONMENT}"
    
    if [[ -f "$env_file" ]]; then
        print_info "Loading environment from: $env_file"
        source "$env_file"
        print_success "Environment variables loaded"
    else
        print_warning "No environment file found, using system environment"
    fi
    
    # Check required environment variables
    local required_vars=(
        "AWS_S3_BUCKET_NAME"
        "AWS_S3_ACCESS_KEY"
        "AWS_S3_SECRET_KEY"
        "YENDOR_JWT_SECRET"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_warning "Missing environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        print_info "Set these variables in $env_file or system environment"
    else
        print_success "All required environment variables are set"
    fi
}

# Login to ECR
ecr_login() {
    print_header "Logging into ECR"
    
    print_info "Authenticating with ECR registry: $ECR_REGISTRY"
    
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
        print_success "Successfully logged into ECR"
    else
        print_error "Failed to login to ECR"
        exit 1
    fi
}

# Pull images from ECR
pull_images() {
    local image_tag="${1:-latest}"
    
    print_header "Pulling Images from ECR"
    
    print_info "Pulling images with tag: $image_tag"
    
    # Set image tag in environment for docker-compose
    export IMAGE_TAG="$image_tag"
    export ECR_REGISTRY="$ECR_REGISTRY"
    
    if docker-compose -f "$COMPOSE_FILE" pull; then
        print_success "All images pulled successfully"
    else
        print_error "Failed to pull images"
        exit 1
    fi
}

# Stop existing containers
stop_containers() {
    print_header "Stopping Existing Containers"
    
    if docker-compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
        print_info "Stopping running containers..."
        docker-compose -f "$COMPOSE_FILE" down
        print_success "Containers stopped"
    else
        print_info "No running containers found"
    fi
}

# Start new containers
start_containers() {
    print_header "Starting New Containers"
    
    print_info "Starting containers in detached mode..."
    
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        print_success "Containers started successfully"
    else
        print_error "Failed to start containers"
        print_info "Check logs: docker-compose -f $COMPOSE_FILE logs"
        exit 1
    fi
}

# Wait for services to be healthy
wait_for_health() {
    print_header "Waiting for Services to be Healthy"
    
    local max_wait=300  # 5 minutes
    local wait_time=0
    local check_interval=10
    
    print_info "Waiting for services to become healthy (max ${max_wait}s)..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        local healthy_count=0
        local total_services=0
        
        # Check each service health
        while IFS= read -r service; do
            if [[ -n "$service" ]]; then
                total_services=$((total_services + 1))
                local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unknown")
                
                case "$health_status" in
                    "healthy")
                        healthy_count=$((healthy_count + 1))
                        ;;
                    "unhealthy")
                        print_warning "Service $service is unhealthy"
                        ;;
                    "starting")
                        print_info "Service $service is starting..."
                        ;;
                    *)
                        print_info "Service $service health status: $health_status"
                        ;;
                esac
            fi
        done < <(docker-compose -f "$COMPOSE_FILE" ps -q | xargs -I {} docker inspect --format='{{.Name}}' {} 2>/dev/null | sed 's/^.//')
        
        if [[ $healthy_count -eq $total_services && $total_services -gt 0 ]]; then
            print_success "All services are healthy ($healthy_count/$total_services)"
            return 0
        fi
        
        print_info "Healthy services: $healthy_count/$total_services (waiting ${check_interval}s...)"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    print_warning "Timeout waiting for services to become healthy"
    return 1
}

# Show container status
show_container_status() {
    print_header "Container Status"
    
    echo -e "${BLUE}Running containers:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo -e "\n${BLUE}Container resource usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker-compose -f "$COMPOSE_FILE" ps -q) 2>/dev/null || true
}

# Run health checks
run_health_checks() {
    print_header "Running Health Checks"
    
    local services=("api" "uploader" "frontend")
    local ports=("5003" "5002" "80")
    
    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local port="${ports[$i]}"
        local container_name="${PROJECT_NAME}-${service}-${ENVIRONMENT}"
        
        print_info "Checking $service service..."
        
        # Check if container is running
        if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            print_success "$service container is running"
            
            # Check health endpoint
            if curl -f -s "http://localhost:${port}/health" > /dev/null; then
                print_success "$service health check passed"
            else
                print_warning "$service health check failed"
                print_info "Check logs: docker logs $container_name"
            fi
        else
            print_error "$service container is not running"
            print_info "Check logs: docker logs $container_name"
        fi
    done
}

# Show deployment summary
show_deployment_summary() {
    local image_tag="${1:-latest}"
    
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Deployment completed successfully!${NC}\n"
    
    echo -e "${BLUE}Deployment Details:${NC}"
    echo "• Environment: $ENVIRONMENT"
    echo "• Image Tag: $image_tag"
    echo "• Server: $(hostname)"
    echo "• Timestamp: $(date)"
    
    echo -e "\n${BLUE}Service Status:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "• View logs: docker-compose -f $COMPOSE_FILE logs -f [service]"
    echo "• Restart service: docker-compose -f $COMPOSE_FILE restart [service]"
    echo "• Stop all: docker-compose -f $COMPOSE_FILE down"
    echo "• Check status: docker-compose -f $COMPOSE_FILE ps"
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
    echo "  -e, --env ENV       Environment (default: production)"
    echo "  -f, --file FILE     Docker compose file (default: docker-compose.ENV.yml)"
    echo "  --skip-health       Skip health checks"
    echo "  --no-wait           Don't wait for services to be healthy"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT         Deployment environment"
    echo "  COMPOSE_FILE        Docker compose file path"
    echo "  AWS_REGION          AWS region"
    echo ""
    echo "Examples:"
    echo "  $0                  # Deploy latest images to production"
    echo "  $0 abc123           # Deploy specific git SHA"
    echo "  $0 -e staging       # Deploy to staging environment"
    echo "  $0 --skip-health    # Deploy without health checks"
}

# Main execution
main() {
    local image_tag="latest"
    local skip_health=false
    local no_wait=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
                shift 2
                ;;
            -f|--file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            --skip-health)
                skip_health=true
                shift
                ;;
            --no-wait)
                no_wait=true
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
    echo "║              YendorCats Server Pull & Deploy                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    show_deployment_info "$image_tag"
    check_prerequisites
    load_environment
    ecr_login
    pull_images "$image_tag"
    stop_containers
    start_containers
    
    if [[ "$no_wait" == false ]]; then
        wait_for_health
    fi
    
    show_container_status
    
    if [[ "$skip_health" == false ]]; then
        run_health_checks
    fi
    
    show_deployment_summary "$image_tag"
    
    print_header "Deployment Complete"
    print_success "YendorCats has been deployed successfully!"
}

# Run main function
main "$@"
