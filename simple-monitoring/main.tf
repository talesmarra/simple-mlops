# declare a lambda function that already exists
data "aws_lambda_function" "lambda" {
  function_name = "inference-function"
}

resource "aws_cloudwatch_dashboard" "lambda_dashboard" {
    dashboard_name = "inference_monitoring_dashboard"

    dashboard_body = jsonencode({
        widgets = [
            {
                type = "metric"
                x    = 0
                y    = 0
                width = 12
                height = 6
                properties = {
                    metrics = [
                        ["AWS/Lambda", "Duration", "FunctionName", data.aws_lambda_function.lambda.function_name, { "stat": "Average", "period": 300 }],
                    ],
                    view = "timeSeries",
                    stacked = false,
                    region = "eu-west-3",
                    title = "Lambda Function Duration (ms)"
                }
            }
        ]
    })
}

# create an alarm for the lambda function errors 
resource "aws_cloudwatch_metric_alarm" "lambda_errors_alarm" {
  alarm_name          = "lambda_errors_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [aws_sns_topic.sns_topic.arn]
  dimensions = {
    FunctionName = data.aws_lambda_function.lambda.function_name
  }
}

# create an SNS topic to send the alarm to
resource "aws_sns_topic" "sns_topic" {
  name = "lambda_errors_topic"
}

# create a subscription to the SNS topic
resource "aws_sns_topic_subscription" "sns_topic_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = "YOUR_MAIL@MAIL.com"
}

