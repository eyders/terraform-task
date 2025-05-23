# Terraform AWS Infrastructure

This Terraform configuration deploys a basic AWS infrastructure with VPC, EC2 instances, and Load Balancer.

## Prerequisites

- Terraform installed
- AWS CLI configured
- `dev.tfvars` file with required variables:

```hcl
ami           = "ami-0abcdef1234567890"
instance_type = "t2.micro"
region        = "us-east-1"
```

## Basic Commands

### Initialize Terraform
```bash
terraform init
```

### Plan changes
```bash
terraform plan -var-file=dev.tfvars
```

### Apply configuration
```bash
terraform apply -var-file=dev.tfvars -auto-approve
```

### Destroy infrastructure
```bash
terraform destroy -var-file=dev.tfvars -auto-approve
```

## What gets created

- VPC with public/private subnets
- 2 EC2 instances with Apache web server
- Classic Load Balancer
- Security Groups

## Output

After deployment, the Load Balancer DNS name will be displayed in the output to access your application.