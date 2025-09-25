#!/bin/bash

#
# Server Setup Script for YendorCats
# Prepares a fresh Ubuntu server for YendorCats deployment
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${ENVIRONMENT:-production}"
PROJECT_USER="${PROJECT_USER:-yendorcats}"
PROJECT_DIR="/opt/yendorcats"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Run with: sudo $0"
        exit 1
    fi
    print_success "Running as root"
}

# Update system packages
update_system() {
    print_header "Updating System Packages"
    
    print_info "Updating package lists..."
    apt-get update
    
    print_info "Upgrading installed packages..."
    apt-get upgrade -y
    
    print_info "Installing essential packages..."
    apt-get install -y \
        curl \
        wget \
        unzip \
        git \
        htop \
        nano \
        vim \
        ufw \
        fail2ban \
        logrotate \
        cron \
        ca-certificates \
        gnupg \
        lsb-release
    
    print_success "System packages updated"
}

# Install Docker
install_docker() {
    print_header "Installing Docker"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_warning "Docker is already installed"
        docker --version
        return 0
    fi
    
    print_info "Adding Docker's official GPG key..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    print_info "Setting up Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_info "Installing Docker Engine..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_info "Starting and enabling Docker service..."
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed successfully"
    docker --version
}

# Install Docker Compose (standalone)
install_docker_compose() {
    print_header "Installing Docker Compose"
    
    # Check if docker-compose is already installed
    if command -v docker-compose &> /dev/null; then
        print_warning "Docker Compose is already installed"
        docker-compose --version
        return 0
    fi
    
    print_info "Downloading Docker Compose..."
    local compose_version="v2.24.5"
    curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    print_info "Setting permissions..."
    chmod +x /usr/local/bin/docker-compose
    
    print_info "Creating symlink..."
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose installed successfully"
    docker-compose --version
}

# Install AWS CLI
install_aws_cli() {
    print_header "Installing AWS CLI"
    
    # Check if AWS CLI is already installed
    if command -v aws &> /dev/null; then
        print_warning "AWS CLI is already installed"
        aws --version
        return 0
    fi
    
    print_info "Downloading AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    
    print_info "Installing AWS CLI..."
    unzip awscliv2.zip
    ./aws/install
    
    print_info "Cleaning up..."
    rm -rf awscliv2.zip aws/
    
    print_success "AWS CLI installed successfully"
    aws --version
}

# Create project user
create_project_user() {
    print_header "Creating Project User"
    
    if id "$PROJECT_USER" &>/dev/null; then
        print_warning "User $PROJECT_USER already exists"
    else
        print_info "Creating user: $PROJECT_USER"
        useradd -m -s /bin/bash "$PROJECT_USER"
        print_success "User $PROJECT_USER created"
    fi
    
    print_info "Adding $PROJECT_USER to docker group..."
    usermod -aG docker "$PROJECT_USER"
    
    print_info "Creating project directory..."
    mkdir -p "$PROJECT_DIR"
    chown "$PROJECT_USER:$PROJECT_USER" "$PROJECT_DIR"
    
    print_success "Project user setup completed"
}

# Configure firewall
configure_firewall() {
    print_header "Configuring Firewall"
    
    print_info "Resetting UFW to defaults..."
    ufw --force reset
    
    print_info "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing
    
    print_info "Allowing SSH..."
    ufw allow ssh
    
    print_info "Allowing HTTP and HTTPS..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow application ports based on environment
    if [[ "$ENVIRONMENT" == "staging" ]]; then
        print_info "Allowing staging ports..."
        ufw allow 5002/tcp  # Uploader
        ufw allow 5003/tcp  # API
    fi
    
    print_info "Enabling UFW..."
    ufw --force enable
    
    print_success "Firewall configured"
    ufw status
}

# Configure fail2ban
configure_fail2ban() {
    print_header "Configuring Fail2ban"
    
    print_info "Creating SSH jail configuration..."
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
    
    print_info "Starting and enabling fail2ban..."
    systemctl start fail2ban
    systemctl enable fail2ban
    
    print_success "Fail2ban configured"
}

# Setup log rotation
setup_log_rotation() {
    print_header "Setting up Log Rotation"
    
    print_info "Creating logrotate configuration for YendorCats..."
    cat > /etc/logrotate.d/yendorcats << EOF
$PROJECT_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $PROJECT_USER $PROJECT_USER
    postrotate
        docker-compose -f $PROJECT_DIR/docker-compose.$ENVIRONMENT.yml restart > /dev/null 2>&1 || true
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

# Create environment template
create_environment_template() {
    print_header "Creating Environment Template"
    
    local env_file="$PROJECT_DIR/.env.$ENVIRONMENT.template"
    
    print_info "Creating environment template: $env_file"
    
    cat > "$env_file" << EOF
# YendorCats Environment Configuration - $ENVIRONMENT
# Copy this file to .env.$ENVIRONMENT and fill in the values

# AWS Configuration
AWS_REGION=ap-southeast-2
AWS_ACCOUNT_ID=025066273203

# S3/B2 Configuration (Backblaze B2)
AWS_S3_BUCKET_NAME=yendor
AWS_S3_ACCESS_KEY=your_access_key_here
AWS_S3_SECRET_KEY=your_secret_key_here

# B2 Specific Configuration
B2_APPLICATION_KEY_ID=your_b2_key_id_here
B2_APPLICATION_KEY=your_b2_key_here
B2_BUCKET_ID=your_b2_bucket_id_here

# Database Configuration (if using MariaDB)
MYSQL_ROOT_PASSWORD=your_root_password_here
MYSQL_USER=yendorcats
MYSQL_PASSWORD=your_mysql_password_here

# JWT Configuration
YENDOR_JWT_SECRET=your_jwt_secret_here

# Server Configuration
SERVER_EXTERNAL_IP=$(curl -s ifconfig.me || echo "your_server_ip_here")
CORS_ADDITIONAL_ORIGINS=https://$(hostname -f),http://$(hostname -f)

# Environment Specific
ASPNETCORE_ENVIRONMENT=$ENVIRONMENT
STAGING_EXTERNAL_IP=\${SERVER_EXTERNAL_IP}
EOF
    
    chown "$PROJECT_USER:$PROJECT_USER" "$env_file"
    chmod 600 "$env_file"
    
    print_success "Environment template created: $env_file"
    print_warning "Remember to copy this to .env.$ENVIRONMENT and fill in the actual values"
}

# Create deployment directory structure
create_directory_structure() {
    print_header "Creating Directory Structure"
    
    local dirs=(
        "$PROJECT_DIR/logs"
        "$PROJECT_DIR/data"
        "$PROJECT_DIR/backups"
        "$PROJECT_DIR/scripts"
    )
    
    for dir in "${dirs[@]}"; do
        print_info "Creating directory: $dir"
        mkdir -p "$dir"
        chown "$PROJECT_USER:$PROJECT_USER" "$dir"
    done
    
    print_success "Directory structure created"
}

# Install monitoring tools
install_monitoring() {
    print_header "Installing Monitoring Tools"
    
    print_info "Installing system monitoring tools..."
    apt-get install -y \
        htop \
        iotop \
        nethogs \
        ncdu \
        tree
    
    print_info "Creating monitoring script..."
    cat > "$PROJECT_DIR/scripts/monitor.sh" << 'EOF'
#!/bin/bash
# Simple monitoring script for YendorCats

echo "=== System Resources ==="
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2 $3 $4 $5}'

echo -e "\nMemory Usage:"
free -h

echo -e "\nDisk Usage:"
df -h /

echo -e "\n=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n=== Container Resources ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo -e "\n=== Recent Logs ==="
docker-compose logs --tail=5
EOF
    
    chmod +x "$PROJECT_DIR/scripts/monitor.sh"
    chown "$PROJECT_USER:$PROJECT_USER" "$PROJECT_DIR/scripts/monitor.sh"
    
    print_success "Monitoring tools installed"
}

# Show setup summary
show_setup_summary() {
    print_header "Setup Summary"
    
    echo -e "${GREEN}Server setup completed successfully!${NC}\n"
    
    echo -e "${BLUE}Installed Components:${NC}"
    echo "• Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    echo "• Docker Compose: $(docker-compose --version | cut -d' ' -f4 | cut -d',' -f1)"
    echo "• AWS CLI: $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
    
    echo -e "\n${BLUE}Project Configuration:${NC}"
    echo "• Environment: $ENVIRONMENT"
    echo "• Project User: $PROJECT_USER"
    echo "• Project Directory: $PROJECT_DIR"
    
    echo -e "\n${BLUE}Security:${NC}"
    echo "• Firewall: Enabled (UFW)"
    echo "• Fail2ban: Enabled"
    echo "• Log Rotation: Configured"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Configure environment variables:"
    echo "   sudo -u $PROJECT_USER cp $PROJECT_DIR/.env.$ENVIRONMENT.template $PROJECT_DIR/.env.$ENVIRONMENT"
    echo "   sudo -u $PROJECT_USER nano $PROJECT_DIR/.env.$ENVIRONMENT"
    echo ""
    echo "2. Configure AWS credentials:"
    echo "   sudo -u $PROJECT_USER aws configure"
    echo ""
    echo "3. Upload docker-compose file:"
    echo "   scp docker-compose.$ENVIRONMENT.yml user@server:$PROJECT_DIR/"
    echo ""
    echo "4. Deploy application:"
    echo "   sudo -u $PROJECT_USER $PROJECT_DIR/scripts/pull-and-deploy.sh"
    
    echo -e "\n${BLUE}Useful Commands:${NC}"
    echo "• Monitor system: $PROJECT_DIR/scripts/monitor.sh"
    echo "• Check firewall: sudo ufw status"
    echo "• Check fail2ban: sudo fail2ban-client status"
    echo "• Switch to project user: sudo -u $PROJECT_USER -i"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -e, --env ENV       Environment (default: production)"
    echo "  -u, --user USER     Project user (default: yendorcats)"
    echo "  --skip-firewall     Skip firewall configuration"
    echo "  --skip-monitoring   Skip monitoring tools installation"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT         Deployment environment"
    echo "  PROJECT_USER        Project user name"
    echo ""
    echo "Examples:"
    echo "  $0                  # Setup production server"
    echo "  $0 -e staging       # Setup staging server"
    echo "  $0 -u myuser        # Use custom project user"
}

# Main execution
main() {
    local skip_firewall=false
    local skip_monitoring=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -u|--user)
                PROJECT_USER="$2"
                shift 2
                ;;
            --skip-firewall)
                skip_firewall=true
                shift
                ;;
            --skip-monitoring)
                skip_monitoring=true
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
    echo "║                YendorCats Server Setup                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    print_info "Environment: $ENVIRONMENT"
    print_info "Project User: $PROJECT_USER"
    print_info "Project Directory: $PROJECT_DIR"
    
    check_root
    update_system
    install_docker
    install_docker_compose
    install_aws_cli
    create_project_user
    
    if [[ "$skip_firewall" == false ]]; then
        configure_firewall
        configure_fail2ban
    fi
    
    setup_log_rotation
    create_environment_template
    create_directory_structure
    
    if [[ "$skip_monitoring" == false ]]; then
        install_monitoring
    fi
    
    show_setup_summary
    
    print_header "Setup Complete"
    print_success "YendorCats server is ready for deployment!"
}

# Run main function
main "$@"
