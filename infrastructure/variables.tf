variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "request_bucket_name" {
  description = "Globally unique name for request bucket"
  type        = string
}

variable "response_bucket_name" {
  description = "Globally unique name for response bucket"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
  default     = "capstone_translate_lambda"
}
