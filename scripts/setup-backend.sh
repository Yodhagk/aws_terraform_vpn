#!/bin/bash
# AWS S3 Backend Setup Script
# This script creates S3 buckets and DynamoDB tables for Terraform state management

set -e

echo "================================"
echo "AWS Terraform Backend Setup"
echo "================================"

# Configuration
REGION="us-east-1"
ENVIRONMENTS=("dev" "uat" "prod")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to create S3 bucket
create_s3_bucket() {
    local env=$1
    local bucket_name="${env}-terraform-state"
    
    echo -e "\n${YELLOW}Creating S3 bucket: ${bucket_name}${NC}"
    
    # Check if bucket already exists
    if aws s3 ls "s3://${bucket_name}" 2>/dev/null; then
        echo -e "${GREEN}✓ Bucket ${bucket_name} already exists${NC}"
    else
        # Create bucket
        if [ "$REGION" == "us-east-1" ]; then
            aws s3 mb "s3://${bucket_name}" --region "$REGION"
        else
            aws s3 mb "s3://${bucket_name}" --region "$REGION" \
                --create-bucket-configuration LocationConstraint="$REGION"
        fi
        echo -e "${GREEN}✓ Bucket ${bucket_name} created${NC}"
    fi
    
    # Enable versioning
    echo "Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "${bucket_name}" \
        --versioning-configuration Status=Enabled \
        --region "$REGION"
    echo -e "${GREEN}✓ Versioning enabled${NC}"
    
    # Enable encryption
    echo "Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "${bucket_name}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }' \
        --region "$REGION"
    echo -e "${GREEN}✓ Encryption enabled${NC}"
    
    # Block public access
    echo "Blocking public access..."
    aws s3api put-public-access-block \
        --bucket "${bucket_name}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "$REGION"
    echo -e "${GREEN}✓ Public access blocked${NC}"
}

# Function to create DynamoDB table
create_dynamodb_table() {
    local env=$1
    local table_name="terraform-locks-${env}"
    
    echo -e "\n${YELLOW}Creating DynamoDB table: ${table_name}${NC}"
    
    # Check if table already exists
    if aws dynamodb describe-table --table-name "${table_name}" --region "$REGION" 2>/dev/null; then
        echo -e "${GREEN}✓ Table ${table_name} already exists${NC}"
    else
        # Create table
        aws dynamodb create-table \
            --table-name "${table_name}" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$REGION"
        
        echo "Waiting for table to be active..."
        aws dynamodb wait table-exists \
            --table-name "${table_name}" \
            --region "$REGION"
        echo -e "${GREEN}✓ Table ${table_name} created${NC}"
    fi
}

# Function to verify AWS credentials
verify_credentials() {
    echo -e "\n${YELLOW}Verifying AWS credentials...${NC}"
    if ! aws sts get-caller-identity &>/dev/null; then
        echo -e "${RED}✗ AWS credentials not configured${NC}"
        echo "Run: aws configure"
        exit 1
    fi
    
    local account=$(aws sts get-caller-identity --query Account --output text)
    local user=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ Credentials verified${NC}"
    echo "Account: $account"
    echo "User: $user"
}

# Main execution
main() {
    verify_credentials
    
    for env in "${ENVIRONMENTS[@]}"; do
        echo -e "\n${YELLOW}================================================${NC}"
        echo -e "${YELLOW}Setting up backend for ${env} environment${NC}"
        echo -e "${YELLOW}================================================${NC}"
        
        create_s3_bucket "$env"
        create_dynamodb_table "$env"
    done
    
    echo -e "\n${GREEN}================================${NC}"
    echo -e "${GREEN}✓ Backend setup completed!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "\nNext steps:"
    echo "1. Verify S3 buckets: aws s3 ls"
    echo "2. Verify DynamoDB tables: aws dynamodb list-tables"
    echo "3. Uncomment backend section in root.tf"
    echo "4. Run: terraform init"
}

main "$@"
