# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# main.tf
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

# Create Lambda function code
resource "local_file" "lambda_function" {
  filename = "${path.module}/lambda_function.py"
  content  = <<-EOT
import json
import boto3
import os

# Initialize Bedrock client
bedrock = boto3.client(
    service_name='bedrock-runtime',
    region_name=os.environ['REGION']
)

def lambda_handler(event, context):
    try:
        # Parse request body
        body = json.loads(event['body'])
        prompt = body.get('prompt')
        model_id = body.get('model_id', 'meta.llama3-2-90b-instruct-v1:0')
        max_tokens = body.get('max_tokens', 4000)
        temperature = body.get('temperature', 0.7)
        
        if not prompt:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'prompt is required'})
            }
        
        # Prepare request for Bedrock with Llama-specific format
        request_body = json.dumps({
            "promptArn": "arn:aws:bedrock:us-west-2:381492005022:prompt/4NLYS6J1L0",
            "prompt": prompt,
            "max_gen_len": max_tokens,
            "temperature": temperature,
            "top_p": 0.9
        })
        
        # Invoke Bedrock model
        response = bedrock.invoke_model(
            modelId=model_id,
            contentType="application/json",
            accept="application/json",
            body=request_body
        )
        
        # Parse response
        response_body = json.loads(response['body'].read())
        completion = response_body.get('generation', '')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'completion': completion,
                'model': model_id
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOT
}

# Create zip file from Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local_file.lambda_function.filename
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda function
resource "aws_lambda_function" "bedrock_api" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
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

I need to customize this terraform deployment. Generate a set of questions to ask to modify the terraform infrastructure as code. Once you are done asking questions and I have answered them: I want you to regenerate the terraform config.

Here are the questions I want you to ask me sequentially:
"""
What is the current region of your AWS account, and do you want to keep it the same or switch to another region?
Do you want to use a different VPC for your AI backend?
Do you want to allow inbound traffic on any port, or restrict it to specific ports (e.g., HTTPS on port 443 and HTTP on port 80)?
What is the desired duration for your CloudWatch log group retention?
Would you like to keep the existing output values (instance_public_ip and bedrock_endpoint) or change them?
Do you have any other resources (e.g., S3 buckets, DynamoDB tables) that need to be configured as part of this Terraform deployment?"""

After each question has been answered: move to the next question. These 6 questions are the only 6.