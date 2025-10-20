output "table_name" {
  description = "Name of the DynamoDB table."
  value       = aws_dynamodb_table.demo.name
}

output "client_kms_key_arn" {
  description = "ARN of the KMS key used for client-side encryption."
  value       = aws_kms_key.dynamodb_client.arn
}

output "client_kms_alias" {
  description = "Alias associated with the client-side KMS key."
  value       = aws_kms_alias.dynamodb_client.name
}

output "storage_kms_key_arn" {
  description = "ARN of the KMS key used for DynamoDB server-side encryption."
  value       = aws_kms_key.dynamodb_storage.arn
}

output "storage_kms_alias" {
  description = "Alias associated with the storage KMS key."
  value       = aws_kms_alias.dynamodb_storage.name
}

output "full_user_name" {
  description = "IAM user with full client-side encryption permissions."
  value       = aws_iam_user.demo_full.name
}

output "limited_user_name" {
  description = "IAM user without client-side decrypt permissions."
  value       = aws_iam_user.demo_limited.name
}
