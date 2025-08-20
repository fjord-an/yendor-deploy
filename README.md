# YendorCats.com - Website Deployment Framework

This repository contains the deployment infrastructure, Docker configurations, and technical framework for the YendorCats.com cat breeding website.

## 🚀 **Quick Start**

### Prerequisites
- Docker and Docker Compose installed
- SSL certificates configured separately  
- Environment variables prepared
- Database access configured

### Deployment Steps
1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd yendorcats.com
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your specific values
   ```

3. **Deploy Application**
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```

---

## 🔒 Security Notice

This repository is designed to be **PUBLIC-SAFE** - all sensitive information has been excluded via comprehensive `.gitignore` rules. 

### What's Included ✅
- Docker Compose framework and templates
- Deployment automation scripts  
- Nginx configurations (sanitized)
- Infrastructure as Code components
- Technical documentation

### What's Excluded ❌
- Environment variables (`.env` files)
- SSL certificates and private keys
- Database backups with client data
- Log files with sensitive information
- All backup files containing production data

---

## 📁 **Repository Structure**

```
├── LICENSE                            # Licensing terms
├── docker-compose.production.yml      # Main production configuration
├── scripts/                          # Deployment automation
│   ├── deploy.sh                    # Main deployment script
│   ├── backup.sh                    # Database backup automation  
│   ├── monitor.sh                   # System monitoring
│   └── update.sh                    # Update automation
├── nginx/                            # Web server configuration
├── fluentd/                          # Logging and monitoring
├── ssl/                              # SSL certificates (not tracked)
├── legal/                            # IP and licensing documentation
├── .env.example                      # Environment template
└── .gitignore                        # Comprehensive security exclusions
```

---

## 🛠️ **Technical Framework Components**

This deployment framework includes enterprise-grade components:

### Infrastructure & DevOps
- **Docker containerization** with multi-service orchestration
- **Automated deployment scripts** with rollback capabilities  
- **Nginx reverse proxy** with SSL termination
- **Database backup automation** with retention policies
- **System monitoring and logging** with Fluentd integration
- **Environment management** with secure variable handling

### Security & Performance  
- **SSL/TLS encryption** with automatic certificate management
- **Security headers** and best practice implementations
- **Performance optimization** with caching strategies
- **Database security** with access controls and encryption
- **Logging and audit trails** for security monitoring

### Scalability Features
- **Container orchestration** ready for horizontal scaling
- **Load balancer configuration** for high availability
- **Database clustering support** for enterprise deployments
- **CDN integration points** for global content delivery
- **Microservice architecture** for modular deployment

---

## ⚙️ **Configuration Management**

### Environment Variables (.env)
```bash
# Application Settings
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yendorcats.com

# Database Configuration  
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=yendorcats_db
DB_USERNAME=your_db_user
DB_PASSWORD=your_secure_password

# SSL Configuration
SSL_CERT_PATH=/etc/ssl/certs/yendorcats.com.crt
SSL_KEY_PATH=/etc/ssl/private/yendorcats.com.key

# Monitoring & Logging
LOG_LEVEL=info
MONITORING_ENABLED=true
```

### Docker Services
- **Web Application:** Main application container
- **Database:** MariaDB/MySQL database server
- **Nginx:** Reverse proxy and static file server
- **Fluentd:** Log aggregation and monitoring
- **Redis:** Session storage and caching (optional)

---

## 🔧 **Development & Maintenance**

### Available Scripts
```bash
# Deployment and updates
./scripts/deploy.sh          # Full deployment with health checks
./scripts/update.sh          # Update application containers only

# Maintenance operations  
./scripts/backup.sh          # Create database backup
./scripts/monitor.sh         # Check system health and status

# Development utilities
docker-compose logs -f       # View real-time logs
docker-compose ps           # Check container status
docker-compose down         # Stop all services
```

### Monitoring & Health Checks
- **Container health monitoring** with automatic restart policies
- **Database connectivity checks** with alerting
- **SSL certificate expiration monitoring**
- **Disk space and resource utilization tracking**
- **Application performance metrics** and logging

---

## ⚠️ **Important Security Notes**

### For Developers
- **NEVER** commit actual `.env` files or production secrets
- **ALWAYS** use `.env.example` as template for new deployments
- **REVIEW** all deployment scripts before running in production environments
- **ENSURE** SSL certificates are properly secured outside version control

---

## 📞 **Contact & Support**

### Technical Issues
- **Framework Support:** admin@paceyspace.com
- **Repository Issues:** Use GitHub issues for technical problems

### Client-Specific Support  
- **Yendor Cat Breeding Enterprise:** [client-email]
- **Business Issues:** Direct client communication

---

## 📜 **License**

See [LICENSE](LICENSE) file for terms.

---

**Framework developed by PaceySpace**  
**Client: Yendor Cat Breeding Enterprise**

**Template Framework Version:** 1.0  
**Last Updated:** August 2025  
**Compatible With:** Docker 20+, Docker Compose 2.0+
