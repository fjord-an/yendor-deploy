# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

YendorCats deployment framework is a Docker-based production deployment system for the YendorCats.com cat breeding website. The system uses a microservices architecture with Nginx reverse proxy, .NET Core API, React frontend, file uploader service, MariaDB database, and comprehensive logging infrastructure.

**Key Technologies:**
- Docker & Docker Compose for containerization
- Nginx with SSL termination and security headers
- AWS ECR (ap-southeast-2 region) for container registry
- Backblaze B2 for file storage and log archiving
- MariaDB for data persistence
- Fluentd for structured logging

## Architecture

```
Internet
    ↓
Nginx (Port 443/80)
    ↓
┌─────────────────────────────────────┐
│  YendorCats Network                 │
│  ┌─────────────┐  ┌──────────────┐  │
│  │  Frontend   │  │  API (.NET)  │  │
│  │  (React)    │  │  (Port 80)   │  │
│  │  (Port 80)  │  └──────────────┘  │
│  └─────────────┘          │         │
│         │                 │         │
│  ┌─────────────┐  ┌──────────────┐  │
│  │  Uploader   │  │   MariaDB    │  │
│  │  Service    │  │  (Port 3306) │  │
│  │  (Port 80)  │  └──────────────┘  │
│  └─────────────┘                    │
└─────────────────────────────────────┘
    ↓
Log Exporter → Backblaze B2
```

**Service URLs:**
- `/` → Frontend (React application)
- `/api/` → Backend API (.NET Core)
- `/upload/` → File upload service
- `/health` → Health checks

## Common Development Commands

### Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Edit environment variables (use Rider for complex editing)
# Ensure AWS region is set to ap-southeast-2
nano .env
```

### Container Management
```bash
# View container status
docker-compose -f docker-compose.production.yml ps

# View real-time logs
docker-compose -f docker-compose.production.yml logs -f

# View logs for specific service
docker-compose -f docker-compose.production.yml logs -f api
docker-compose -f docker-compose.production.yml logs -f frontend

# Check container health
docker-compose -f docker-compose.production.yml ps
docker stats --no-stream

# Shell access to containers
docker-compose -f docker-compose.production.yml exec api /bin/bash
docker-compose -f docker-compose.production.yml exec db mysql -u root -p
```

### Deployment Commands

#### Standard Deployment
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Full deployment (pulls latest images, restarts services)
./scripts/deploy.sh

# Deploy with specific image tag
./deploy-with-tag.sh <git-commit-hash>
# Example: ./deploy-with-tag.sh 74cde28
```

#### Manual Container Operations
```bash
# Pull latest images from ECR
docker-compose -f docker-compose.production.yml pull

# Stop all services
docker-compose -f docker-compose.production.yml down

# Start services in background
docker-compose -f docker-compose.production.yml up -d

# Restart specific service
docker-compose -f docker-compose.production.yml restart api
```

#### Image Management
```bash
# Update compose file with specific tag
./update-compose-tag.sh <commit-hash>

# View current images in use
docker-compose -f docker-compose.production.yml images

# Remove unused images (cleanup)
docker image prune -a
```

### Monitoring and Debugging

#### Health Checks
```bash
# System overview
./scripts/monitor.sh

# Manual health checks
curl http://localhost/health
curl http://localhost/api/health
curl http://localhost/upload/health

# Test HTTPS (with self-signed cert warning)
curl -k https://localhost/health
```

#### Database Operations
```bash
# Connect to database
docker-compose -f docker-compose.production.yml exec db mysql -u root -p YendorCats

# Create database backup
./scripts/backup.sh

# View database logs
docker-compose -f docker-compose.production.yml logs db
```

#### Log Analysis
```bash
# View nginx access logs
docker-compose -f docker-compose.production.yml exec nginx tail -f /var/log/nginx/access.log

# View nginx error logs
docker-compose -f docker-compose.production.yml exec nginx tail -f /var/log/nginx/error.log

# View API application logs
docker-compose -f docker-compose.production.yml logs -f api

# Check log exporter status
docker-compose -f docker-compose.production.yml logs log-exporter
```

## Environment Variables

### Required Variables (.env file)
```bash
# Database Configuration
MYSQL_ROOT_PASSWORD=secure_root_password
MYSQL_USER=yendorcats_user
MYSQL_PASSWORD=secure_user_password

# AWS/Backblaze B2 Configuration (ap-southeast-2 region)
AWS_S3_BUCKET_NAME=yendor
AWS_S3_ACCESS_KEY=your_b2_key_id
AWS_S3_SECRET_KEY=your_b2_application_key
B2_APPLICATION_KEY_ID=your_b2_key_id
B2_APPLICATION_KEY=your_b2_application_key
B2_BUCKET_ID=your_bucket_id
B2_BUCKET_NAME=yendor

# Application Security
YENDOR_JWT_SECRET=your_jwt_secret_256_bit_key
```

### AWS ECR Authentication
The deployment system uses AWS ECR in ap-southeast-2 region:
```bash
# ECR login (handled by deploy.sh)
/usr/local/bin/ecr-login.sh

# Manual ECR login if needed
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin \
  025066273203.dkr.ecr.ap-southeast-2.amazonaws.com
```

## SSL/TLS Configuration

The system uses self-signed certificates for development. For production:

1. Place certificates in `ssl/` directory:
   - `nginx-selfsigned.crt`
   - `nginx-selfsigned.key`

2. Update nginx configuration if using different certificate names

3. The nginx container automatically redirects HTTP to HTTPS

## Troubleshooting

### Common Issues

#### API Container Won't Start
```bash
# Check API logs for startup errors
docker-compose logs api

# Verify database connection
docker-compose exec db mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} YendorCats

# Check API environment variables
docker-compose exec api env | grep -E "(DB_|AWS_)"
```

#### Database Connection Issues
```bash
# Verify database is running
docker-compose ps db

# Test database connectivity
docker-compose exec api ping db

# Check database logs
docker-compose logs db

# Manual database connection test
docker-compose exec db mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD}
```

#### File Upload Issues
```bash
# Check uploader service status
docker-compose logs uploader

# Verify B2 configuration
docker-compose exec uploader env | grep -E "(AWS_|B2_)"

# Test uploader health endpoint
curl http://localhost/upload/health
```

#### SSL/Certificate Issues
```bash
# Check nginx SSL configuration
docker-compose exec nginx nginx -t

# View nginx error logs for SSL issues
docker-compose logs nginx

# Test SSL connectivity
openssl s_client -connect localhost:443 -servername yendorcats.com
```

### Performance Issues

#### High Memory Usage
```bash
# Check container resource usage
docker stats

# Check database performance
docker-compose exec db mysql -u root -p -e "SHOW PROCESSLIST;"

# Review API memory usage
docker-compose logs api | grep -i memory
```

#### Slow Response Times
```bash
# Check nginx access logs for response times
docker-compose exec nginx tail -f /var/log/nginx/access.log

# Monitor container health
docker-compose ps
docker stats --no-stream
```

## File Structure

```
├── docker-compose.production.yml    # Main production configuration
├── nginx/
│   ├── Dockerfile                   # Nginx container build
│   └── nginx.conf                   # Reverse proxy configuration
├── scripts/
│   ├── deploy.sh                    # Main deployment script
│   ├── backup.sh                    # Database backup
│   ├── monitor.sh                   # System monitoring
│   └── update.sh                    # Update automation
├── fluentd/
│   ├── Dockerfile                   # Log aggregation container
│   └── fluent.conf                  # Logging configuration
├── deploy-with-tag.sh               # Deploy with specific image tag
├── update-compose-tag.sh            # Update compose with image tag
├── fix-api-startup.sh               # API container startup fix
└── .env.example                     # Environment template
```

## Security Considerations

- All sensitive data should be in `.env` file (never committed)
- ECR images are private and require authentication
- Nginx implements security headers and rate limiting
- Database access is restricted to application containers
- SSL/TLS termination at nginx level
- Log export to secure B2 storage with encryption

## Development Workflow

1. **Environment Setup**: Copy `.env.example` to `.env` and configure
2. **Local Testing**: Use docker-compose for local development
3. **Image Updates**: Deploy with specific commit tags using `deploy-with-tag.sh`
4. **Monitoring**: Use `monitor.sh` for health checks
5. **Backup**: Regular backups via `backup.sh`
6. **Rider Integration**: Use Rider IDE for .NET development and debugging

When working in Rider:
- Docker plugin provides container management UI
- Database plugin can connect to MariaDB container
- Terminal integration for running deployment scripts
- Built-in git integration for commit-based deployments
