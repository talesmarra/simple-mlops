# Declare an ECR repository
data "aws_ecr_repository" "inference_image_repo" {
  name = "inference-image-repo"
}

data "aws_s3_bucket" "model_registry_bucket" {
  bucket = "registry-bucket-simple-ct"
}

data "aws_dynamodb_table" "simple_registry" {
  name = "simple-registry"
}

# create a new role for the lambda function
resource "aws_iam_role" "simple_inference_role" {
  name = "simple-inference-role"

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

# declare a lambda function resource

resource "aws_lambda_function" "simple-inference" {
  function_name    = "inference-function"
  role             = aws_iam_role.simple_inference_role.arn
  image_uri     = "${data.aws_ecr_repository.inference_image_repo.repository_url}:latest"
  package_type  = "Image"
  timeout          = 900
  memory_size      = 128
}

# create a policy to read from the dynamodb table
resource "aws_iam_policy" "dynamodb_access_policy_inference" {
  name        = "dynamodb-access-policy-inference"
  description = "IAM policy for DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = data.aws_dynamodb_table.simple_registry.arn,
      },
    ],
  })
}

# attach the policy to the role
resource "aws_iam_role_policy_attachment" "dynamodb_access_attachment" {
  policy_arn = aws_iam_policy.dynamodb_access_policy_inference.arn
  role       = aws_iam_role.simple_inference_role.name
}

# create a policy to read from the s3 bucket
resource "aws_iam_policy" "s3_access_policy_inf" {
  name        = "s3-access-policy-inf"
  description = "IAM policy for S3 access for inference"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject"],
        Effect   = "Allow",
        Resource = [
          "${data.aws_s3_bucket.model_registry_bucket.arn}/*",
        ],
      },
    ],
  })
}

# attach the policy to the role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy_inf.arn
  role       = aws_iam_role.simple_inference_role.name
}