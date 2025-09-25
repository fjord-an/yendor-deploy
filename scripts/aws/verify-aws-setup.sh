#!/bin/bash

#
# AWS Setup Verification Script for YendorCats
# Verifies AWS CLI installation, configuration, and ECR access
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="ap-southeast-2"
AWS_ACCOUNT_ID="025066273203"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if AWS CLI is installed
check_aws_cli() {
    print_header "Checking AWS CLI Installation"
    
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
        print_success "AWS CLI is installed (version: $AWS_VERSION)"
        
        # Check if version is recent enough
        if [[ $(echo "$AWS_VERSION" | cut -d. -f1) -ge 2 ]]; then
            print_success "AWS CLI version is up to date"
        else
            print_warning "AWS CLI version is older than v2. Consider upgrading."
        fi
    else
        print_error "AWS CLI is not installed"
        print_info "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
}

# Check AWS authentication
check_aws_auth() {
    print_header "Checking AWS Authentication"
    
    if aws sts get-caller-identity &> /dev/null; then
        CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
        CURRENT_REGION=$(aws configure get region)
        
        print_success "AWS CLI is authenticated"
        print_info "Account ID: $CURRENT_ACCOUNT"
        print_info "User/Role: $CURRENT_USER"
        print_info "Default Region: $CURRENT_REGION"
        
        # Check if account matches expected
        if [[ "$CURRENT_ACCOUNT" == "$AWS_ACCOUNT_ID" ]]; then
            print_success "Account ID matches expected ($AWS_ACCOUNT_ID)"
        else
            print_warning "Account ID ($CURRENT_ACCOUNT) doesn't match expected ($AWS_ACCOUNT_ID)"
        fi
        
        # Check if region matches expected
        if [[ "$CURRENT_REGION" == "$AWS_REGION" ]]; then
            print_success "Region matches expected ($AWS_REGION)"
        else
            print_warning "Region ($CURRENT_REGION) doesn't match expected ($AWS_REGION)"
            print_info "You can change region with: aws configure set region $AWS_REGION"
        fi
    else
        print_error "AWS CLI is not authenticated"
        print_info "Run 'aws configure' to set up authentication"
        exit 1
    fi
}

# Check ECR access
check_ecr_access() {
    print_header "Checking ECR Access"
    
    if aws ecr describe-repositories --region "$AWS_REGION" &> /dev/null; then
        print_success "ECR access is working"
        
        # Check for YendorCats repositories
        REPOS=("yendorcats-api" "yendorcats-uploader" "yendorcats-frontend")
        
        for repo in "${REPOS[@]}"; do
            if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &> /dev/null; then
                print_success "Repository '$repo' exists"
                
                # Check for images in repository
                IMAGE_COUNT=$(aws ecr list-images --repository-name "$repo" --region "$AWS_REGION" --query 'length(imageIds)' --output text)
                if [[ "$IMAGE_COUNT" -gt 0 ]]; then
                    print_info "Repository '$repo' has $IMAGE_COUNT images"
                else
                    print_warning "Repository '$repo' has no images"
                fi
            else
                print_warning "Repository '$repo' does not exist"
                print_info "Create with: aws ecr create-repository --repository-name $repo --region $AWS_REGION"
            fi
        done
    else
        print_error "Cannot access ECR"
        print_info "Check your AWS permissions for ECR access"
        exit 1
    fi
}

# Check Docker installation
check_docker() {
    print_header "Checking Docker Installation"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker is installed (version: $DOCKER_VERSION)"
        
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            print_success "Docker daemon is running"
        else
            print_error "Docker daemon is not running"
            print_info "Start Docker and try again"
            exit 1
        fi
    else
        print_error "Docker is not installed"
        print_info "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
}

# Test ECR login
test_ecr_login() {
    print_header "Testing ECR Login"
    
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY" &> /dev/null; then
        print_success "ECR login successful"
    else
        print_error "ECR login failed"
        print_info "Check your AWS credentials and Docker daemon"
        exit 1
    fi
}

# Check required environment variables
check_environment() {
    print_header "Checking Environment Configuration"
    
    # Check for .env file
    if [[ -f ".env" ]]; then
        print_success ".env file exists"
    else
        print_warning ".env file not found"
        print_info "Create .env file with required environment variables"
    fi
    
    # Check for required variables
    REQUIRED_VARS=("AWS_S3_BUCKET_NAME" "AWS_S3_ACCESS_KEY" "AWS_S3_SECRET_KEY")
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            print_success "Environment variable '$var' is set"
        else
            print_warning "Environment variable '$var' is not set"
        fi
    done
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 YendorCats AWS Setup Verification           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_aws_cli
    check_aws_auth
    check_ecr_access
    check_docker
    test_ecr_login
    check_environment
    
    print_header "Verification Complete"
    print_success "All checks passed! Your AWS setup is ready for deployment."
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Build and push images: ./scripts/deploy/build-and-push.sh"
    echo "2. Deploy to staging: ./scripts/deploy/deploy-staging.sh"
    echo "3. Deploy to production: ./scripts/deploy/deploy-production.sh"
}

# Run main function
main "$@"
