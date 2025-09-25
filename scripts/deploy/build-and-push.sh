#!/bin/bash

#
# Build and Push Script for YendorCats
# Builds all services and pushes them to AWS ECR
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

# Get git information for tagging
GIT_SHA=$(git rev-parse HEAD)
GIT_SHA_SHORT=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")

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

# Show build information
show_build_info() {
    print_header "Build Information"
    print_info "Git SHA: $GIT_SHA_SHORT"
    print_info "Git Branch: $GIT_BRANCH"
    print_info "Build Timestamp: $BUILD_TIMESTAMP"
    print_info "ECR Registry: $ECR_REGISTRY"
    print_info "AWS Region: $AWS_REGION"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if we're in the right directory
    if [[ ! -f "docker-compose.yml" ]]; then
        print_error "docker-compose.yml not found. Run this script from the project root."
        exit 1
    fi
    print_success "Project root directory confirmed"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    print_success "AWS CLI is available"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is available"
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    print_success "Docker daemon is running"
    
    # Check AWS authentication
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not authenticated"
        exit 1
    fi
    print_success "AWS CLI is authenticated"
    
    # Check git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "Not in a git repository"
        exit 1
    fi
    print_success "Git repository detected"
}

# Login to ECR
ecr_login() {
    print_header "Logging into ECR"
    
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
        print_success "Successfully logged into ECR"
    else
        print_error "Failed to login to ECR"
        exit 1
    fi
}

# Create ECR repositories if they don't exist
create_ecr_repos() {
    print_header "Ensuring ECR Repositories Exist"
    
    REPOS=("${PROJECT_NAME}-api" "${PROJECT_NAME}-uploader" "${PROJECT_NAME}-frontend")
    
    for repo in "${REPOS[@]}"; do
        if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &> /dev/null; then
            print_success "Repository '$repo' exists"
        else
            print_warning "Repository '$repo' does not exist. Creating..."
            if aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" &> /dev/null; then
                print_success "Created repository '$repo'"
            else
                print_error "Failed to create repository '$repo'"
                exit 1
            fi
        fi
    done
}

# Build services
build_services() {
    print_header "Building Services"
    
    # Build API service
    print_info "Building API service..."
    docker build \
        --build-arg GIT_SHA="$GIT_SHA_SHORT" \
        --build-arg GIT_BRANCH="$GIT_BRANCH" \
        --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
        -t "${PROJECT_NAME}-api:latest" \
        -f backend/YendorCats.API/Dockerfile \
        .
    print_success "API service built"
    
    # Build Uploader service
    print_info "Building Uploader service..."
    docker build \
        -t "${PROJECT_NAME}-uploader:latest" \
        tools/file-uploader/
    print_success "Uploader service built"
    
    # Build Frontend service
    print_info "Building Frontend service..."
    docker build \
        -t "${PROJECT_NAME}-frontend:latest" \
        -f Dockerfile.frontend.ci \
        .
    print_success "Frontend service built"
}

# Tag images for ECR
tag_images() {
    print_header "Tagging Images for ECR"
    
    # Define tags
    TAGS=("latest" "$GIT_SHA_SHORT" "build-$(date +%Y%m%d-%H%M%S)")
    
    # Add branch-specific tag
    if [[ "$GIT_BRANCH" == "main" || "$GIT_BRANCH" == "master" ]]; then
        TAGS+=("production")
    elif [[ "$GIT_BRANCH" == "develop" ]]; then
        TAGS+=("staging")
    else
        TAGS+=("$GIT_BRANCH")
    fi
    
    SERVICES=("api" "uploader" "frontend")
    
    for service in "${SERVICES[@]}"; do
        print_info "Tagging $service service..."
        for tag in "${TAGS[@]}"; do
            docker tag "${PROJECT_NAME}-${service}:latest" "${ECR_REGISTRY}/${PROJECT_NAME}-${service}:${tag}"
        done
        print_success "$service service tagged with ${#TAGS[@]} tags"
    done
}

# Push images to ECR
push_images() {
    print_header "Pushing Images to ECR"
    
    SERVICES=("api" "uploader" "frontend")
    TAGS=("latest" "$GIT_SHA_SHORT" "build-$(date +%Y%m%d-%H%M%S)")
    
    # Add branch-specific tag
    if [[ "$GIT_BRANCH" == "main" || "$GIT_BRANCH" == "master" ]]; then
        TAGS+=("production")
    elif [[ "$GIT_BRANCH" == "develop" ]]; then
        TAGS+=("staging")
    else
        TAGS+=("$GIT_BRANCH")
    fi
    
    for service in "${SERVICES[@]}"; do
        print_info "Pushing $service service..."
        for tag in "${TAGS[@]}"; do
            docker push "${ECR_REGISTRY}/${PROJECT_NAME}-${service}:${tag}"
        done
        print_success "$service service pushed with ${#TAGS[@]} tags"
    done
}

# Generate deployment manifest
generate_deployment_manifest() {
    print_header "Generating Deployment Manifest"
    
    MANIFEST_FILE="deployment-manifest-${BUILD_TIMESTAMP}.json"
    
    cat > "$MANIFEST_FILE" << EOF
{
  "build_info": {
    "git_sha": "$GIT_SHA",
    "git_sha_short": "$GIT_SHA_SHORT",
    "git_branch": "$GIT_BRANCH",
    "build_timestamp": "$BUILD_TIMESTAMP",
    "ecr_registry": "$ECR_REGISTRY"
  },
  "services": {
    "api": {
      "image": "${ECR_REGISTRY}/${PROJECT_NAME}-api:${GIT_SHA_SHORT}",
      "latest": "${ECR_REGISTRY}/${PROJECT_NAME}-api:latest"
    },
    "uploader": {
      "image": "${ECR_REGISTRY}/${PROJECT_NAME}-uploader:${GIT_SHA_SHORT}",
      "latest": "${ECR_REGISTRY}/${PROJECT_NAME}-uploader:latest"
    },
    "frontend": {
      "image": "${ECR_REGISTRY}/${PROJECT_NAME}-frontend:${GIT_SHA_SHORT}",
      "latest": "${ECR_REGISTRY}/${PROJECT_NAME}-frontend:latest"
    }
  },
  "deployment_commands": {
    "staging": "./scripts/deploy/deploy-staging.sh ${GIT_SHA_SHORT}",
    "production": "./scripts/deploy/deploy-production.sh ${GIT_SHA_SHORT}"
  }
}
EOF
    
    print_success "Deployment manifest created: $MANIFEST_FILE"
}

# Show deployment instructions
show_deployment_instructions() {
    print_header "Deployment Instructions"
    
    echo -e "${GREEN}Build completed successfully!${NC}\n"
    
    echo -e "${BLUE}Images pushed to ECR:${NC}"
    echo "• API: ${ECR_REGISTRY}/${PROJECT_NAME}-api:${GIT_SHA_SHORT}"
    echo "• Uploader: ${ECR_REGISTRY}/${PROJECT_NAME}-uploader:${GIT_SHA_SHORT}"
    echo "• Frontend: ${ECR_REGISTRY}/${PROJECT_NAME}-frontend:${GIT_SHA_SHORT}"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    if [[ "$GIT_BRANCH" == "develop" ]]; then
        echo "• Deploy to staging: ./scripts/deploy/deploy-staging.sh $GIT_SHA_SHORT"
    elif [[ "$GIT_BRANCH" == "main" || "$GIT_BRANCH" == "master" ]]; then
        echo "• Deploy to production: ./scripts/deploy/deploy-production.sh $GIT_SHA_SHORT"
    else
        echo "• Deploy to staging: ./scripts/deploy/deploy-staging.sh $GIT_SHA_SHORT"
        echo "• Deploy to production: ./scripts/deploy/deploy-production.sh $GIT_SHA_SHORT"
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  --no-cache          Build without using Docker cache"
    echo "  --skip-push         Build and tag only, don't push to ECR"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION          AWS region (default: ap-southeast-2)"
    echo "  AWS_ACCOUNT_ID      AWS account ID (default: 025066273203)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Build and push all services"
    echo "  $0 --no-cache       # Build without cache"
    echo "  $0 --skip-push      # Build and tag only"
}

# Main execution
main() {
    local no_cache=false
    local skip_push=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            --skip-push)
                skip_push=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                YendorCats Build & Push to ECR               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    show_build_info
    check_prerequisites
    
    if [[ "$skip_push" == false ]]; then
        ecr_login
        create_ecr_repos
    fi
    
    build_services
    tag_images
    
    if [[ "$skip_push" == false ]]; then
        push_images
        generate_deployment_manifest
    fi
    
    show_deployment_instructions
    
    print_header "Build Complete"
    if [[ "$skip_push" == false ]]; then
        print_success "All services built and pushed to ECR successfully!"
    else
        print_success "All services built and tagged successfully!"
    fi
}

# Run main function
main "$@"
