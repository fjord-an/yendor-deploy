# YendorCats Deployment Repository

This repository contains deployment scripts, Docker configurations, and infrastructure code for the YendorCats application.

## 🔒 Security Notice

This repository is designed to be **PUBLIC-SAFE** - all sensitive information has been excluded via `.gitignore`. 

### What's Included ✅
- Docker Compose templates
- Deployment scripts
- Nginx configurations (sanitized)
- Dockerfile configurations
- Infrastructure as Code
- Documentation

### What's Excluded ❌
- Environment variables (`.env` files)
- SSL certificates and private keys
- Database backups
- Log files
- All backup files
- Any files containing secrets or credentials

## 🚀 Setup Instructions

1. Clone this repository
2. Copy `.env.example` to `.env`
3. Fill in your actual environment variables in `.env`
4. Configure your SSL certificates (not included in repo)
5. Run deployment scripts

## 📁 Repository Structure

```
├── docker-compose.production.yml    # Main production configuration
├── docker-compose.production.yml.template  # Template version
├── scripts/                        # Deployment and maintenance scripts
├── nginx/                          # Nginx configuration
├── fluentd/                        # Logging configuration  
├── frontend/                       # Frontend server configs
└── .env.example                    # Environment template
```

## ⚠️ Important Security Notes

- **NEVER** commit your actual `.env` file
- **ALWAYS** use the `.env.example` template for new deployments
- Review deployment scripts before running in production
- Ensure SSL certificates are properly secured outside this repository
- Database backups are automatically excluded from version control

## 📝 License

See [LICENSE](LICENSE) file for details.
