# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.small"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
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

# API Gateway
resource "aws_api_gateway_rest_api" "bedrock_api" {
  name        = "bedrock-api"
  description = "API Gateway for Bedrock Integration"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  parent_id   = aws_api_gateway_rest_api.bedrock_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.bedrock_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method
  
  integration_http_method = "POST"
  type                   = "HTTP_PROXY"
  uri                    = "http://${aws_instance.api_server.private_ip}"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  depends_on  = [aws_api_gateway_integration.proxy]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id  = aws_api_gateway_rest_api.bedrock_api.id
  stage_name   = "api"
}

# IAM role for EC2 to access Bedrock
resource "aws_iam_role" "bedrock_access" {
  name = "bedrock_access_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Bedrock access
resource "aws_iam_role_policy" "bedrock_policy" {
  name = "bedrock_access_policy"
  role = aws_iam_role.bedrock_access.id
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
      }
    ]
  })
}

# EC2 instance profile
resource "aws_iam_instance_profile" "bedrock_profile" {
  name = "bedrock_profile"
  role = aws_iam_role.bedrock_access.name
}

# Security Group for EC2 Instance
resource "aws_security_group" "allow_api" {
  name        = "allow_api"
  description = "Allow inbound traffic for API"
  
  ingress {
    description = "HTTP API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "api_server" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.bedrock_profile.name
  vpc_security_group_ids = [aws_security_group.allow_api.id]
  
  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }
  
  tags = {
    Name = "bedrock-api-server"
  }
}

# Latest Ubuntu ARM AMI lookup
data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Elastic IP
resource "aws_eip" "api_ip" {
  instance = aws_instance.api_server.id
}

# Outputs
output "api_url" {
  value = "${aws_api_gateway_stage.api_stage.invoke_url}"
}

output "server_ip" {
  value = aws_eip.api_ip.public_ip
}

output "ami_id" {
  value = data.aws_ami.ubuntu_arm.id
}

I need to customize this terraform deployment. Generate a set of questions to ask to modify the terraform infrastructure as code. Once you are done asking questions and I have answered them: I want you to regenerate the terraform config.

Here are the questions I want you to ask me sequentially:
"""
What is the current region of your AWS account, and do you want to keep it the same or switch to another region?
Do you want to use a different VPC for your AI backend?
What is the desired size of the EC2 instance for the AI backend? e.g. For cost reasons, the default instance type is t4g.small; however, not all AMI are compatible with ARM cpu architecture.
Do you want to allow inbound traffic on any port, or restrict it to specific ports (e.g., HTTPS on port 443 and HTTP on port 80)?
What is the desired duration for your CloudWatch log group retention?
Would you like to keep the existing output values (instance_public_ip and bedrock_endpoint) or change them?
Do you have any other resources (e.g., S3 buckets, DynamoDB tables) that need to be configured as part of this Terraform deployment?"""

After each question has been answered: move to the next question. These 7 questions are the only 7.

After all 7 questions are complete: propose an AMI appropriate for the instance type.

The default setting """# Latest Ubuntu ARM AMI lookup
data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}""" assumes t4g.small instance type with ARM cpu. Validate CPU / AMI compatibility before finalizing the terraform config.