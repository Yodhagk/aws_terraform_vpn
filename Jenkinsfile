#!/usr/bin/env groovy

pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'uat', 'prod'], description: 'Select environment to deploy')
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action to perform')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Auto approve apply (not for prod)')
    }

    environment {
        // AWS Configuration
        AWS_REGION = 'us-east-1'
        AWS_CREDENTIALS = credentials('aws-service-account')
        
        // GitHub Configuration
        GITHUB_CREDENTIALS = credentials('github-credentials')
        GIT_REPO = 'https://github.com/YOUR_ORG/aws_terraform_vpn.git'
        
        // Terraform Configuration
        TERRAFORM_VERSION = '1.6.0'
        TF_VAR_FILE = "resources/${ENVIRONMENT}/terraform.tfvars"
        TF_BACKEND_BUCKET = "${ENVIRONMENT}-terraform-state"
        LOCK_TABLE = "terraform-locks-${ENVIRONMENT}"
    }

    options {
        ansiColor('xterm')
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '🔍 Stage: Checkout Repository'
                    echo '═══════════════════════════════════════'
                }
                checkout scm
                sh '''
                    echo "Git branch: $(git rev-parse --abbrev-ref HEAD)"
                    echo "Git commit: $(git rev-parse --short HEAD)"
                    echo "Git user: $(git log -1 --pretty=format:'%an')"
                '''
            }
        }

        stage('Validate Environment') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '[SUCCESS] Stage: Validate Environment'
                    echo '═══════════════════════════════════════'
                    
                    if (ENVIRONMENT == 'prod' && AUTO_APPROVE) {
                        error("❌ AUTO_APPROVE cannot be true for PROD environment!")
                    }
                }
                sh '''
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Action: ${ACTION}"
                    echo "Terraform vars file: ${TF_VAR_FILE}"
                    
                    if [ ! -f "${TF_VAR_FILE}" ]; then
                        echo "❌ Terraform variables file not found: ${TF_VAR_FILE}"
                        exit 1
                    fi
                    echo "[SUCCESS] Terraform variables file found"
                '''
            }
        }

        stage('Setup Terraform') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '🛠️ Stage: Setup Terraform'
                    echo '═══════════════════════════════════════'
                }
                sh '''
                    # Install tfenv to manage Terraform versions (optional)
                    # or use terraform directly if already installed
                    terraform -v
                    
                    # Create backend config file
                    cat > backend-config.hcl <<'EOF'
                    bucket         = "${TF_BACKEND_BUCKET}"
                    key            = "terraform.tfstate"
                    region         = "${AWS_REGION}"
                    encrypt        = true
                    dynamodb_table = "${LOCK_TABLE}"
                    EOF
                    
                    echo "[SUCCESS] Terraform setup completed"
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '📦 Stage: Terraform Init'
                    echo '═══════════════════════════════════════'
                }
                withCredentials([
                    usernamePassword(credentialsId: 'aws-service-account', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_REGION=${AWS_REGION}
                        
                        # Initialize Terraform (without backend if it doesn't exist yet)
                        terraform init \
                            -var-file="${TF_VAR_FILE}" \
                            -upgrade \
                            -lock=true
                        
                        echo "[SUCCESS] Terraform init completed"
                    '''
                }
            }
        }

        stage('Terraform Format Check') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '🎯 Stage: Format Check'
                    echo '═══════════════════════════════════════'
                }
                sh '''
                    terraform fmt -check -recursive . || true
                    echo "[SUCCESS] Format check completed"
                '''
            }
        }

        stage('Terraform Validate') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '[INFO] Stage: Validate Configuration'
                    echo '═══════════════════════════════════════'
                }
                sh '''
                    terraform validate
                    echo "[SUCCESS] Configuration validation completed"
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '[INFO] Stage: Terraform Plan'
                    echo '═══════════════════════════════════════'
                }
                withCredentials([
                    usernamePassword(credentialsId: 'aws-service-account', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_REGION=${AWS_REGION}
                        
                        terraform plan \
                            -var-file="${TF_VAR_FILE}" \
                            -out=tfplan-${ENVIRONMENT}.tfplan \
                            -lock=true
                        
                        # Generate human-readable plan
                        terraform show -no-color tfplan-${ENVIRONMENT}.tfplan > tfplan-${ENVIRONMENT}.txt || true
                        
                        echo "[SUCCESS] Terraform plan completed"
                    '''
                }
            }
        }

        stage('Approval') {
            when {
                expression { 
                    return params.ACTION == 'apply'
                }
            }
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '[INFO] Stage: Approval'
                    echo '═══════════════════════════════════════'
                    
                    if (ENVIRONMENT == 'prod' && !AUTO_APPROVE) {
                        input message: "[WARNING] Apply changes to PROD environment? This action cannot be undone!", ok: 'Deploy to PROD'
                    } else if (AUTO_APPROVE) {
                        echo "[AUTO-APPROVAL] Auto-approval enabled"
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    return params.ACTION == 'apply'
                }
            }
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '[SUCCESS] Stage: Terraform Apply'
                    echo '═══════════════════════════════════════'
                }
                withCredentials([
                    usernamePassword(credentialsId: 'aws-service-account', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_REGION=${AWS_REGION}
                        
                        terraform apply \
                            -lock=true \
                            -input=false \
                            tfplan-${ENVIRONMENT}.tfplan
                        
                        echo "[SUCCESS] Terraform apply completed"
                    '''
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression {
                    return params.ACTION == 'destroy'
                }
            }
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '🗑️  Stage: Terraform Destroy'
                    echo '═══════════════════════════════════════'
                    
                    if (ENVIRONMENT == 'prod') {
                        input message: "⚠️⚠️⚠️ DESTROYING PROD ENVIRONMENT! This is irreversible!", ok: 'Destroy PROD'
                    }
                }
                withCredentials([
                    usernamePassword(credentialsId: 'aws-service-account', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_REGION=${AWS_REGION}
                        
                        terraform destroy \
                            -var-file="${TF_VAR_FILE}" \
                            -lock=true \
                            -auto-approve
                        
                        echo "[SUCCESS] Terraform destroy completed"
                    '''
                }
            }
        }

        stage('Export Outputs') {
            when {
                expression {
                    return params.ACTION == 'apply'
                }
            }
            steps {
                script {
                    echo '═══════════════════════════════════════'
                    echo '[INFO] Stage: Export Outputs'
                    echo '═══════════════════════════════════════'
                }
                sh '''
                    terraform output -json > outputs-${ENVIRONMENT}.json
                    terraform output
                    echo "[SUCCESS] Outputs exported"
                '''
            }
        }
    }

    post {
        always {
            script {
                echo '═══════════════════════════════════════'
                echo '[INFO] Post-Build Actions'
                echo '═══════════════════════════════════════'
            }
            
            // Archive terraform plan and outputs
            archiveArtifacts artifacts: 'tfplan-*.txt,outputs-*.json', allowEmptyArchive: true
            
            // Clean workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '.terraform', type: 'INCLUDE'],
                    [pattern: '.tfplan', type: 'INCLUDE'],
                    [pattern: 'terraform.tfstate*', type: 'INCLUDE']
                ]
            )
        }

        success {
            script {
                echo '[SUCCESS] Pipeline completed successfully'
            }
        }

        failure {
            script {
                echo '[ERROR] Pipeline failed'
            }
        }
    }
}
