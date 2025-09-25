#!/bin/bash

#
# ECR Login Script for YendorCats
# Authenticates Docker with AWS ECR
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

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
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
        print_info "Run 'aws configure' to set up authentication"
        exit 1
    fi
    print_success "AWS CLI is authenticated"
}

# Perform ECR login
ecr_login() {
    print_header "Logging into ECR"
    
    print_info "Registry: $ECR_REGISTRY"
    print_info "Region: $AWS_REGION"
    
    # Get login password and authenticate
    if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
        print_success "Successfully logged into ECR"
    else
        print_error "Failed to login to ECR"
        exit 1
    fi
}

# Verify login by testing access
verify_login() {
    print_header "Verifying ECR Access"
    
    # Try to list repositories
    if aws ecr describe-repositories --region "$AWS_REGION" &> /dev/null; then
        print_success "ECR access verified"
        
        # List YendorCats repositories
        REPOS=("yendorcats-api" "yendorcats-uploader" "yendorcats-frontend")
        
        echo -e "\n${BLUE}Available repositories:${NC}"
        for repo in "${REPOS[@]}"; do
            if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &> /dev/null; then
                IMAGE_COUNT=$(aws ecr list-images --repository-name "$repo" --region "$AWS_REGION" --query 'length(imageIds)' --output text)
                echo -e "  ${GREEN}✓${NC} $repo ($IMAGE_COUNT images)"
            else
                echo -e "  ${YELLOW}⚠${NC} $repo (not found)"
            fi
        done
    else
        print_error "Cannot access ECR repositories"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verify   Verify login after authentication"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION     AWS region (default: ap-southeast-2)"
    echo "  AWS_ACCOUNT_ID AWS account ID (default: 025066273203)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Login to ECR"
    echo "  $0 --verify          # Login and verify access"
    echo "  AWS_REGION=us-east-1 $0  # Login to different region"
}

# Main execution
main() {
    local verify_login_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verify)
                verify_login_flag=true
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
    echo "║                    YendorCats ECR Login                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    ecr_login
    
    if [[ "$verify_login_flag" == true ]]; then
        verify_login
    fi
    
    print_header "Login Complete"
    print_success "Docker is now authenticated with ECR"
    print_info "You can now push and pull images from $ECR_REGISTRY"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "• Build images: docker build -t <image-name> ."
    echo "• Tag for ECR: docker tag <image-name> $ECR_REGISTRY/<repo-name>:latest"
    echo "• Push to ECR: docker push $ECR_REGISTRY/<repo-name>:latest"
}

# Run main function
main "$@"
