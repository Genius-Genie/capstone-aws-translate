output "request_bucket_name" {
  value = aws_s3_bucket.request_bucket.bucket
}

output "response_bucket_name" {
  value = aws_s3_bucket.response_bucket.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.translate_lambda.function_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}
