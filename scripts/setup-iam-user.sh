#!/bin/bash
# AWS IAM User and Policy Setup Script
# Creates terraform-automation user with necessary permissions

set -e

echo "========================================="
echo "Creating Terraform AWS IAM User"
echo "========================================="

USERNAME="terraform-automation"
POLICY_NAME="TerraformManagement"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}Step 1: Creating IAM user '${USERNAME}'...${NC}"
aws iam create-user --user-name "${USERNAME}" 2>/dev/null || echo -e "${GREEN}User already exists${NC}"

echo -e "\n${YELLOW}Step 2: Creating access key...${NC}"
aws iam create-access-key --user-name "${USERNAME}" > access-key.json
echo -e "${GREEN}Access key created${NC}"
echo "Save this securely:"
cat access-key.json

echo -e "\n${YELLOW}Step 3: Creating and attaching inline policy...${NC}"

# Create policy document
cat > terraform-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformEC2",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformS3",
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
      "Sid": "TerraformDynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:*"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks*"
    },
    {
      "Sid": "AllowCreatingBuckets",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:ListAllMyBuckets"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-user-policy \
    --user-name "${USERNAME}" \
    --policy-name "${POLICY_NAME}" \
    --policy-document file://terraform-policy.json

echo -e "${GREEN}Policy attached${NC}"

echo -e "\n${YELLOW}Step 4: Verifying setup...${NC}"
aws iam get-user-policy --user-name "${USERNAME}" --policy-name "${POLICY_NAME}" > /dev/null
echo -e "${GREEN}✓ Setup verified${NC}"

echo -e "\n========================================="
echo -e "${GREEN}✓ IAM user setup complete!${NC}"
echo -e "========================================="
echo -e "\nAccess Key ID: $(jq -r '.AccessKey.AccessKeyId' access-key.json)"
echo -e "Secret Access Key: $(jq -r '.AccessKey.SecretAccessKey' access-key.json)"
echo -e "\nSave these credentials in Jenkins or your AWS CLI configuration"

# Cleanup
rm access-key.json
