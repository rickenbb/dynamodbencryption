terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_kms_key" "dynamodb_client" {
  description             = "CMK for DynamoDB client-side encryption demo (client-side keyring)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.default_tags
}

resource "aws_kms_alias" "dynamodb_client" {
  name          = "alias/${var.kms_client_alias}"
  target_key_id = aws_kms_key.dynamodb_client.key_id
}

resource "aws_kms_key" "dynamodb_storage" {
  description             = "CMK for DynamoDB server-side encryption demo (table-at-rest)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.default_tags
}

resource "aws_kms_alias" "dynamodb_storage" {
  name          = "alias/${var.kms_storage_alias}"
  target_key_id = aws_kms_key.dynamodb_storage.key_id
}

resource "aws_dynamodb_table" "demo" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_storage.arn
  }

  tags = var.default_tags
}

data "aws_iam_policy_document" "dynamodb_table_access" {
  statement {
    sid       = "DynamoDBTableCRUD"
    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:UpdateItem", "dynamodb:DeleteItem","dynamodb:ListTables"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "dynamodb_table_access" {
  name        = "${var.table_name}-access"
  description = "Access policy for the demo DynamoDB table."
  policy      = data.aws_iam_policy_document.dynamodb_table_access.json
}

data "aws_iam_policy_document" "kms_storage_via_service" {
  statement {
    sid       = "AllowStorageKeyViaDynamoDB"
    actions   = ["kms:DescribeKey", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext", "kms:Encrypt", "kms:Decrypt"]
    resources = [aws_kms_key.dynamodb_storage.arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "kms_storage_via_service" {
  name        = "${var.table_name}-kms-storage-via-dynamodb"
  description = "Allow using the storage CMK only through DynamoDB (no direct decrypt)."
  policy      = data.aws_iam_policy_document.kms_storage_via_service.json
}

resource "aws_iam_user" "demo_full" {
  name = var.iam_full_user_name
}

resource "aws_iam_user" "demo_limited" {
  name = var.iam_limited_user_name
}

resource "aws_iam_user_policy_attachment" "full_table" {
  user       = aws_iam_user.demo_full.name
  policy_arn = aws_iam_policy.dynamodb_table_access.arn
}

resource "aws_iam_user_policy_attachment" "full_storage_kms" {
  user       = aws_iam_user.demo_full.name
  policy_arn = aws_iam_policy.kms_storage_via_service.arn
}

resource "aws_iam_user_policy_attachment" "limited_table" {
  user       = aws_iam_user.demo_limited.name
  policy_arn = aws_iam_policy.dynamodb_table_access.arn
}

resource "local_file" "python_env" {
  filename = abspath("${path.module}/../.env")
  content  = <<-EOT
AWS_REGION=${var.aws_region}
DEMO_TABLE_NAME=${aws_dynamodb_table.demo.name}
DEMO_CLIENT_KMS_KEY_ARN=${aws_kms_key.dynamodb_client.arn}
FULL_USER_NAME=${aws_iam_user.demo_full.name}
LIMITED_USER_NAME=${aws_iam_user.demo_limited.name}
EOT
}
