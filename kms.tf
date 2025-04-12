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
      # 1. Root access for overall management
      {
        Sid    = "AllowRootAccount",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      # 2. EC2 Role access
      {
        Sid    = "AllowEC2UseKey",
        Effect = "Allow",
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}", 
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
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
      # 3. Grants for attachment of persistent resources
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
        Resource = "*",
        # Condition = {
        #   Bool = {
        #     "kms:GrantIsForAWSResource": "true"
        #   }
        # }
      },
      # 4. Grant EC2 Service Principal necessary permissions
      {
        Sid    = "AllowAutoScalingAndEC2ServiceAccess",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:CreateGrant",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
  tags = {
    Name = "ec2-key-${random_pet.key_suffix.id}"
  }
}

# resource "aws_kms_alias" "ec2_key_alias" {
#   name          = "alias/ec2-key-${random_pet.key_suffix.id}"
#   target_key_id = aws_kms_key.ec2_key.key_id
# }


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
    Version   = "2012-10-17",
    Statement = [
      # 1. Allow full access for the root account
      {
        Sid       = "AllowAccountRootFullAccess",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      # 2. Allow S3 service to use the key for encryption and decryption
      {
        Sid       = "AllowS3ServiceUse",
        Effect    = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
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
