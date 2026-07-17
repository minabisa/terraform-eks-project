pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment / Terraform workspace'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to run'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip manual approval before apply/destroy (use with caution)'
        )
    }

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_CREDENTIALS     = credentials('aws-terraform-eks-creds') // Jenkins credentials ID
        TF_IN_AUTOMATION    = 'true'
        TF_INPUT            = 'false'
        TF_VAR_FILE         = "environments/${params.ENVIRONMENT}/terraform.tfvars"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Format Check') {
            steps {
                sh 'terraform fmt -check -recursive'
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init -input=false -reconfigure'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Select Workspace') {
            steps {
                sh """
                    terraform workspace select ${params.ENVIRONMENT} || terraform workspace new ${params.ENVIRONMENT}
                """
            }
        }

        stage('Terraform Plan') {
            steps {
                sh """
                    terraform plan -input=false \
                        -var-file=${env.TF_VAR_FILE} \
                        -out=tfplan-${params.ENVIRONMENT}
                """
            }
        }

        stage('Approval') {
            when {
                allOf {
                    expression { params.ACTION != 'plan' }
                    expression { !params.AUTO_APPROVE }
                }
            }
            steps {
                input message: "Approve Terraform ${params.ACTION.toUpperCase()} on ${params.ENVIRONMENT}?", ok: 'Proceed'
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh "terraform apply -input=false -auto-approve tfplan-${params.ENVIRONMENT}"
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                sh """
                    terraform destroy -input=false -auto-approve \
                        -var-file=${env.TF_VAR_FILE}
                """
            }
        }

        stage('Update kubeconfig & Smoke Test') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh """
                    CLUSTER_NAME=\$(terraform output -raw cluster_name)
                    aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name \$CLUSTER_NAME
                    kubectl get nodes
                    kubectl get pods -A
                """
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: "tfplan-${params.ENVIRONMENT}", allowEmptyArchive: true
        }
        success {
            echo "Terraform ${params.ACTION} succeeded for ${params.ENVIRONMENT}."
        }
        failure {
            echo "Terraform ${params.ACTION} failed for ${params.ENVIRONMENT}. Check logs above."
        }
    }
}
