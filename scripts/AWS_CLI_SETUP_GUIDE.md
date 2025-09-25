---
id: aws-cli-setup-guide
title: "AWS CLI Setup Guide for YendorCats"
description: "Step-by-step guide for setting up AWS CLI for YendorCats deployment automation"
company: "PaceySpace"
author: "Jordan Pacey"
owner: "jordan@paceyspace.com"
version: "1.0.0"
created: "2025-01-27"
updated: "2025-01-27"
status: "active"
type: "setup-guide"
project: "yendorcats"
area: "devops/aws"
aws_services: ["CLI", "ECR", "IAM", "S3"]
technologies: ["AWS CLI", "bash", "macOS", "Ubuntu"]
tags: ["aws", "cli", "setup", "configuration", "ecr", "iam", "credentials"]
---

# AWS CLI Setup Guide for YendorCats

## Overview

This guide walks you through setting up the AWS CLI for YendorCats deployment automation. The AWS CLI is essential for authenticating with ECR, managing resources, and running deployment scripts.

## Prerequisites

- **Operating System**: macOS or Linux (Ubuntu/Debian)
- **Internet Connection**: Required for downloading and authentication
- **AWS Account**: Access to AWS account 025066273203
- **Permissions**: IAM user with appropriate permissions

## Installation

### macOS (Homebrew)

```bash
# Install using Homebrew (recommended)
brew install awscli

# Verify installation
aws --version
```

### macOS (Official Installer)

```bash
# Download and install official AWS CLI v2
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Verify installation
aws --version
```

### Ubuntu/Debian Linux

```bash
# Update package list
sudo apt update

# Install dependencies
sudo apt install -y curl unzip

# Download AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Extract and install
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version

# Cleanup
rm -rf awscliv2.zip aws/
```

## Configuration

### Method 1: Interactive Configuration (Recommended for Development)

```bash
# Run interactive configuration
aws configure

# You'll be prompted for:
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]
# Default region name: ap-southeast-2
# Default output format: json
```

### Method 2: Environment Variables (Recommended for Servers)

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="your_access_key_here"
export AWS_SECRET_ACCESS_KEY="your_secret_key_here"
export AWS_DEFAULT_REGION="ap-southeast-2"

# Add to shell profile for persistence
echo 'export AWS_ACCESS_KEY_ID="your_access_key_here"' >> ~/.bashrc
echo 'export AWS_SECRET_ACCESS_KEY="your_secret_key_here"' >> ~/.bashrc
echo 'export AWS_DEFAULT_REGION="ap-southeast-2"' >> ~/.bashrc

# Reload shell configuration
source ~/.bashrc
```

### Method 3: AWS Credentials File

```bash
# Create credentials directory
mkdir -p ~/.aws

# Create credentials file
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = your_access_key_here
aws_secret_access_key = your_secret_key_here
EOF

# Create config file
cat > ~/.aws/config << EOF
[default]
region = ap-southeast-2
output = json
EOF

# Set appropriate permissions
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config
```

## Required IAM Permissions

Your AWS user needs the following permissions for YendorCats deployment:

### ECR Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchDeleteImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage",
                "ecr:CreateRepository"
            ],
            "Resource": "*"
        }
    ]
}
```

### S3 Permissions (for Backblaze B2)
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::yendor",
                "arn:aws:s3:::yendor/*"
            ]
        }
    ]
}
```

## Verification

### Test Basic Authentication

```bash
# Test AWS CLI authentication
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "025066273203",
#     "Account": "025066273203",
#     "Arn": "arn:aws:iam::025066273203:user/your-username"
# }
```

### Test ECR Access

```bash
# Test ECR authentication
aws ecr get-login-password --region ap-southeast-2

# Test ECR repository access
aws ecr describe-repositories --region ap-southeast-2

# Test ECR login with Docker
aws ecr get-login-password --region ap-southeast-2 | \
    docker login --username AWS --password-stdin \
    025066273203.dkr.ecr.ap-southeast-2.amazonaws.com
```

### Run Verification Script

```bash
# Use the automated verification script
./scripts/aws/verify-aws-setup.sh
```

## Troubleshooting

### Common Issues

#### 1. "Unable to locate credentials"
```bash
# Check if credentials are configured
aws configure list

# Reconfigure if needed
aws configure
```

#### 2. "An error occurred (UnauthorizedOperation)"
```bash
# Check IAM permissions
aws iam get-user

# Contact AWS administrator to verify permissions
```

#### 3. "Region not found"
```bash
# Set correct region
aws configure set region ap-southeast-2

# Or use environment variable
export AWS_DEFAULT_REGION=ap-southeast-2
```

#### 4. "Docker login failed"
```bash
# Check Docker is running
docker info

# Try ECR login again
aws ecr get-login-password --region ap-southeast-2 | \
    docker login --username AWS --password-stdin \
    025066273203.dkr.ecr.ap-southeast-2.amazonaws.com
```

### Debug Commands

```bash
# Check AWS CLI version
aws --version

# Check current configuration
aws configure list

# Check current identity
aws sts get-caller-identity

# Test specific service access
aws ecr describe-repositories --region ap-southeast-2
aws s3 ls s3://yendor/

# Enable debug logging
aws --debug sts get-caller-identity
```

## Security Best Practices

### 1. Credential Management
- **Never commit credentials** to version control
- **Use environment variables** on servers
- **Rotate credentials** regularly
- **Use IAM roles** when possible (EC2 instances)

### 2. Permissions
- **Follow principle of least privilege**
- **Use specific resource ARNs** instead of wildcards
- **Regularly audit permissions**
- **Remove unused access keys**

### 3. Monitoring
- **Enable CloudTrail** for API logging
- **Monitor unusual access patterns**
- **Set up billing alerts**
- **Review access logs** regularly

## Server Setup

### Production Server Configuration

```bash
# Install AWS CLI on Ubuntu server
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure using environment variables (more secure for servers)
sudo -u yendorcats aws configure set region ap-southeast-2
sudo -u yendorcats aws configure set output json

# Set credentials via environment variables in .env file
echo "AWS_ACCESS_KEY_ID=your_key_here" >> /opt/yendorcats/.env.production
echo "AWS_SECRET_ACCESS_KEY=your_secret_here" >> /opt/yendorcats/.env.production
```

### Staging Server Configuration

```bash
# Same as production but with staging environment
echo "AWS_ACCESS_KEY_ID=your_key_here" >> /opt/yendorcats/.env.staging
echo "AWS_SECRET_ACCESS_KEY=your_secret_here" >> /opt/yendorcats/.env.staging
```

## Integration with YendorCats Scripts

Once AWS CLI is configured, you can use the YendorCats deployment scripts:

```bash
# Verify setup
./scripts/aws/verify-aws-setup.sh

# Login to ECR
./scripts/aws/ecr-login.sh

# Build and push images
./scripts/deploy/build-and-push.sh

# Deploy to staging
./scripts/deploy/deploy-staging.sh

# Deploy to production
./scripts/deploy/deploy-production.sh
```

## Support

### Getting Help

- **AWS CLI Documentation**: https://docs.aws.amazon.com/cli/
- **YendorCats Scripts**: Check script help with `--help` flag
- **IAM Permissions**: Contact AWS administrator
- **Technical Issues**: jordan@paceyspace.com

### Useful Resources

- **AWS CLI Command Reference**: https://docs.aws.amazon.com/cli/latest/reference/
- **ECR User Guide**: https://docs.aws.amazon.com/ecr/
- **IAM Best Practices**: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

---

### Tags
#aws #cli #setup #configuration #ecr #iam #credentials #deployment #yendorcats

---
