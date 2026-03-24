@REM AWS S3 Backend Setup Script (Windows Batch)
@REM This script creates S3 buckets and DynamoDB tables for Terraform state management

@echo off
setlocal enabledelayedexpansion

cls
echo ================================
echo AWS Terraform Backend Setup
echo ================================

REM Configuration
set REGION=us-east-1
set ENVIRONMENTS=dev uat prod

REM Verify AWS CLI is installed
where aws >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: AWS CLI not installed
    echo Download from: https://aws.amazon.com/cli/
    exit /b 1
)

echo.
echo Verifying AWS credentials...
aws sts get-caller-identity >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: AWS credentials not configured
    echo Run: aws configure
    exit /b 1
)

for %%E in (%ENVIRONMENTS%) do (
    echo.
    echo ================================================
    echo Setting up backend for %%E environment
    echo ================================================
    
    REM Create S3 bucket
    set BUCKET=%%E-terraform-state
    echo Creating S3 bucket: !BUCKET!
    
    aws s3api head-bucket --bucket !BUCKET! --region %REGION% 2>nul
    if %ERRORLEVEL% NEQ 0 (
        aws s3 mb s3://!BUCKET! --region %REGION%
        echo Bucket !BUCKET! created
    ) else (
        echo Bucket !BUCKET! already exists
    )
    
    REM Enable versioning
    echo Enabling versioning...
    aws s3api put-bucket-versioning ^
        --bucket !BUCKET! ^
        --versioning-configuration Status=Enabled ^
        --region %REGION%
    
    REM Enable encryption
    echo Enabling encryption...
    aws s3api put-bucket-encryption ^
        --bucket !BUCKET! ^
        --server-side-encryption-configuration "{\"Rules\": [{\"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}}]}" ^
        --region %REGION%
    
    REM Block public access
    echo Blocking public access...
    aws s3api put-public-access-block ^
        --bucket !BUCKET! ^
        --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true ^
        --region %REGION%
    
    REM Create DynamoDB table
    set TABLE=terraform-locks-%%E
    echo Creating DynamoDB table: !TABLE!
    
    aws dynamodb describe-table --table-name !TABLE! --region %REGION% >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        aws dynamodb create-table ^
            --table-name !TABLE! ^
            --attribute-definitions AttributeName=LockID,AttributeType=S ^
            --key-schema AttributeName=LockID,KeyType=HASH ^
            --billing-mode PAY_PER_REQUEST ^
            --region %REGION%
        
        echo Waiting for table to be active...
        aws dynamodb wait table-exists ^
            --table-name !TABLE! ^
            --region %REGION%
        echo Table !TABLE! created
    ) else (
        echo Table !TABLE! already exists
    )
)

echo.
echo ================================
echo Backend setup completed!
echo ================================
echo.
echo Next steps:
echo 1. Verify S3 buckets: aws s3 ls
echo 2. Verify DynamoDB tables: aws dynamodb list-tables
echo 3. Uncomment backend section in root.tf
echo 4. Run: terraform init

pause
