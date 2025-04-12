data "aws_caller_identity" "current" {}

resource "random_pet" "key_suffix" {
  length = 2
}

resource "aws_kms_key" "ec2_key" {
  description         = "KMS key for EC2 EBS volume encryption"
  enable_key_rotation = true
  is_enabled          = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowRootAccount",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowASGServiceRole",
        Effect = "Allow",
        Principal = {
          Service = "autoscaling.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:CreateGrant",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : "true"
          }
        }

      },
      {
        Sid    = "AllowAutoScalingUseOfCMK",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowAutoScalingCreateGrant",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action   = "kms:CreateGrant",
        Resource = "*",
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },

      {
        Sid    = "AllowEC2UseKey",
        Effect = "Allow",
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}"
          ]
        },
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowAttachmentOfPersistentResources",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}"
        },
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        Resource = "*"
      },

    ]
  })

  tags = {
    Name = "ec2-key-${random_pet.key_suffix.id}"
  }
}



# 2. KMS Key for RDS
resource "aws_kms_key" "rds_key" {
  description         = "KMS key for RDS encryption"
  enable_key_rotation = true
  tags = {
    Name = "rds-key-${random_pet.key_suffix.id}"
  }
}

# 3. KMS Key for S3
resource "aws_kms_key" "s3_key" {
  description         = "KMS key for S3 encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAccountRootFullAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceUse",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowEC2AccessToS3Key",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}"
        },
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "s3-key-${random_pet.key_suffix.id}"
  }
}


# 4. KMS Key for Secrets Manager
resource "aws_kms_key" "secrets_key" {
  description         = "KMS key for Secrets Manager encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      # 👇 Root user (always keep this!)
      {
        Sid    = "AllowAccountRootFullAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      # 👇 EC2 role (needed for Secrets Manager decryption)
      {
        Sid    = "AllowEC2DecryptSecret",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}"
        },
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
  tags = {
    Name = "secrets-key-${random_pet.key_suffix.id}"
  }
}
