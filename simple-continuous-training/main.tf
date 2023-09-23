provider "aws" {
  region = "eu-west-3"
}

# Declare an ECR repository
data "aws_ecr_repository" "ct_image_repo" {
  name = "ct-image-repo"
}

# Define an IAM policy for Lambda execution role
resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "lambda-execution-policy"
  description = "IAM policy for Lambda execution"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "lambda:InvokeFunction",
        Effect   = "Allow",
        Resource = aws_lambda_function.ct_function.arn,
      },
    ],
  })
}

# Attach the Lambda execution policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_execution_attachment" {
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
  role       = aws_iam_role.ct_role.name
}

# Define an IAM role for Lambda
resource "aws_iam_role" "ct_role" {
  name = "ct-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Declare a S3 bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "data-bucket-simple-ct"
}

# Declare another bucket for the Lambda function to write to
resource "aws_s3_bucket" "model_registry_bucket" {
  bucket = "registry-bucket-simple-ct"
}
# define a policy for the Lambda function to read and write to the 2 buckets
resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3-access-policy"
  description = "IAM policy for S3 access"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject"],
        Effect   = "Allow",
        Resource = [
          "${aws_s3_bucket.data_bucket.arn}/*",
          "${aws_s3_bucket.model_registry_bucket.arn}/*",
        ],
      },
    ],
  })
}

# Attach the S3 access policy to the IAM role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.ct_role.name
}

# Define a Lambda function
resource "aws_lambda_function" "ct_function" {
  function_name = "ct-function"
  timeout       = 100 # seconds
  image_uri     = "${data.aws_ecr_repository.ct_image_repo.repository_url}:latest"
  package_type  = "Image"
  memory_size   = 200 # MB
  role          = aws_iam_role.ct_role.arn
}

# Grant CloudWatch Events permission to invoke the Lambda function
resource "aws_lambda_permission" "lambda_cloudwatch_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ct_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name        = "lambda-schedule-rule"
  description = "Scheduled rule to trigger Lambda function"
  schedule_expression = "cron(0 0 ? * SUN *)"  # This schedules the event for every Sunday at midnight UTC. You can adjust the cron expression for your desired schedule.
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.ct_function.arn
}
