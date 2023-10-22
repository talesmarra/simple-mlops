# If using only the registry component uncomment this part
# # declare an AWS bucket resource
# resource "aws_s3_bucket" "model_registry_bucket" {
#   bucket = "registry-bucket-simple-ct"
# }

data "aws_iam_role" "ct_role" {
  name = "ct-role"
} 


# declare an AWS dynamodb table resource with one index and three attributes: published_at (date), tag (string), and evaluation_metrics (string)
resource "aws_dynamodb_table" "simple-registry" {
  name     = "simple-registry"
  hash_key = "id"
  range_key = "published_at"
  billing_mode = "PROVISIONED"
  read_capacity = 1
  write_capacity = 1
  attribute {
    name = "id"
    type = "N"
  }
  attribute {
    name = "published_at"
    type = "S"
  }
  attribute {
    name = "tag"
    type = "S"
  }
  attribute {
    name = "evaluation_metrics"
    type = "S"
  }
  global_secondary_index {
    name            = "tag-index"
    hash_key        = "tag"
    range_key       = "evaluation_metrics"
    projection_type = "ALL"
    read_capacity = 1
  write_capacity = 1
  }
}

# add policy to dynamodb to allow the lambda function to write to it
resource "aws_iam_policy" "dynamodb_access_policy" {
  name        = "dynamodb-access-policy"
  description = "IAM policy for DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan",
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.simple-registry.arn,
      },
    ],
  })
}

# attach the policy to the lambda execution role
resource "aws_iam_role_policy_attachment" "dynamodb_access_attachment" {
  policy_arn = aws_iam_policy.dynamodb_access_policy.arn
  role       = data.aws_iam_role.ct_role.name
}
