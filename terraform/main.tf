provider "aws" {
    region = "ap-south-1"
}

// creating the s3 bucket 
resource "aws_s3_bucket" "email_notif" {
    bucket = "email-notif-bucket"
}

// creating the lambda function
resource "aws_lambda_function" "lambda" {
    function_name = "ProcessingS3EventNotification"
    role = aws_iam_role.lambda_execution.arn
    handler = "lambda_notif.lambda_handler"
    runtime = "python3.12"
    filename         = "${path.module}/../lambda/lambda_function.zip"
    source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_function.zip")
    environment {
            variables = {
            SNS_TOPIC_ARN = aws_sns_topic.email_topic.arn}
            }
}


//create the IAM role which will be assumed by lambda service 
resource "aws_iam_role" "lambda_execution" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
                Service = "lambda.amazonaws.com"
            }
    }]
  })
}

//  add permissions to cloudwatch 
resource "aws_iam_role_policy" "lambda_logs" {
  name = "lambda-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

// Configure S3 bucket to send notifications to Lambda on object creation events
resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.email_notif.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  // Ensure Lambda permission is created before notification
  depends_on = [aws_lambda_permission.allow_s3]
}


// Allow S3 to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.email_notif.arn
}

// s3 access
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject"
        ],
        Resource = [
          aws_s3_bucket.email_notif.arn,
          "${aws_s3_bucket.email_notif.arn}/*"
        ]
      }
    ]
  })
}

// creating SNS topic 
resource "aws_sns_topic" "email_topic" {
  name = "email-notifications"
}

// subscribe lambda to SNS topic 
//resource "aws_sns_topic_subscription" "lambda_subscription" {
//    topic_arn = aws_sns_topic.notification_topic.arn
//    protocol = "lambda"
//    endpoint = aws_lambda_function.lambda.arn
//}

// adding email so SNS send email to me 
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.email_topic.arn
  protocol  = "email"
  endpoint  = "ping2manish92@gmail.com"
}

// Add an IAM policy to your Lambda execution role allowing sns:Publish on your SNS topic
resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "lambda-sns-publish"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.email_topic.arn
      }
    ]
  })
}
