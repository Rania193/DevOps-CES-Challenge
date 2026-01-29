output "state_bucket_name" {
  description = "Name of the Terraform state S3 bucket"
  value       = aws_s3_bucket.state_bucket.bucket
}
output "state_lock_table" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.state_lock.name
}