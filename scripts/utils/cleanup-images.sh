#!/bin/bash

#
# Docker Image Cleanup Script for YendorCats
# Removes old and unused Docker images to free up disk space
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="yendorcats"
KEEP_IMAGES=5  # Number of images to keep per service
DRY_RUN=false

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

# Show disk usage before cleanup
show_disk_usage() {
    print_header "Current Disk Usage"
    
    echo -e "${BLUE}Docker system disk usage:${NC}"
    docker system df
    
    echo -e "\n${BLUE}System disk usage:${NC}"
    df -h /
}

# List Docker images
list_images() {
    print_header "Current Docker Images"
    
    echo -e "${BLUE}All Docker images:${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    echo -e "\n${BLUE}YendorCats images:${NC}"
    docker images --filter "reference=${PROJECT_NAME}*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Clean up dangling images
cleanup_dangling() {
    print_header "Cleaning Up Dangling Images"
    
    local dangling_images=$(docker images -f "dangling=true" -q)
    
    if [[ -n "$dangling_images" ]]; then
        local count=$(echo "$dangling_images" | wc -l)
        print_info "Found $count dangling images"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_warning "DRY RUN: Would remove dangling images"
            docker images -f "dangling=true"
        else
            print_info "Removing dangling images..."
            docker rmi $dangling_images
            print_success "Removed $count dangling images"
        fi
    else
        print_success "No dangling images found"
    fi
}

# Clean up unused images
cleanup_unused() {
    print_header "Cleaning Up Unused Images"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Would remove unused images"
        docker image prune -a --filter "until=24h" --dry-run
    else
        print_info "Removing unused images older than 24 hours..."
        docker image prune -a --filter "until=24h" -f
        print_success "Unused images cleaned up"
    fi
}

# Clean up old YendorCats images
cleanup_old_project_images() {
    print_header "Cleaning Up Old YendorCats Images"
    
    local services=("api" "uploader" "frontend")
    
    for service in "${services[@]}"; do
        local repo_name="${PROJECT_NAME}-${service}"
        print_info "Processing $service images..."
        
        # Get all images for this service, sorted by creation date (newest first)
        local images=$(docker images --filter "reference=${repo_name}" --format "{{.ID}} {{.CreatedAt}} {{.Tag}}" | sort -k2 -r)
        
        if [[ -z "$images" ]]; then
            print_info "No images found for $service"
            continue
        fi
        
        local image_count=$(echo "$images" | wc -l)
        print_info "Found $image_count images for $service"
        
        if [[ $image_count -le $KEEP_IMAGES ]]; then
            print_success "Keeping all $image_count images for $service (within limit)"
            continue
        fi
        
        # Get images to remove (skip the first KEEP_IMAGES)
        local images_to_remove=$(echo "$images" | tail -n +$((KEEP_IMAGES + 1)) | awk '{print $1}')
        local remove_count=$(echo "$images_to_remove" | wc -l)
        
        print_warning "Will remove $remove_count old images for $service (keeping $KEEP_IMAGES newest)"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_warning "DRY RUN: Would remove the following images:"
            echo "$images_to_remove" | while read -r image_id; do
                local image_info=$(docker images --filter "reference=${repo_name}" --format "{{.ID}} {{.Tag}} {{.CreatedAt}}" | grep "$image_id")
                echo "  - $image_info"
            done
        else
            echo "$images_to_remove" | while read -r image_id; do
                if [[ -n "$image_id" ]]; then
                    print_info "Removing image: $image_id"
                    docker rmi "$image_id" 2>/dev/null || print_warning "Failed to remove image: $image_id"
                fi
            done
            print_success "Removed $remove_count old images for $service"
        fi
    done
}

# Clean up stopped containers
cleanup_containers() {
    print_header "Cleaning Up Stopped Containers"
    
    local stopped_containers=$(docker ps -a -f "status=exited" -q)
    
    if [[ -n "$stopped_containers" ]]; then
        local count=$(echo "$stopped_containers" | wc -l)
        print_info "Found $count stopped containers"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_warning "DRY RUN: Would remove stopped containers"
            docker ps -a -f "status=exited"
        else
            print_info "Removing stopped containers..."
            docker rm $stopped_containers
            print_success "Removed $count stopped containers"
        fi
    else
        print_success "No stopped containers found"
    fi
}

# Clean up unused volumes
cleanup_volumes() {
    print_header "Cleaning Up Unused Volumes"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Would remove unused volumes"
        docker volume prune --dry-run
    else
        print_info "Removing unused volumes..."
        docker volume prune -f
        print_success "Unused volumes cleaned up"
    fi
}

# Clean up unused networks
cleanup_networks() {
    print_header "Cleaning Up Unused Networks"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN: Would remove unused networks"
        docker network prune --dry-run
    else
        print_info "Removing unused networks..."
        docker network prune -f
        print_success "Unused networks cleaned up"
    fi
}

# Show cleanup summary
show_cleanup_summary() {
    print_header "Cleanup Summary"
    
    echo -e "${BLUE}Docker system disk usage after cleanup:${NC}"
    docker system df
    
    echo -e "\n${BLUE}Remaining YendorCats images:${NC}"
    docker images --filter "reference=${PROJECT_NAME}*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    echo -e "\n${BLUE}System disk usage after cleanup:${NC}"
    df -h /
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "This was a DRY RUN - no changes were made"
        print_info "Run without --dry-run to perform actual cleanup"
    else
        print_success "Cleanup completed successfully!"
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -n, --dry-run       Show what would be cleaned up without doing it"
    echo "  -k, --keep NUM      Number of images to keep per service (default: $KEEP_IMAGES)"
    echo "  --all               Clean up everything (containers, images, volumes, networks)"
    echo "  --images-only       Clean up images only"
    echo "  --containers-only   Clean up containers only"
    echo "  --volumes-only      Clean up volumes only"
    echo "  --networks-only     Clean up networks only"
    echo ""
    echo "Examples:"
    echo "  $0                  # Clean up everything"
    echo "  $0 --dry-run        # Show what would be cleaned up"
    echo "  $0 --keep 10        # Keep 10 images per service"
    echo "  $0 --images-only    # Clean up images only"
}

# Main execution
main() {
    local cleanup_all=true
    local cleanup_images=false
    local cleanup_containers_only=false
    local cleanup_volumes_only=false
    local cleanup_networks_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -k|--keep)
                KEEP_IMAGES="$2"
                shift 2
                ;;
            --all)
                cleanup_all=true
                shift
                ;;
            --images-only)
                cleanup_all=false
                cleanup_images=true
                shift
                ;;
            --containers-only)
                cleanup_all=false
                cleanup_containers_only=true
                shift
                ;;
            --volumes-only)
                cleanup_all=false
                cleanup_volumes_only=true
                shift
                ;;
            --networks-only)
                cleanup_all=false
                cleanup_networks_only=true
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
    echo "║                YendorCats Docker Cleanup                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    print_info "Keeping $KEEP_IMAGES images per service"
    
    show_disk_usage
    list_images
    
    if [[ "$cleanup_all" == true ]]; then
        cleanup_containers
        cleanup_dangling
        cleanup_unused
        cleanup_old_project_images
        cleanup_volumes
        cleanup_networks
    else
        if [[ "$cleanup_images" == true ]]; then
            cleanup_dangling
            cleanup_unused
            cleanup_old_project_images
        fi
        
        if [[ "$cleanup_containers_only" == true ]]; then
            cleanup_containers
        fi
        
        if [[ "$cleanup_volumes_only" == true ]]; then
            cleanup_volumes
        fi
        
        if [[ "$cleanup_networks_only" == true ]]; then
            cleanup_networks
        fi
    fi
    
    show_cleanup_summary
    
    print_header "Cleanup Complete"
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Dry run completed - no changes were made"
    else
        print_success "Docker cleanup completed successfully!"
    fi
}

# Run main function
main "$@"
