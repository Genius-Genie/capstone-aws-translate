provider "aws" {
  region = var.region
}

# --- S3 Buckets ---
resource "aws_s3_bucket" "request_bucket" {
  bucket        = var.request_bucket_name
  force_destroy = true

  tags = {
    Name        = var.request_bucket_name
    Environment = "dev"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "request_lifecycle" {
  bucket = aws_s3_bucket.request_bucket.id

  rule {
    id     = "ExpireRequestsAfter30Days"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket" "response_bucket" {
  bucket        = var.response_bucket_name
  force_destroy = true

  tags = {
    Name        = var.response_bucket_name
    Environment = "dev"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "response_lifecycle" {
  bucket = aws_s3_bucket.response_bucket.id

  rule {
    id     = "ExpireResponsesAfter30Days"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.lambda_function_name}_policy"
  description = "Allow Lambda to use Translate, S3, and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Translate
      {
        Effect   = "Allow"
        Action   = ["translate:TranslateText"]
        Resource = "*"
      },
      # S3 Access
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.request_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.response_bucket.arn}/*"
      },
      # CloudWatch Logs
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# --- Lambda Function ---
resource "aws_lambda_function" "translate_lambda" {
  filename         = "${path.module}/../lambda_package.zip"
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = filebase64sha256("${path.module}/../lambda_package.zip")
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      REQUEST_BUCKET  = aws_s3_bucket.request_bucket.bucket
      RESPONSE_BUCKET = aws_s3_bucket.response_bucket.bucket
    }
  }

  tags = {
    Name        = var.lambda_function_name
    Environment = "dev"
  }
}

# --- S3 Event Trigger ---
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translate_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.request_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.request_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.translate_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
