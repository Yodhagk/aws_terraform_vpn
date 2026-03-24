# AWS Terraform VPN Infrastructure - Complete Setup Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [AWS Service Account Setup](#aws-service-account-setup)
3. [S3 Backend Configuration](#s3-backend-configuration)
4. [Jenkins Server Setup](#jenkins-server-setup)
5. [GitHub Integration](#github-integration)
6. [Execution Commands](#execution-commands)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- **Terraform**: v1.6.0 or higher
- **AWS CLI**: v2.0 or higher
- **Git**: Latest version
- **Jenkins**: v2.387.1 or higher
- **Docker** (optional, for containerized Jenkins)

### Install Terraform (Windows)
```powershell
# Using Chocolatey
choco install terraform

# Or manually download from https://www.terraform.io/downloads.html
```

### Install AWS CLI
```powershell
# Using MSI installer or Chocolatey
choco install awscli
```

### Verify Installations
```bash
terraform -v
aws --version
git --version
```

---

## AWS Service Account Setup

### Step 1: Create IAM User for Terraform

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. User name: `terraform-automation`
4. Click "Create user"

### Step 2: Create Access Keys

1. Select the user → "Security credentials" tab
2. Click "Create access key"
3. Select "Application running outside AWS"
4. Copy **Access Key ID** and **Secret Access Key** (save securely)

### Step 3: Create IAM Policy for Terraform

Create a file `terraform-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformVPC",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DescribeVpcs",
        "ec2:DeleteVpc",
        "ec2:CreateSubnet",
        "ec2:DescribeSubnets",
        "ec2:DeleteSubnet",
        "ec2:CreateInternetGateway",
        "ec2:DescribeInternetGateways",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:CreateNatGateway",
        "ec2:DescribeNatGateways",
        "ec2:DeleteNatGateway",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:DescribeAddresses",
        "ec2:CreateRouteTable",
        "ec2:DescribeRouteTables",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
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
        "s3:CreateBucket",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketEncryption",
        "s3:PutBucketEncryption"
      ],
      "Resource": [
        "arn:aws:s3:::*-terraform-state",
        "arn:aws:s3:::*-terraform-state/*"
      ]
    },
    {
      "Sid": "DynamoDBStatelock",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DeleteTable",
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks*"
    }
  ]
}
```

### Step 4: Attach Policy to User

```bash
# Using AWS CLI
aws iam put-user-policy \
  --user-name terraform-automation \
  --policy-name TerraformManagement \
  --policy-document file://terraform-policy.json
```

---

## S3 Backend Configuration

### Step 1: Create S3 Bucket for State Files

```bash
# For DEV environment
aws s3 mb s3://dev-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket dev-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket dev-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# For UAT environment
aws s3 mb s3://uat-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket uat-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket uat-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# For PROD environment
aws s3 mb s3://prod-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket prod-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket prod-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Step 2: Create DynamoDB Table for State Locking

```bash
# For DEV
aws dynamodb create-table \
  --table-name terraform-locks-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# For UAT
aws dynamodb create-table \
  --table-name terraform-locks-uat \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# For PROD
aws dynamodb create-table \
  --table-name terraform-locks-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Enable S3 Backend in Terraform

Uncomment the backend configuration in `root.tf`:

```hcl
backend "s3" {
  bucket         = "dev-terraform-state"  # Change per environment
  key            = "infrastructure/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks-dev"  # Change per environment
}
```

---

## Jenkins Server Setup

### Step 1: Install Jenkins (Windows)

#### Option A: Using Installer
1. Download from https://www.jenkins.io/download/
2. Run the `.msi` installer
3. Choose installation directory
4. Run as service with default account

#### Option B: Using Docker
```powershell
# Pull latest Jenkins image
docker pull jenkins/jenkins:latest

# Run Jenkins container
docker run -d `
  --name jenkins `
  -p 8080:8080 `
  -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  jenkins/jenkins:latest

# Get initial admin password
docker logs jenkins | grep -A 5 "please use the following password"
```

### Step 2: Initial Jenkins Setup

1. Navigate to `http://localhost:8080`
2. Enter the initial admin password from logs
3. Install suggested plugins
4. Create first admin user
5. Configure Jenkins instance

### Step 3: Install Required Jenkins Plugins

1. Go to **Manage Jenkins** → **Plugin Manager**
2. Install these plugins:
   - **Pipeline**: Declarative Pipeline
   - **Git**: Git Plugin
   - **GitHub**: GitHub Plugin
   - **AWS**: CloudBees AWS Credentials
   - **Credentials Binding**: Credentials Binding Plugin
   - **Email**: Email Extension Plugin

### Step 4: Configure System

1. **Manage Jenkins** → **Configure System**
2. Configure Git:
   - Path to Git: `C:\\Program Files\\Git\\bin\\git.exe` (Windows)
3. Configure GitHub (optional):
   - Add GitHub API Token

---

## GitHub Integration

### Step 1: Create GitHub Personal Access Token

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click "Generate new token"
3. Select scopes:
   - `repo` (full control of private repositories)
   - `admin:repo_hook` (write access to hooks)
4. Generate token and **save it** (you won't see it again)

### Step 2: Add GitHub Credentials to Jenkins

1. **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
2. Click "Add Credentials"
3. Configure:
   - **Kind**: Username with password
   - **Username**: Your GitHub username
   - **Password**: Your personal access token
   - **ID**: `github-credentials`
   - **Description**: GitHub API Token

### Step 3: Add AWS Credentials to Jenkins

1. **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
2. Click "Add Credentials"
3. Configure:
   - **Kind**: AWS Credentials
   - **Access Key ID**: From service account
   - **Secret Access Key**: From service account
   - **ID**: `aws-service-account`
   - **Description**: Terraform AWS Service Account

---

## Jenkins Pipeline Creation

### Step 1: Create New Pipeline Job

1. Jenkins Dashboard → **New Item**
2. Enter job name: `AWS-Terraform-VPN-Pipeline`
3. Select **Pipeline**
4. Click **OK**

### Step 2: Configure Pipeline

1. **General** tab:
   - Description: "AWS VPN Infrastructure Automation Pipeline"
   - Check "GitHub project" and enter repo URL

2. **Build Triggers** tab:
   - Check "GitHub hook trigger for GITScm polling"

3. **Pipeline** tab:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/YOUR_ORG/aws_terraform_vpn.git`
   - Credentials: Select `github-credentials`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

4. Click **Save**

### Step 3: Configure Webhook (Optional - for auto-trigger)

1. GitHub repo → **Settings** → **Webhooks** → **Add webhook**
2. Payload URL: `http://jenkins-server:8080/github-webhook/`
3. Content type: `application/json`
4. Events: Push events, Pull request events
5. Add webhook

---

## Execution Commands

### Manual Execution Through Jenkins UI

#### Plan Command
```
ENVIRONMENT: dev (or uat, prod)
ACTION: plan
AUTO_APPROVE: false
```

#### Apply Command
```
ENVIRONMENT: dev
ACTION: apply
AUTO_APPROVE: true (for dev only)
```

#### Destroy Command
```
ENVIRONMENT: dev
ACTION: destroy
AUTO_APPROVE: false
```

### Command Line Execution (Local)

#### Step 1: Setup AWS Credentials

```powershell
# Windows PowerShell
$env:AWS_ACCESS_KEY_ID = "YOUR_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET_KEY"
$env:AWS_REGION = "us-east-1"
```

Or configure using AWS CLI:
```bash
aws configure
# Enter Access Key ID, Secret Access Key, Region, Output format
```

#### Step 2: Initialize Terraform

```bash
# Navigate to project root
cd c:\Users\monkspark\OneDrive\Documents\GitHub\aws_terraform_vpn

# Initialize Terraform
terraform init -var-file="resources/dev/terraform.tfvars"
```

#### Step 3: Validate Configuration

```bash
terraform validate
terraform fmt -recursive .
```

#### Step 4: Plan Infrastructure

```bash
# DEV Environment
terraform plan \
  -var-file="resources/dev/terraform.tfvars" \
  -out=tfplan-dev.tfplan

# UAT Environment
terraform plan \
  -var-file="resources/uat/terraform.tfvars" \
  -out=tfplan-uat.tfplan

# PROD Environment
terraform plan \
  -var-file="resources/prod/terraform.tfvars" \
  -out=tfplan-prod.tfplan
```

#### Step 5: Review Plan

```bash
terraform show tfplan-dev.tfplan
```

#### Step 6: Apply Infrastructure

```bash
# DEV Environment
terraform apply tfplan-dev.tfplan

# UAT Environment
terraform apply tfplan-uat.tfplan

# PROD Environment (requires manual approval)
terraform apply tfplan-prod.tfplan
```

#### Step 7: View Outputs

```bash
# Display all outputs
terraform output

# Export as JSON
terraform output -json > outputs.json

# Specific output
terraform output vpc_id
terraform output public_subnet_ids
```

#### Step 8: Destroy Infrastructure

```bash
# DEV Environment
terraform destroy -var-file="resources/dev/terraform.tfvars" -auto-approve

# UAT Environment (requires approval)
terraform destroy -var-file="resources/uat/terraform.tfvars"

# PROD Environment (requires manual approval - DANGEROUS)
terraform destroy -var-file="resources/prod/terraform.tfvars"
```

---

## Complete Step-by-Step Execution Example

### Scenario 1: Deploy DEV Environment via Jenkins

#### Step 1: Commit and Push Code
```bash
cd aws_terraform_vpn
git add .
git commit -m "Initial Terraform setup for AWS VPN infrastructure"
git push origin main
```

#### Step 2: Trigger Pipeline
1. Go to Jenkins → `AWS-Terraform-VPN-Pipeline`
2. Click **Build with Parameters**
3. Select:
   - ENVIRONMENT: `dev`
   - ACTION: `plan`
   - AUTO_APPROVE: unchecked
4. Click **Build**
5. Monitor build in **Console Output**

#### Step 3: Verify Plan
1. Wait for plan stage to complete
2. Review plan output in console
3. Click **AWS-Terraform-VPN-Pipeline** → build number
4. Download `tfplan-dev.txt` artifact to review changes

#### Step 4: Apply Infrastructure
1. Go to Jenkins → `AWS-Terraform-VPN-Pipeline`
2. Click **Build with Parameters**
3. Select:
   - ENVIRONMENT: `dev`
   - ACTION: `apply`
   - AUTO_APPROVE: `checked` (dev only)
4. Click **Build**
5. Monitor build execution

#### Step 5: Verify Deployment
```bash
# Check resources created
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"
aws ec2 describe-subnets --filters "Name=tag:Environment,Values=dev"

# Or use Terraform
terraform output -json dev-outputs.json
```

### Scenario 2: Deploy to PROD Environment

#### Step 1: Plan PROD
1. Jenkins → `AWS-Terraform-VPN-Pipeline` → **Build with Parameters**
2. ENVIRONMENT: `prod`, ACTION: `plan`, AUTO_APPROVE: unchecked
3. Review all changes carefully
4. Download plan artifact

#### Step 2: Apply with Approval
1. Jenkins → `AWS-Terraform-VPN-Pipeline` → **Build with Parameters**
2. ENVIRONMENT: `prod`, ACTION: `apply`, AUTO_APPROVE: unchecked
3. Build will pause at approval stage
4. Review changes in Jenkins UI
5. Click **Proceed** to deploy
6. **Review twice** - it's PROD!

### Scenario 3: Local Development

```bash
# 1. Setup environment
$env:AWS_ACCESS_KEY_ID = "YOUR_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET"

# 2. Navigate to project
cd aws_terraform_vpn

# 3. Initialize dev environment
terraform init -var-file="resources/dev/terraform.tfvars"

# 4. Plan changes
terraform plan \
  -var-file="resources/dev/terraform.tfvars" \
  -out=tfplan-dev.tfplan

# 5. Review plan output
terraform show tfplan-dev.tfplan | more

# 6. Apply if satisfied
terraform apply tfplan-dev.tfplan

# 7. Get outputs
terraform output vpc_id
terraform output public_subnet_ids

# 8. Make changes to .tf files as needed

# 9. Plan again
terraform plan -var-file="resources/dev/terraform.tfvars"

# 10. Destroy when done
terraform destroy -var-file="resources/dev/terraform.tfvars" -auto-approve
```

---

## Troubleshooting

### Issue: "Credentials not found"
**Solution:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Set credentials explicitly
$env:AWS_ACCESS_KEY_ID = "YOUR_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET"
```

### Issue: "Permission denied" on S3 bucket
**Solution:**
```bash
# Verify IAM policy is attached
aws iam list-user-policies --user-name terraform-automation

# Check S3 bucket policy
aws s3api get-bucket-policy --bucket dev-terraform-state
```

### Issue: "State lock timeout"
**Solution:**
```bash
# Check DynamoDB for locks
aws dynamodb scan --table-name terraform-locks-dev

# Force unlock (USE WITH CAUTION)
terraform force-unlock LOCK-ID
```

### Issue: "subnet CIDR conflict"
**Solution:**
Ensure subnet CIDRs in `terraform.tfvars` don't overlap and are within VPC CIDR range.

### Issue: Jenkins pipeline fails at "Checkout"
**Solution:**
1. Verify GitHub credentials in Jenkins
2. Check GitHub repo URL is correct
3. Verify SSH key or access token permissions

### Issue: Terraform plan shows "No changes"
**Solution:**
- Resources already exist in state
- Run `terraform refresh` to sync state
- Check for typos in variable values

---

## Next Steps

1. ✅ Complete S3 backend setup
2. ✅ Configure Jenkins server
3. ✅ Add AWS and GitHub credentials
4. ✅ Create Jenkins pipeline job
5. ✅ Deploy DEV environment first
6. ✅ Test in UAT environment
7. ✅ Schedule PROD deployment with approval gates
8. Add monitoring and logging
9. Implement disaster recovery procedures
10. Document run books for operations team

