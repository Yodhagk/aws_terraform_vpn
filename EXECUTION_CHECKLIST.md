# AWS Terraform VPN - Complete Execution Checklist

## ✅ PRE-SETUP CHECKLIST (Complete Before Starting)

### Tools Installation
- [ ] Terraform v1.6+ installed (`terraform -v`)
- [ ] AWS CLI v2 installed (`aws --version`)
- [ ] Git installed (`git --version`)
- [ ] Jenkins 2.387+ installed or Docker available
- [ ] Text editor/IDE (VS Code, etc.)

### AWS Account Setup
- [ ] AWS account with appropriate permissions
- [ ] AWS credentials available (Access Key ID & Secret)
- [ ] Root/Admin user for initial setup
- [ ] One AWS region selected (recommended: us-east-1)

### GitHub Setup
- [ ] GitHub account with repo access
- [ ] GitHub Personal Access Token generated
- [ ] Repository cloned locally

---

## 📋 STEP 1: AWS SERVICE ACCOUNT SETUP (15 minutes)

### Create IAM User for Terraform Automation

```bash
# 1. Create user
aws iam create-user --user-name terraform-automation

# 2. Generate access keys
aws iam create-access-key --user-name terraform-automation

# 3. Save the output (you won't see it again!)
# Access Key ID: _____________
# Secret Access Key: _____________

# 4. Attach permissions
aws iam put-user-policy \
  --user-name terraform-automation \
  --policy-name TerraformManagement \
  --policy-document file://terraform-policy.json
```

**Expected Output:**
- User `terraform-automation` created in AWS IAM
- Access Key ID and Secret generated
- Policy attached successfully

**Verification:**
```bash
aws iam get-user --user-name terraform-automation
aws iam list-user-policies --user-name terraform-automation
```

---

## 📦 STEP 2: AWS S3 BACKEND SETUP (20 minutes)

### Create S3 Buckets for State Files

```powershell
# Windows PowerShell
# Run the script
.\scripts\setup-backend.bat

# Or manually:
$REGION = "us-east-1"

# Create buckets for dev, uat, prod
foreach ($env in "dev", "uat", "prod") {
    $bucket = "$env-terraform-state"
    
    # Create bucket
    aws s3 mb s3://$bucket --region $REGION
    
    # Enable versioning
    aws s3api put-bucket-versioning `
        --bucket $bucket `
        --versioning-configuration Status=Enabled `
        --region $REGION
    
    # Enable encryption
    aws s3api put-bucket-encryption `
        --bucket $bucket `
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }' `
        --region $REGION
}
```

### Create DynamoDB Tables for State Locking

```powershell
foreach ($env in "dev", "uat", "prod") {
    $table = "terraform-locks-$env"
    
    aws dynamodb create-table `
        --table-name $table `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region us-east-1
}
```

**Verification:**
```bash
aws s3 ls                                  # List buckets
aws dynamodb list-tables --region us-east-1  # List tables
```

**Expected Output:**
```
dev-terraform-state
uat-terraform-state
prod-terraform-state
```

---

## 🔧 STEP 3: JENKINS SERVER SETUP (30 minutes)

### Option A: Install Jenkins on Windows

1. Download from https://www.jenkins.io/download/
2. Run MSI installer
3. Choose installation directory
4. Run as Windows Service
5. Access at `http://localhost:8080`
6. Retrieve initial password from: `C:\Program Files\Jenkins\secrets\initialAdminPassword`

### Option B: Run Jenkins in Docker

```powershell
# Pull and run Jenkins
docker run -d `
  --name jenkins `
  -p 8080:8080 `
  -p 50000:50000 `
  -v jenkins_home:/var/jenkins_home `
  jenkins/jenkins:latest

# Get initial admin password
docker logs jenkins | Select-String "password"
```

### Initial Jenkins Setup (First Run)

1. Navigate to `http://localhost:8080`
2. Enter initial admin password
3. Click "Install suggested plugins"
4. Wait for installation (5-10 minutes)
5. Create first admin user:
   - Username: `admin`
   - Password: `(your secure password)`
6. Configure Jenkins URL: `http://localhost:8080`
7. Start using Jenkins

### Install Required Plugins

1. Go to **Manage Jenkins** → **Plugin Manager**
2. Search and install:
   - [ ] Pipeline
   - [ ] Pipeline: Declarative
   - [ ] Git
   - [ ] GitHub
   - [ ] AWS Credentials
   - [ ] Credentials Binding
   - [ ] Email Extension

---

## 🔐 STEP 4: ADD CREDENTIALS TO JENKINS (15 minutes)

### Add AWS Service Account Credentials

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **System** → **Global credentials (unrestricted)**
3. Click **Add Credentials**
4. Configure:
   - **Kind**: AWS Credentials
   - **Access Key ID**: (from IAM user)
   - **Secret Access Key**: (from IAM user)
   - **ID**: `aws-service-account`
   - **Description**: Terraform AWS Service Account
5. Click **Create**

### Add GitHub Credentials

1. First, create GitHub Personal Access Token:
   - GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token
   - Scopes: `repo`, `admin:repo_hook`
   - Copy token (save it!)

2. In Jenkins:
   - Go to **Manage Jenkins** → **Manage Credentials**
   - Click **System** → **Global credentials**
   - Click **Add Credentials**
   - Configure:
     - **Kind**: Username with password
     - **Username**: Your GitHub username
     - **Password**: Your personal access token
     - **ID**: `github-credentials`
     - **Description**: GitHub Token
   - Click **Create**

**Verification:**
```
Jenkins → Manage Credentials → System → Global credentials
Should show:
- aws-service-account (AWS Credentials)
- github-credentials (Username with password)
```

---

## 📁 STEP 5: CREATE JENKINS PIPELINE JOB (20 minutes)

### Create New Pipeline Job

1. Jenkins Dashboard → **New Item**
2. Enter name: `AWS-Terraform-VPN-Pipeline`
3. Select **Pipeline**
4. Click **OK**

### Configure Pipeline Job

**General Tab:**
- [ ] Description: "AWS VPN Infrastructure Automation Pipeline"
- [ ] Check "GitHub project"
- [ ] Enter Project URL: `https://github.com/YOUR_ORG/aws_terraform_vpn`

**Build Triggers Tab:**
- [ ] Check "GitHub hook trigger for GITScm polling" (optional, for auto-trigger)

**Pipeline Tab:**
- [ ] Definition: **Pipeline script from SCM**
- [ ] SCM: **Git**
- [ ] Repository URL: `https://github.com/YOUR_ORG/aws_terraform_vpn.git`
- [ ] Credentials: Select `github-credentials`
- [ ] Branch Specifier: `*/main` (or your default branch)
- [ ] Script Path: `Jenkinsfile`

**Click Save**

---

## 🚀 STEP 6: TERRAFORM CONFIGURATION VERIFICATION (10 minutes)

### Verify Terraform Files Structure

```
aws_terraform_vpn/
├── modules/network/       ✓
│   ├── main.tf           ✓
│   ├── variables.tf       ✓
│   └── outputs.tf         ✓
├── resources/
│   ├── dev/terraform.tfvars   ✓
│   ├── uat/terraform.tfvars   ✓
│   └── prod/terraform.tfvars  ✓
├── main.tf                ✓
├── variables.tf           ✓
├── outputs.tf             ✓
├── root.tf                ✓
└── Jenkinsfile            ✓
```

### Verify Terraform is Valid

```bash
cd aws_terraform_vpn
terraform init -var-file="resources/dev/terraform.tfvars"
terraform validate

# Output should be:
# Success! The configuration is valid.
```

---

## 🔄 STEP 7: DEPLOYMENT - DEV ENVIRONMENT (20 minutes)

### Route 1: Deploy via Jenkins UI (Recommended)

1. Go to Jenkins → `AWS-Terraform-VPN-Pipeline`
2. Click **Build with Parameters**
3. Select:
   ```
   ENVIRONMENT: dev
   ACTION: plan
   AUTO_APPROVE: unchecked
   ```
4. Click **Build**
5. Monitor in **Console Output**
6. When complete, review the plan:
   - Jenkins → Build #1 → Artifacts → `tfplan-dev.txt`
   - Verify resources to be created

7. Repeat **Build with Parameters**:
   ```
   ENVIRONMENT: dev
   ACTION: apply
   AUTO_APPROVE: checked (for dev only)
   ```
8. Click **Build** and monitor

### Route 2: Deploy Locally (For Testing)

```powershell
# 1. Set AWS credentials
$env:AWS_ACCESS_KEY_ID = "YOUR_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET_KEY"
$env:AWS_REGION = "us-east-1"

# 2. Navigate to project
cd c:\Users\monkspark\OneDrive\Documents\GitHub\aws_terraform_vpn

# 3. Initialize Terraform
terraform init -var-file="resources/dev/terraform.tfvars"

# 4. Validate
terraform validate

# 5. Plan
terraform plan `
  -var-file="resources/dev/terraform.tfvars" `
  -out=tfplan-dev.tfplan

# 6. Review plan
terraform show tfplan-dev.tfplan

# 7. Apply
terraform apply tfplan-dev.tfplan

# 8. View outputs
terraform output -json | ConvertFrom-Json
```

### Verification After Deployment

```bash
# Verify VPC created
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"

# Verify subnets
aws ec2 describe-subnets --filters "Name=tag:Environment,Values=dev"

# Get all outputs
terraform output

# Check specific outputs
terraform output vpc_id
terraform output public_subnet_ids
terraform output private_subnet_ids
```

**Expected Output:**
```
VPC ID: vpc-xxxxxxxxx
Public Subnets: [subnet-xxx, subnet-xxx]
Private Subnets: [subnet-xxx, subnet-xxx]
NAT Gateways: [nat-xxx, nat-xxx]
```

---

## 🎯 STEP 8: DEPLOYMENT - UAT ENVIRONMENT (15 minutes)

```bash
# 1. Plan UAT
terraform plan \
  -var-file="resources/uat/terraform.tfvars" \
  -out=tfplan-uat.tfplan

# 2. Review plan
terraform show tfplan-uat.tfplan

# 3. Apply UAT
terraform apply tfplan-uat.tfplan

# 4. Verify
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=uat"
```

Or via Jenkins:
1. Build with Parameters
2. ENVIRONMENT: `uat`, ACTION: `plan`
3. Review plan artifact
4. Build with Parameters
5. ENVIRONMENT: `uat`, ACTION: `apply`

---

## ⚠️ STEP 9: DEPLOYMENT - PROD ENVIRONMENT (30 minutes)

### IMPORTANT: Prod Requires Manual Approval

```bash
# 1. Plan PROD (no auto-apply)
terraform plan \
  -var-file="resources/prod/terraform.tfvars" \
  -out=tfplan-prod.tfplan

# 2. THOROUGHLY review plan
terraform show tfplan-prod.tfplan | more

# 3. Apply with approval
terraform apply tfplan-prod.tfplan
# When prompted: type 'yes' to confirm
```

Or via Jenkins (Recommended for Prod):
1. Build with Parameters
2. ENVIRONMENT: `prod`, ACTION: `plan`
3. **CAREFULLY REVIEW** plan artifact
4. Build with Parameters
5. ENVIRONMENT: `prod`, ACTION: `apply`, AUTO_APPROVE: unchecked
6. When prompted, click "Proceed" in Jenkins UI
7. Monitor console for completion

---

## 📊 STEP 10: VERIFY COMPLETE INFRASTRUCTURE

```bash
# List all VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Environment`].Value]'

# List all subnets per environment
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,CidrBlock,Tags[?Key==`Environment`].Value]'

# List NAT Gateways
aws ec2 describe-nat-gateways --query 'NatGateways[*].[NatGatewayId,State]'

# Get routing tables
aws ec2 describe-route-tables --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Environment`].Value]'

# Export full output
terraform output -json > infrastructure-state.json
```

---

## 🗑️ CLEANUP (When Done Testing)

### Destroy DEV (Safe to destroy)
```bash
terraform destroy \
  -var-file="resources/dev/terraform.tfvars" \
  -auto-approve
```

### Destroy UAT (May need approval)
```bash
terraform destroy -var-file="resources/uat/terraform.tfvars"
# Type 'yes' when prompted
```

### Destroy PROD (Requires CAREFUL Approval)
```bash
# BACKUP STATE FIRST!
cp terraform.tfstate terraform.tfstate.backup

# Destroy
terraform destroy -var-file="resources/prod/terraform.tfvars"
# Type 'yes' when prompted (check 3 times!)
```

---

## 📚 REFERENCE - USEFUL COMMANDS

### Terraform Commands
```bash
# Refresh state
terraform refresh -var-file="resources/dev/terraform.tfvars"

# Show state
terraform state list
terraform state show aws_vpc.main

# Format code
terraform fmt -recursive .

# Check workspace
terraform workspace list
terraform workspace select dev

# Create workspace (optional)
terraform workspace new dev
```

### AWS CLI Commands
```bash
# List all resources tagged environment
aws ec2 describe-resources --filters "Name=tag:Environment,Values=dev"

# Get costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"

# Check S3 state bucket
aws s3 ls s3://dev-terraform-state/

# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-locks-dev
```

---

## ✅ SUCCESS CRITERIA

- [ ] All three environments (dev, uat, prod) have VPC created
- [ ] All subnets created with correct CIDR ranges
- [ ] NAT Gateways deployed (at least one per environment)
- [ ] Internet Gateway attached
- [ ] Route tables configured
- [ ] Terraform state stored in S3 with backup
- [ ] State locked with DynamoDB
- [ ] Jenkins pipeline executes successfully
- [ ] All outputs accessible and verified
- [ ] No manual resources in AWS (all via Terraform)

---

## 📞 TROUBLESHOOTING

### Issue: "Credentials not found"
```bash
# Check AWS credentials
aws sts get-caller-identity

# Set manually
$env:AWS_ACCESS_KEY_ID = "YOUR_KEY"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET"
```

### Issue: "S3 bucket access denied"
```bash
# Check IAM policy
aws iam get-user-policy --user-name terraform-automation --policy-name TerraformManagement

# Check bucket policy
aws s3api get-bucket-policy --bucket dev-terraform-state
```

### Issue: "State lock timeout"
```bash
# Check DynamoDB for stuck locks
aws dynamodb scan --table-name terraform-locks-dev

# Force unlock (CAUTION!)
terraform force-unlock LOCK_ID
```

### Issue: Jenkins pipeline not triggering
```bash
# Check webhook
curl -i http://localhost:8080/github-webhook/

# Check git credentials in Jenkins
Manage Jenkins → Manage Credentials
```

---

## 📋 COMPLETION CHECKLIST

- [ ] AWS service account created
- [ ] S3 buckets created (dev, uat, prod)
- [ ] DynamoDB tables created
- [ ] Jenkins installed and running
- [ ] AWS credentials added to Jenkins
- [ ] GitHub credentials added to Jenkins
- [ ] Jenkins pipeline job created
- [ ] DEV environment deployed
- [ ] UAT environment deployed
- [ ] PROD environment deployed
- [ ] All outputs verified
- [ ] Documentation updated with real values
- [ ] Team trained on pipeline usage
- [ ] Backup procedure documented
- [ ] ✅ READY FOR PRODUCTION!

