variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default = "eu-central-2"
}

variable "table_name" {
  description = "DynamoDB table name for the demo."
  type        = string
  default = "dynamodb-testtable98ih23"
}

variable "default_tags" {
  description = "Optional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "kms_client_alias" {
  description = "Alias assigned to the client-side encryption KMS key."
  type        = string
  default     = "dynamodb-demo-client-key"
}

variable "kms_storage_alias" {
  description = "Alias assigned to the DynamoDB server-side encryption KMS key."
  type        = string
  default     = "dynamodb-demo-storage-key"
}

variable "iam_full_user_name" {
  description = "IAM user name with full encryption permissions."
  type        = string
  default     = "dynamodb-demo-full-user"
}

variable "iam_limited_user_name" {
  description = "IAM user name with limited permissions (no client key decrypt)."
  type        = string
  default     = "dynamodb-demo-limited-user"
}
