# CSYE6225 Infrastructure as Code (Terraform)

This project provisions and configures the infrastructure for a web application using **Terraform** on **AWS**, enabling secure, scalable deployment with CI/CD, encryption, autoscaling, and HTTPS routing.

---

## 🚀 Architecture Overview

```
User → Route53 (DNS)
     → Application Load Balancer (ALB)
         → Auto Scaling Group (EC2 Instances, Launch Template)
             → Secrets Manager (RDS DB Password)
             → Encrypted EBS Volumes (KMS)
             → CloudWatch Logs
         → RDS (PostgreSQL, private subnet, encrypted)
         → S3 Bucket (attachments, encrypted)
```

---

## 🧰 Tech Stack

- **Terraform** for IaC
- **AWS** (EC2, S3, RDS, Route53, ALB, ASG, Secrets Manager, CloudWatch, KMS)
- **GitHub Actions** for CI/CD
- **Packer** for AMI creation
- **Node.js** app (served on port `8080`)

---

## 📂 Repository Structure

```
.
├── main.tf                  # Core infrastructure
├── kms.tf                   # AWS KMS Keys and policies
├── variables.tf             # Configurable parameters
├── outputs.tf               # Exported variables
├── packer/                  # Packer template for AMI
├── .github/workflows/       # CI/CD pipelines
└── README.md                # This file
```

---

## ✅ Features

- 🔐 **Encryption**
  - RDS, EC2 EBS, S3, and Secrets Manager use separate **KMS keys**.
  - Key rotation enabled (90 days).

- 📦 **Secrets Management**
  - DB password is auto-generated and stored in **Secrets Manager** with encryption.

- 📈 **Monitoring**
  - EC2 instances send logs to **CloudWatch**.
  - **CPU-based Auto Scaling** enabled via CloudWatch alarms.

- 🌐 **Networking**
  - Public/private subnets across AZs.
  - ALB forwards HTTP/HTTPS traffic to private EC2s.
  - HTTPS secured via **ACM** TLS certificate.

- 🧪 **CI/CD**
  - GitHub Actions workflow:
    - Runs tests, builds AMI, creates launch template version.
    - Refreshes auto scaling group in DEV & DEMO environments.

- 📡 **DNS**
  - Route53 record (`dev.sahanajprakash.me`) alias points to ALB.

---

## ⚙️ Terraform Usage

```bash
# 1. Configure AWS CLI credentials via named profile

# 2. Set environment variables or use tfvars
export TF_VAR_aws_profile="dev"
export TF_VAR_db_password="strong-db-password"

# 3. Init, plan, and apply
terraform init
terraform plan
terraform apply
```

---

## 🧪 Testing

```bash
# Check health of web app
curl -v https://demo.sahanajprakash.me/healthz

# View logs
journalctl -u csye6225.service -f
```

---

## 🔐 IAM Roles & KMS

Each resource is encrypted using a separate KMS key. The following policies are granted:

| Key         | Permissions Granted To |
|-------------|-------------------------|
| `ec2_key`   | EC2 role, autoscaling service-linked role |
| `rds_key`   | RDS service, root       |
| `s3_key`    | S3 service              |
| `secrets_key` | EC2 role              |

---

## ☁️ CI/CD Workflow

- Triggers on `pull_request.closed` if merged into `main`
- Runs tests, installs deps, creates AMI via Packer
- Creates new launch template version
- Shares AMI with demo account
- Refreshes ASG and waits for update to complete

Secrets used:

| Secret Key                        | Purpose                           |
|----------------------------------|-----------------------------------|
| `AWS_DEV_ACCESS_KEY_ID`          | Dev AWS account access            |
| `AWS_DEV_SECRET_ACCESS_KEY`      |                                   |
| `AWS_DEMO_ACCESS_KEY_ID`         | Demo AWS account access           |
| `AWS_DEMO_SECRET_ACCESS_KEY`     |                                   |
| `GCP_DEV_SERVICE_ACCOUNT_KEY`    | Optional, for logging or backups  |
| `AMI_USERS`                      | List of shared AWS account IDs    |
| `ACM_CERTIFICATE_ARN`            | ACM certificate for HTTPS         |

---

## 🧽 Cleanup

```bash
terraform destroy
```

---

## 🔍 Troubleshooting

| Problem | Solution |
|--------|----------|
| `AccessDenied` for S3 | Check EC2 IAM policy and bucket KMS key allows `kms:GenerateDataKey` |
| Instance stuck in `Unhealthy` | Check that the app binds to `0.0.0.0`, port is open to LB, and `/healthz` returns 200 |
| `kms key invalid state` | Make sure KMS key is enabled and not pending deletion |
| Can't SSH into EC2 | Use public subnet temporarily and enable port 22 from your IP |

---

## 📫 Contact

Author: **Sahana Prakash**  
Email: [1999sahana@gmail.com]  
GitHub: [@sahanajprakash](https://github.com/sahanajprakash)

---