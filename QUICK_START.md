# Quick Start - AWS Terraform VPN Infrastructure

## 5-Minute Quick Start

### Prerequisites
- Terraform v1.6+
- AWS CLI configured with credentials
- Git

### Step 1: Clone Repository
```bash
git clone https://github.com/YOUR_ORG/aws_terraform_vpn.git
cd aws_terraform_vpn
```

### Step 2: Initialize Terraform (DEV)
```bash
terraform init -var-file="resources/dev/terraform.tfvars"
terraform validate
```

### Step 3: Plan Infrastructure
```bash
terraform plan -var-file="resources/dev/terraform.tfvars" -out=tfplan.out
terraform show tfplan.out
```

### Step 4: Create Infrastructure
```bash
terraform apply tfplan.out
```

### Step 5: Get Outputs
```bash
terraform output -json
```

### Step 6: Destroy (When Done)
```bash
terraform destroy -var-file="resources/dev/terraform.tfvars" -auto-approve
```

---

## Jenkins Quick Setup

### Prerequisites
- Jenkins 2.387+
- Docker (optional)

### Installation
```bash
# Start Jenkins with Docker
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 jenkins/jenkins:latest

# Access at http://localhost:8080
# Get admin password: docker logs jenkins
```

### Configure Jenkins (10 minutes)
1. Install plugins: Pipeline, Git, GitHub, AWS, Credentials Binding
2. Add GitHub credentials (Settings → Developer settings → Personal access tokens)
3. Add AWS credentials (Access Key + Secret Key from IAM user)
4. Create new Pipeline job pointing to Jenkinsfile

### Run Pipeline
1. Click "Build with Parameters"
2. Select ENVIRONMENT (dev/uat/prod)
3. Select ACTION (plan/apply/destroy)
4. Click Build

---

## Project Structure

```
aws_terraform_vpn/
├── modules/
│   ├── network/
│   │   ├── main.tf           # VPC, Subnets, NAT, IGW
│   │   ├── variables.tf      # Input variables
│   │   └── outputs.tf        # Output values
│   └── security/            # (Future) Security groups, ACLs
├── resources/
│   ├── dev/
│   │   └── terraform.tfvars  # Dev environment values
│   ├── uat/
│   │   └── terraform.tfvars  # UAT environment values
│   └── prod/
│       └── terraform.tfvars  # Prod environment values
├── main.tf                   # Root module configuration
├── variables.tf              # Root variables
├── outputs.tf                # Root outputs
├── root.tf                   # Provider and backend config
├── Jenkinsfile              # CI/CD pipeline definition
├── SETUP_GUIDE.md           # Detailed setup instructions
└── QUICK_START.md           # This file
```

---

## Environment Configurations

### DEV (Development)
- VPC CIDR: 10.0.0.0/16
- Public Subnets: 2 (10.0.1.0/24, 10.0.2.0/24)
- Private Subnets: 2 (10.0.10.0/24, 10.0.11.0/24)

### UAT (User Acceptance Testing)
- VPC CIDR: 10.1.0.0/16
- Public Subnets: 2 (10.1.1.0/24, 10.1.2.0/24)
- Private Subnets: 2 (10.1.10.0/24, 10.1.11.0/24)

### PROD (Production)
- VPC CIDR: 10.2.0.0/16
- Public Subnets: 3 (10.2.1.0/24, 10.2.2.0/24, 10.2.3.0/24)
- Private Subnets: 3 (10.2.10.0/24, 10.2.11.0/24, 10.2.12.0/24)

---

## Useful Commands

### Plan Specific Environment
```bash
terraform plan -var-file="resources/uat/terraform.tfvars"
```

### Apply with Auto-Approval
```bash
terraform apply -auto-approve -var-file="resources/dev/terraform.tfvars"
```

### Format Code
```bash
terraform fmt -recursive .
```

### Validate Syntax
```bash
terraform validate
```

### Show Current State
```bash
terraform state list
terraform state show aws_vpc.main
```

### Import Existing Resource
```bash
terraform import aws_vpc.main vpc-xxxxx
```

### Get Module Documentation
```bash
terraform init && terraform providers
```

---

## Key Resources Created

Each environment creates:
- 1 VPC
- 2-3 Public Subnets (with NAT)
- 2-3 Private Subnets
- Internet Gateway
- NAT Gateways (per AZ)
- Route Tables
- Security Group Rules (in security module)

---

## Cost Estimation

**DEV**: ~$15/month
- NAT Gateway: $32/month
- Data transfer: minimal
- S3 state: <$1/month

**UAT**: ~$15/month
**PROD**: ~$45/month (3x AZ)

---

## Support & Troubleshooting

### Check Terraform Version
```bash
terraform version
```

### Validate AWS Credentials
```bash
aws sts get-caller-identity
```

### View Terraform Logs
```bash
export TF_LOG=DEBUG
terraform plan
unset TF_LOG
```

### Clean Terraform Cache
```bash
rm -rf .terraform/
terraform init
```

---

## Next Steps

1. Update GitHub repo URL in Jenkinsfile
2. Create AWS S3 bucket for state (see SETUP_GUIDE.md)
3. Configure Jenkins pipeline (see SETUP_GUIDE.md)
4. Deploy DEV first
5. Test in UAT
6. Deploy to PROD

See **SETUP_GUIDE.md** for complete step-by-step instructions!

