# 🚀 AWS TERRAFORM VPN - COMPLETE END-TO-END SETUP & EXECUTION GUIDE

## 📑 Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Complete Step-by-Step Setup](#complete-step-by-step-setup)
3. [Exact Execution Commands](#exact-execution-commands)
4. [Deployment Scenarios](#deployment-scenarios)
5. [AWS Service Account Details](#aws-service-account-details)
6. [Jenkins Configuration Details](#jenkins-configuration-details)
7. [Monitoring & Verification](#monitoring--verification)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Architecture Overview

### Infrastructure Design
```
┌─────────────────────────────────────────────────────────────┐
│                       AWS Account                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          DEV Environment (10.0.0.0/16)               │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │  Public Subnets (2)       Private Subnets (2)        │   │
│  │  ┌────────────────┐       ┌────────────────┐        │   │
│  │  │ 10.0.1.0/24    │       │ 10.0.10.0/24   │        │   │
│  │  │ (us-east-1a)   │       │ (us-east-1a)   │        │   │
│  │  └────────────────┘       └────────────────┘        │   │
│  │  ┌────────────────┐       ┌────────────────┐        │   │
│  │  │ 10.0.2.0/24    │       │ 10.0.11.0/24   │        │   │
│  │  │ (us-east-1b)   │       │ (us-east-1b)   │        │   │
│  │  └────────────────┘       └────────────────┘        │   │
│  │  ↓ IGW (Internet Gateway)  ↓ NAT Gateways           │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          UAT Environment (10.1.0.0/16)               │   │
│  │          (Similar structure as DEV)                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          PROD Environment (10.2.0.0/16)              │   │
│  │          (3 AZ HA Setup)                             │   │
│  │          (3 Public + 3 Private Subnets)              │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │       S3 Bucket & DynamoDB for State Management      │   │
│  │  dev-terraform-state          terraform-locks-dev    │   │
│  │  uat-terraform-state          terraform-locks-uat    │   │
│  │  prod-terraform-state         terraform-locks-prod   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Jenkins CI/CD Pipeline                    │
├─────────────────────────────────────────────────────────────┤
│  Checkout → Validate → Init → Plan → Approval → Apply/Destroy │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                        │
├─────────────────────────────────────────────────────────────┤
│  main branch → Jenkinsfile → Pipeline Trigger               │
└─────────────────────────────────────────────────────────────┘
```

### Services Architecture
```
GitHub                  Jenkins                    AWS
  ↓                       ↓                         ↓
Code Push          Pipeline Trigger           terraform-automation
  ↓                       ↓                     (IAM User)
Webhook      →    Build with Parameters    →    Access Key
             →    Checkout Code            →    + Secret Key
             →    Terraform Init/Plan/Apply →  EC2, VPC, NAT
             →    AWS Credentials         →    Route Tables
             →    Store State in S3       →    Subnets, IGW
```

---

## Complete Step-by-Step Setup

### PHASE 1: Prerequisites (30 minutes)

#### Step 1.1: Install Required Tools
```powershell
# Windows PowerShell as Administrator

# Install Terraform
choco install terraform -y
terraform -v

# Install AWS CLI
choco install awscli -y
aws --version

# Install Git
choco install git -y
git --version

# Verify Docker (optional, for Jenkins)
choco install docker-desktop -y
docker --version
```

#### Step 1.2: Create Local Project Folder
```powershell
# Create project directory
New-Item -ItemType Directory -Path "C:\Projects\aws_terraform_vpn" -Force
cd C:\Projects\aws_terraform_vpn

# Initialize Git
git init
git config user.name "Your Name"
git config user.email "your@email.com"
```

#### Step 1.3: Configure AWS CLI
```bash
# Configure AWS credentials
aws configure

# When prompted, enter:
# AWS Access Key ID: (from your AWS root account)
# AWS Secret Access Key: (from your AWS root account)
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:root"
}
```

---

### PHASE 2: AWS Service Account Setup (20 minutes)

#### Step 2.1: Create IAM User for Terraform

```bash
# Create user
aws iam create-user --user-name terraform-automation

# Create access keys
aws iam create-access-key --user-name terraform-automation > terraform-user-keys.json

# Display credentials (SAVE SECURELY!)
cat terraform-user-keys.json

# You'll see:
# {
#     "AccessKey": {
#         "UserName": "terraform-automation",
#         "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
#         "Status": "Active",
#         "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
#         "CreateDate": "2024-01-15T10:30:00+00:00"
#     }
# }
```

#### Step 2.2: Create and Attach IAM Policy

```bash
# Create policy document
cat > terraform-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformVPC",
      "Effect": "Allow",
      "Action": [
        "ec2:*Vpc*",
        "ec2:*Subnet*",
        "ec2:*InternetGateway*",
        "ec2:*NatGateway*",
        "ec2:*RouteTable*",
        "ec2:*Route",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:CreateTags",
        "ec2:DescribeTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3StateBackend",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::*-terraform-state",
        "arn:aws:s3:::*-terraform-state/*"
      ]
    },
    {
      "Sid": "DynamoDBStateLock",
      "Effect": "Allow",
      "Action": [
        "dynamodb:*"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks*"
    }
  ]
}
EOF

# Attach policy to user
aws iam put-user-policy \
  --user-name terraform-automation \
  --policy-name TerraformManagement \
  --policy-document file://terraform-policy.json
```

#### Step 2.3: Verify IAM Setup

```bash
# Verify user exists
aws iam get-user --user-name terraform-automation

# Verify policy attached
aws iam get-user-policy \
  --user-name terraform-automation \
  --policy-name TerraformManagement

# List access keys
aws iam list-access-keys --user-name terraform-automation
```

**Expected Output:** User created with policy attached successfully

---

### PHASE 3: S3 Backend Configuration (25 minutes)

#### Step 3.1: Create S3 Buckets

```bash
# For DEV environment
aws s3 mb s3://dev-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket dev-terraform-state \
  --versioning-configuration Status=Enabled

# For UAT environment
aws s3 mb s3://uat-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket uat-terraform-state \
  --versioning-configuration Status=Enabled

# For PROD environment
aws s3 mb s3://prod-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket prod-terraform-state \
  --versioning-configuration Status=Enabled
```

#### Step 3.2: Enable Encryption on S3 Buckets

```bash
# For each environment
for BUCKET in dev-terraform-state uat-terraform-state prod-terraform-state; do
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
done
```

#### Step 3.3: Create DynamoDB Tables for State Locking

```bash
# Create lock table for DEV
aws dynamodb create-table \
  --table-name terraform-locks-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Wait for table
aws dynamodb wait table-exists --table-name terraform-locks-dev

# Create lock table for UAT
aws dynamodb create-table \
  --table-name terraform-locks-uat \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

aws dynamodb wait table-exists --table-name terraform-locks-uat

# Create lock table for PROD
aws dynamodb create-table \
  --table-name terraform-locks-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

aws dynamodb wait table-exists --table-name terraform-locks-prod
```

#### Step 3.4: Verify Backend Setup

```bash
# Verify S3 buckets
aws s3 ls | grep terraform-state

# Expected output:
# dev-terraform-state
# prod-terraform-state
# uat-terraform-state

# Verify DynamoDB tables
aws dynamodb list-tables --region us-east-1

# Expected output should include:
# terraform-locks-dev
# terraform-locks-prod
# terraform-locks-uat
```

---

### PHASE 4: Jenkins Server Setup (35 minutes)

#### Option A: Windows Service Installation

```powershell
# 1. Download Jenkins MSI
# https://mirrors.jenkins.io/windows-latest/jenkins.msi

# 2. Run installer
# Installation directory: C:\Program Files\Jenkins
# Port: 8080
# Run as service: Yes

# 3. Access Jenkins
# Open browser: http://localhost:8080

# 4. Get initial admin password
$initialPassword = Get-Content "C:\Program Files\Jenkins\secrets\initialAdminPassword"
Write-Host "Jenkins Initial Admin Password: $initialPassword"

# 5. Complete setup wizard
# - Install suggested plugins
# - Create first admin user
# - Configure instance URL
```

#### Option B: Docker Installation

```bash
# Pull Jenkins image
docker pull jenkins/jenkins:latest

# Run Jenkins container
docker run -d `
  --name jenkins `
  -p 8080:8080 `
  -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  jenkins/jenkins:latest

# Get initial admin password
docker logs jenkins | Select-String "password to unlock Jenkins"

# Access: http://localhost:8080
```

#### Step 4.1: Initialize Jenkins

1. Navigate to `http://localhost:8080`
2. Enter initial admin password
3. Select "Install suggested plugins"
4. Wait for plugin installation (5-10 minutes)
5. Create first admin user:
   - Full name: `Jenkins Admin`
   - Username: `admin`
   - Password: `(use strong password)`
   - Email: `jenkins@company.com`
6. Configure Jenkins instance URL: `http://localhost:8080/`
7. Start using Jenkins

#### Step 4.2: Install Required Plugins

1. Go to **Manage Jenkins** → **Plugin Manager** → **Available plugins**
2. Search for and install:

```
Pipeline
Pipeline: Declarative
Git
GitHub
AWS Credentials
Credentials Binding
Email Extension
Timestamper
AnsiColor
```

#### Step 4.3: Configure Global Tools

1. Go to **Manage Jenkins** → **Global Tool Configuration**
2. Configure Git:
   - Path: `C:\Program Files\Git\bin\git.exe` (Windows)
   - Or `/usr/bin/git` (Linux)
3. Click **Save**

---

### PHASE 5: Add Credentials to Jenkins (20 minutes)

#### Step 5.1: Add AWS Credentials

From the Terraform user keys file:
```json
{
    "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
    "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}
```

In Jenkins:
1. Go to **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials (unrestricted)**
2. Click **Add Credentials** → **Create**

Configure:
- **Kind**: AWS Credentials
- **Access Key ID**: `AKIAIOSFODNN7EXAMPLE`
- **Secret Access Key**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
- **ID**: `aws-service-account`
- **Description**: `AWS Terraform Service Account Credentials`

Click **Create**

#### Step 5.2: Add GitHub Credentials

1. Create GitHub Personal Access Token:
   - GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token"
   - Name: `jenkins-terraform-deployment`
   - Scopes check:
     - ✓ repo (full control of private repositories)
     - ✓ admin:repo_hook (write access to hooks)
   - Click "Generate token"
   - **Copy token immediately!**

2. In Jenkins:
   - Go to **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
   - Click **Add Credentials** → **Create**

Configure:
- **Kind**: Username with password
- **Username**: `your-github-username`
- **Password**: `(paste your personal access token here)`
- **ID**: `github-credentials`
- **Description**: `GitHub Personal Access Token for Terraform Repo`

Click **Create**

#### Step 5.3: Verify Credentials

Jenkins → **Manage Credentials** → **System** → **Global credentials**

You should see:
```
✓ aws-service-account (AWS Credentials)
✓ github-credentials (Username with password)
```

---

### PHASE 6: Create Jenkins Pipeline Job (25 minutes)

#### Step 6.1: Create New Pipeline Job

1. Jenkins Dashboard → **New Item**
2. Enter name: `AWS-Terraform-VPN-Pipeline`
3. Select **Pipeline**
4. Click **OK**

#### Step 6.2: Configure General Settings

**General Tab:**
- ✓ Description: `AWS VPN Infrastructure Automation - Terraform Pipeline`
- ✓ GitHub project checked
- Project URL: `https://github.com/YOUR_ORG/aws_terraform_vpn`

#### Step 6.3: Configure Build Triggers

**Build Triggers Tab:**
- ✓ Check "GitHub hook trigger for GITScm polling"
- This enables automatic build on GitHub push

#### Step 6.4: Configure Pipeline

**Pipeline Tab:**
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/YOUR_ORG/aws_terraform_vpn.git`
- **Credentials**: Select `github-credentials`
- **Branch Specifier**: `*/main` (or your default branch)
- **Script Path**: `Jenkinsfile`

Click **Save**

#### Step 6.5: Test Pipeline Job

1. Click **Build with Parameters**
2. Select:
   - ENVIRONMENT: `dev`
   - ACTION: `plan`
   - AUTO_APPROVE: unchecked
3. Click **Build**
4. Monitor **Console Output**

Expected output:
```
[Pipeline] Start of Pipeline
[Pipeline] node
[Pipeline] stage(Checkout)
[Pipeline] checkout scm
...
[Pipeline] stage(Terraform Plan)
...
✅ Terraform plan completed
```

---

## Exact Execution Commands

### LOCAL SETUP AND DEPLOYMENT

#### Initialize Terraform (First Time)

```powershell
# 1. Navigate to project
cd C:\Projects\aws_terraform_vpn

# 2. Set AWS credentials
$env:AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
$env:AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
$env:AWS_REGION = "us-east-1"

# 3. Initialize Terraform (DEV - LOCAL)
terraform init -var-file="resources/dev/terraform.tfvars"

# Output should show:
# Terraform has been successfully configured!
# You may now begin working with Terraform.
```

#### Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output:
# Success! The configuration is valid.

# Check formatting
terraform fmt -recursive -check .

# Format code
terraform fmt -recursive .
```

#### Plan DEV Environment

```bash
# Generate plan
terraform plan `
  -var-file="resources/dev/terraform.tfvars" `
  -out=tfplan-dev.tfplan

# View plan in human-readable format
terraform show tfplan-dev.tfplan

# Export as text for review
terraform show -no-color tfplan-dev.tfplan > tfplan-dev.txt
```

#### Apply DEV Environment

```bash
# Apply the plan
terraform apply tfplan-dev.tfplan

# Output will show:
# aws_vpc.main: Creating...
# aws_internet_gateway.main: Creating...
# aws_subnet.public[0]: Creating...
# ...
# Apply complete! Resources: X added, 0 changed, 0 destroyed.
```

#### Get Outputs

```bash
# Display all outputs
terraform output

# Export to JSON
terraform output -json | ConvertFrom-Json | ConvertTo-Json > outputs-dev.json

# Get specific outputs
$vpcId = terraform output -raw vpc_id
$publicSubnets = terraform output -json public_subnet_ids
$privateSubnets = terraform output -json private_subnet_ids

Write-Host "VPC ID: $vpcId"
Write-Host "Public Subnets: $publicSubnets"
Write-Host "Private Subnets: $privateSubnets"
```

#### Plan UAT Environment

```bash
# Switch to UAT
terraform destroy -var-file="resources/dev/terraform.tfvars" -auto-approve

# Initialize for UAT
terraform init -var-file="resources/uat/terraform.tfvars"

# Plan UAT
terraform plan `
  -var-file="resources/uat/terraform.tfvars" `
  -out=tfplan-uat.tfplan

# Apply UAT
terraform apply tfplan-uat.tfplan
```

#### Plan PROD Environment

```bash
# Initialize for PROD
terraform init -var-file="resources/prod/terraform.tfvars"

# Plan PROD - Review carefully!
terraform plan `
  -var-file="resources/prod/terraform.tfvars" `
  -out=tfplan-prod.tfplan

# Show plan in detail
terraform show tfplan-prod.tfplan | more

# Apply PROD - Will require 'yes' confirmation
terraform apply tfplan-prod.tfplan

# When prompted, type: yes
```

#### Destroy Infrastructure

```bash
# Destroy DEV
terraform destroy `
  -var-file="resources/dev/terraform.tfvars" `
  -auto-approve

# Destroy UAT (with confirmation)
terraform destroy -var-file="resources/uat/terraform.tfvars"
# Type: yes

# Destroy PROD (DANGEROUS!)
terraform destroy -var-file="resources/prod/terraform.tfvars"
# Review carefully, type: yes
```

---

### JENKINS PIPELINE EXECUTION

#### Scenario 1: Deploy via Jenkins UI

**Step 1: Plan DEV**
```
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters

ENVIRONMENT: dev
ACTION: plan
AUTO_APPROVE: unchecked

Click: Build
Monitor: Console Output
Download: tfplan-dev.txt artifact
```

**Step 2: Apply DEV**
```
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters

ENVIRONMENT: dev
ACTION: apply
AUTO_APPROVE: checked (dev only!)

Click: Build
Monitor: Console Output until completion
Verify: Job #X Artifacts section
```

**Step 3: Plan UAT**
```
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters

ENVIRONMENT: uat
ACTION: plan
AUTO_APPROVE: unchecked

Click: Build
Wait for completion
Download: tfplan-uat.txt artifact
Review: Changes carefully
```

**Step 4: Apply UAT**
```
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters

ENVIRONMENT: uat
ACTION: apply
AUTO_APPROVE: unchecked

Click: Build
Wait for plan stage
Click: Approve
Monitor: Apply stage
Verify: Job #X Artifacts
```

**Step 5: Plan PROD**
```
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters

ENVIRONMENT: prod
ACTION: plan
AUTO_APPROVE: unchecked (NEVER checked for prod!)

Click: Build
HEAVILY REVIEW: tfplan-prod.txt artifact
Verify: All changes are expected
```

**Step 6: Apply PROD**
```
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters

ENVIRONMENT: prod
ACTION: apply
AUTO_APPROVE: unchecked (MUST be unchecked!)

Click: Build
Wait for plan stage
Jenkins Build will ask: "Deploy to PROD?"
Review: All details one more time
Click: Proceed (after reviewing)
Monitor: Apply stage
Verify: Successful completion
```

---

## Deployment Scenarios

### Scenario A: Complete Fresh Deployment (All Environments)

**Timeline: ~2 hours**

```bash
# Day 1: Setup
Step 1: AWS service account + IAM policy (20 min)
Step 2: S3 buckets + DynamoDB tables (25 min)
Step 3: Jenkins installation (35 min)
Step 4: Jenkins credentials (20 min)
Step 5: Pipeline job creation (25 min)

# Day 2: Deployment
Step 6: Deploy DEV (15 min) - Jenkins UI
Step 7: Deploy UAT (15 min) - Jenkins UI
Step 8: Deploy PROD (30 min) - Jenkins UI with approvals

# Verification
Step 9: Verify all environments (15 min)
Step 10: Document outputs (10 min)

TOTAL: ~3.5 hours
```

**Command Sequence:**

```bash
# DEV Pipeline
Build: ENVIRONMENT=dev, ACTION=plan → Review → Apply
Wait 5 minutes

# UAT Pipeline
Build: ENVIRONMENT=uat, ACTION=plan → Review → Apply
Wait 5 minutes

# PROD Pipeline
Build: ENVIRONMENT=prod, ACTION=plan → **REVIEW THOROUGHLY**
Build: ENVIRONMENT=prod, ACTION=apply → Approve in Jenkins
Wait 10 minutes

# Verify All
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev,uat,prod"
aws ec2 describe-subnets | grep Environment
```

### Scenario B: Update Specific Environment (DEV only)

```bash
# 1. Modify Terraform files
# Edit modules/network/main.tf or resources/dev/terraform.tfvars

# 2. Commit changes
git add .
git commit -m "Update dev network configuration"
git push origin main

# 3. Trigger pipeline
Jenkins → AWS-Terraform-VPN-Pipeline → Build with Parameters
ENVIRONMENT: dev
ACTION: plan
→ Review plan
→ Build again with ACTION: apply
→ Monitor completion

# 4. Verify
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"
terraform output vpc_id
```

### Scenario C: Disaster Recovery (Recreate PROD)

```bash
# Only if absolutely necessary!

# 1. Backup current state
aws s3 cp s3://prod-terraform-state/terraform.tfstate ./prod-backup.tfstate

# 2. Clear lock (if stuck)
aws dynamodb scan --table-name terraform-locks-prod
aws dynamodb delete-item --table-name terraform-locks-prod --key '{"LockID":{"S":"prod-terraform-state/terraform.tfstate"}}'

# 3. Destroy PROD
Jenkins → Build with Parameters
ENVIRONMENT: prod
ACTION: destroy
AUTO_APPROVE: unchecked
→ CONFIRM MULTIPLE TIMES!
→ Monitor completion

# 4. Redeploy PROD
Jenkins → Build with Parameters
ENVIRONMENT: prod
ACTION: plan
→ Review
→ Build with ACTION: apply
→ Approve
→ Monitor completion

# 5. Restore data if needed using backup
```

---

## AWS Service Account Details

### Created Resources

```
IAM User: terraform-automation
  ├── Access Key ID: AKIA...
  ├── Secret Access Key: wJalr...
  └── Inline Policy: TerraformManagement
      ├── EC2 full access
      ├── S3 access (terraform-state buckets)
      └── DynamoDB access (terraform-locks tables)

S3 Buckets:
  ├── dev-terraform-state (versioning enabled, encrypted)
  ├── uat-terraform-state (versioning enabled, encrypted)
  └── prod-terraform-state (versioning enabled, encrypted)

DynamoDB Tables:
  ├── terraform-locks-dev (LockID as primary key)
  ├── terraform-locks-uat (LockID as primary key)
  └── terraform-locks-prod (LockID as primary key)
```

### Secure Credentials Management

```bash
# Jenkins Integration
Manage Jenkins → Manage Credentials → System → Global credentials
├── aws-service-account (AWS Credentials)
│   ├── Access Key ID: ****
│   └── Secret Access Key: ****
└── github-credentials (Username with password)
    ├── Username: your-github-user
    └── Password: github_pat_****
```

### Cost Estimation

| Resource | DEV | UAT | PROD | Monthly |
|----------|-----|-----|------|---------|
| NAT Gateway | $0.045/hr = $32 | $32 | $96 | $160 |
| Elastic IP | 0.005/hr | $3.60 |$10.80 | $14.40 |
| S3 Storage | <$1 | <$1 | $2 | $3+ |
| DynamoDB | $0 | $0 | $0 | $0 |
| **Total** | **$35** | **$35** | **$109** | **$179** |

---

## Jenkins Configuration Details

### Environment Variables

```groovy
Environment {
    AWS_REGION = 'us-east-1'
    AWS_CREDENTIALS = credentials('aws-service-account')  // Injected
    GITHUB_CREDENTIALS = credentials('github-credentials') // Injected
    GIT_REPO = 'https://github.com/YOUR_ORG/aws_terraform_vpn.git'
    TERRAFORM_VERSION = '1.6.0'
    TF_VAR_FILE = "resources/${ENVIRONMENT}/terraform.tfvars"
    TF_BACKEND_BUCKET = "${ENVIRONMENT}-terraform-state"
    LOCK_TABLE = "terraform-locks-${ENVIRONMENT}"
}
```

### Pipeline Stages Explained

| Stage | Duration | Action | Output |
|-------|----------|--------|--------|
| Checkout | 30s | Clone repo from GitHub | Git commit hash |
| Validate Environment | 20s | Check vars file exists | Validation result |
| Setup Terraform | 10s | Show terraform version | Version info |
| Terraform Init | 2min | Download providers | .terraform/ dir |
| Format Check | 30s | Check code formatting | Format status |
| Terraform Validate | 30s | Validate HCL syntax | Validation result |
| Terraform Plan | 3-5min | Generate execution plan | tfplan-X.tfplan file |
| Approval | ∞ | Wait for manual approval | User input |
| Terraform Apply/Destroy | 5-10min | Execute plan | Resource changes |
| Export Outputs | 30s | Save outputs to JSON | outputs-X.json |

### Webhook Configuration (Auto-Trigger)

```
GitHub Repository Settings → Webhooks

Payload URL: http://jenkins-server:8080/github-webhook/
Content type: application/json
Events to trigger on:
  ✓ Push events
  ✓ Pull request events
SSL verification: Enable
```

---

## Monitoring & Verification

### Verify Infrastructure Creation

```bash
# List all VPCs with environment tags
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Environment`].Value|[0],CidrBlock]' --output table

# Example output:
# |  VpcId   | Environment | CidrBlock    |
# |----------|-------------|-------------|
# | vpc-xxx1 | dev         | 10.0.0.0/16 |
# | vpc-xxx2 | uat         | 10.1.0.0/16 |
# | vpc-xxx3 | prod        | 10.2.0.0/16 |

# List all subnets per environment
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,CidrBlock,Tags[?Key==`Environment`].Value|[0],Tags[?Key==`Type`].Value|[0]]' --output table

# List NAT Gateways
aws ec2 describe-nat-gateways --query 'NatGateways[*].[NatGatewayId,State,Tags[?Key==`Environment`].Value|[0]]' --output table

# Check Internet Gateways
aws ec2 describe-internet-gateways --query 'InternetGateways[*].[InternetGatewayId,Tags[?Key==`Environment`].Value|[0]]' --output table

# Verify route tables
aws ec2 describe-route-tables --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Environment`].Value|[0]]' --output table
```

### Export Complete State

```bash
# Save all outputs for documentation
terraform output -json > infrastructure-complete-state.json

# Format nicely
terraform output -json | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-File infrastructure-state.json

# Display key outputs
Write-Host "VPC IDs:"
terraform output -json vpc_id | ConvertFrom-Json

Write-Host "Public Subnets:"
terraform output -json public_subnet_ids | ConvertFrom-Json

Write-Host "Private Subnets:"
terraform output -json private_subnet_ids | ConvertFrom-Json

Write-Host "NAT Gateways:"
terraform output -json nat_gateway_ids | ConvertFrom-Json
```

### Jenkins Build Artifacts

```
Jenkins → AWS-Terraform-VPN-Pipeline → Build #X

📦 Artifacts:
  ├── tfplan-dev.txt (readable plan for dev)
  ├── tfplan-uat.txt (readable plan for uat)
  ├── tfplan-prod.txt (readable plan for prod)
  ├── outputs-dev.json (all terraform outputs)
  ├── outputs-uat.json (all terraform outputs)
  └── outputs-prod.json (all terraform outputs)

Save these for compliance documentation!
```

---

## Troubleshooting Guide

### Issue 1: AWS Credentials Not Found

**Symptom:**
```
Error: Error configuring AWS Provider: no credentials found
```

**Solution:**
```bash
# Verify credentials are set
$env:AWS_ACCESS_KEY_ID
$env:AWS_SECRET_ACCESS_KEY

# Reconfigure
aws configure

# Or set explicitly
$env:AWS_ACCESS_KEY_ID = "YOUR_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET"

# Verify
aws sts get-caller-identity
```

### Issue 2: S3 Bucket Access Denied

**Symptom:**
```
Error: Error putting object in S3 bucket
AccessDenied: Access Denied
```

**Solution:**
```bash
# Verify IAM policy
aws iam get-user-policy \
  --user-name terraform-automation \
  --policy-name TerraformManagement

# Verify bucket exists
aws s3 ls | grep terraform-state

# Check bucket permissions
aws s3api get-bucket-policy --bucket dev-terraform-state

# Re-attach policy if needed
aws iam put-user-policy \
  --user-name terraform-automation \
  --policy-name TerraformManagement \
  --policy-document file://terraform-policy.json
```

### Issue 3: DynamoDB Lock Timeout

**Symptom:**
```
Error: Error acquiring the state lock
timeout waiting for DynamoDB table to become ready
```

**Solution:**
```bash
# Check lock table status
aws dynamodb describe-table --table-name terraform-locks-dev

# Scan for stuck locks
aws dynamodb scan --table-name terraform-locks-dev --output table

# Force unlock (CAUTION!)
terraform force-unlock <LOCK_ID>

# Or delete from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-locks-dev \
  --key '{"LockID":{"S":"dev-terraform-state/terraform.tfstate"}}'
```

### Issue 4: Terraform Plan Shows No Changes

**Symptom:**
```
No changes. Infrastructure is up-to-date.
```

**Solution:**
```bash
# Refresh state
terraform refresh -var-file="resources/dev/terraform.tfvars"

# Check state file
terraform state list

# View specific resource
terraform state show aws_vpc.main

# If state is out of sync, re-import
terraform import aws_vpc.main vpc-xxxxxxxx

# Validate all resources still exist
aws ec2 describe-vpcs --vpc-ids vpc-xxxxxxxx
```

### Issue 5: Jenkins Pipeline Fails at Checkout

**Symptom:**
```
ERROR: Error cloning remote repository 'https://github.com/...'
```

**Solution:**
```bash
# Verify GitHub credentials in Jenkins
Manage Jenkins → Manage Credentials → github-credentials

# Test Git URL
git clone https://github.com/YOUR_ORG/aws_terraform_vpn.git

# Verify token has repo access
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/YOUR_ORG/aws_terraform_vpn

# Update credentials in Jenkins if needed
```

### Issue 6: Subnet CIDR Conflict

**Symptom:**
```
Error: Cannot create subnet - invalid CIDR block
```

**Solution:**
```bash
# Check existing VPC CIDR
aws ec2 describe-vpcs --filters "Name=cidr-block,Values=10.0.0.0/16"

# Verify subnet CIDRs don't overlap
# Update terraform.tfvars with non-overlapping ranges
# Example:
#   vpc_cidr: 10.0.0.0/16
#   public: 10.0.1.0/24, 10.0.2.0/24
#   private: 10.0.10.0/24, 10.0.11.0/24

# Validate CIDR blocks
terraform plan -var-file="resources/dev/terraform.tfvars"
```

### Issue 7: Terraform State Corrupted

**Symptom:**
```
Error reading state file - invalid state
```

**Solution:**
```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Download from S3 directly
aws s3 cp s3://dev-terraform-state/terraform.tfstate ./terraform.tfstate.s3-backup

# Restore from backup
cp terraform.tfstate.backup terraform.tfstate

# Or refresh from AWS
terraform refresh -var-file="resources/dev/terraform.tfvars"
```

---

## Summary

### ✅ Completion Checklist

- [ ] AWS service account created (`terraform-automation`)
- [ ] IAM policy attached with EC2, S3, DynamoDB permissions
- [ ] S3 buckets created (dev, uat, prod) with versioning
- [ ] DynamoDB tables created (dev, uat, prod) for state locking
- [ ] Jenkins installed and accessible
- [ ] Required plugins installed
- [ ] AWS credentials added to Jenkins
- [ ] GitHub credentials added to Jenkins
- [ ] Pipeline job created and tested
- [ ] DEV environment deployed (VPC + Subnets + NAT)
- [ ] UAT environment deployed (VPC + Subnets + NAT)
- [ ] PROD environment deployed (VPC + 3 AZ + HA Setup)
- [ ] All outputs verified and documented
- [ ] Team trained on pipeline usage
- [ ] Disaster recovery procedure documented
- [ ] Cost monitoring set up
- [ ] ✅ PRODUCTION READY!

### 📖 Documentation Files

```
aws_terraform_vpn/
├── SETUP_GUIDE.md              ← Comprehensive setup details
├── QUICK_START.md              ← 5-minute quick setup
├── EXECUTION_CHECKLIST.md      ← Step-by-step execution
├── PRODUCTION_SETUP.md         ← This file (complete guide)
├── Jenkinsfile                 ← CI/CD pipeline
├── modules/network/
│   ├── main.tf                 ← VPC, Subnets, NAT, IGW
│   ├── variables.tf            ← Input variables
│   └── outputs.tf              ← Output values
├── resources/
│   ├── dev/terraform.tfvars    ← Dev configuration
│   ├── uat/terraform.tfvars    ← UAT configuration
│   └── prod/terraform.tfvars   ← Prod configuration
├── main.tf                     ← Module usage
├── root.tf                     ← Provider & backend config
└── scripts/
    ├── setup-backend.sh        ← Bash script for S3/DynamoDB
    ├── setup-backend.bat       ← Windows batch for S3/DynamoDB
    └── setup-iam-user.sh       ← IAM setup script
```

### 🎯 Next Steps

1. **Use QUICK_START.md** for immediate deployment
2. **Use SETUP_GUIDE.md** for detailed explanations
3. **Use EXECUTION_CHECKLIST.md** as a reference during setup
4. **Refer to this guide** for production deployment strategies

---

### 📞 Support & References

- Terraform: https://www.terraform.io/docs
- AWS CLI: https://docs.aws.amazon.com/cli
- Jenkins: https://www.jenkins.io/doc
- GitHub: https://docs.github.com

---

**Created**: 2024
**Last Updated**: 2024
**Status**: ✅ Production Ready

