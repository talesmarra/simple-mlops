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
  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_logs_attachment,
    aws_cloudwatch_log_group.simple_inference_log_group,
  ]
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

# create an HTTP API gateway for the lambda function
resource "aws_apigatewayv2_api" "simple_inference_api" {
  name          = "simple-inference-api"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.simple-inference.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.simple_inference_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "simple_inference_integration" {
  api_id            = aws_apigatewayv2_api.simple_inference_api.id
  integration_type  = "AWS_PROXY"
  integration_uri   = aws_lambda_function.simple-inference.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "simple_inference_route" {
  api_id    = aws_apigatewayv2_api.simple_inference_api.id
  route_key = "POST /inference"
  target    = "integrations/${aws_apigatewayv2_integration.simple_inference_integration.id}"
}

resource "aws_apigatewayv2_stage" "simple_inference_stage" {
  api_id      = aws_apigatewayv2_api.simple_inference_api.id
  name        = "simple-inference-stage"
  auto_deploy = true
}

# create a cloudwatch log group for the lambda function
resource "aws_cloudwatch_log_group" "simple_inference_log_group" {
  name              = "/aws/lambda/inference-function"
  retention_in_days = 7
}


# attach the policy to the role for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "cloudwatch-logs-policy"
  description = "IAM policy for CloudWatch Logs access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = ["arn:aws:logs:*:*:*"]
      },
    ],
  })
}

# attach the policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_attachment" {
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
  role       = aws_iam_role.simple_inference_role.name
}

