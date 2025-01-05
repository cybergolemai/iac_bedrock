terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/bedrock-api"
  retention_in_days = 2
}

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "bedrock_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda policy for Bedrock access and CloudWatch logging
resource "aws_iam_role_policy" "lambda_policy" {
  name = "bedrock_lambda_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeStreamingModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "bedrock_api" {
  filename         = "lambda_function.zip"
  function_name    = "bedrock-api"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      REGION = var.aws_region
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "bedrock_api" {
  name        = "bedrock-api"
  description = "API Gateway for Bedrock Integration"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  parent_id   = aws_api_gateway_rest_api.bedrock_api.root_resource_id
  path_part   = "invoke"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.bedrock_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.bedrock_api.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.bedrock_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  depends_on  = [aws_api_gateway_integration.lambda]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id  = aws_api_gateway_rest_api.bedrock_api.id
  stage_name   = "api"
}

# Outputs
output "api_url" {
  value = "${aws_api_gateway_stage.api_stage.invoke_url}/invoke"
}