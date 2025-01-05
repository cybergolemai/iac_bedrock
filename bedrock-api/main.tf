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
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/ec2/bedrock-api"
  retention_in_days = 2
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

# IAM policy for Bedrock access and CloudWatch logging
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
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.api_logs.arn}:*"
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

  ingress {
    description = "Ollama"
    from_port   = 11434
    to_port     = 11434
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

# Create Node.js server code
resource "local_file" "server_js" {
  filename = "${path.module}/server.js"
  content  = <<-EOT
const express = require('express');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
const app = express();
const port = 80;

// Initialize Bedrock client
const bedrock = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

app.use(express.json());

app.post('/invoke', async (req, res) => {
  try {
    const { prompt, model_id = 'meta.llama3-2-90b-instruct-v1:0', max_tokens = 4000, temperature = 0.7 } = req.body;

    if (!prompt) {
      return res.status(400).json({ error: 'prompt is required' });
    }

    // Prepare request for Bedrock with Llama-specific format and guardrail
    const params = {
      modelId: model_id,
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({
        promptArn: "arn:aws:bedrock:us-west-2:381492005022:prompt/4NLYS6J1L0",
        guardrailArn: "arn:aws:bedrock:us-west-2:381492005022:guardrail/k6tcx8eogg3w",
        prompt: prompt,
        max_gen_len: max_tokens,
        temperature: temperature,
        top_p: 0.9
      })
    };

    const command = new InvokeModelCommand(params);
    const response = await bedrock.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    res.json({
      completion: responseBody.generation,
      model: model_id
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOT
}

# Create systemd service file
resource "local_file" "systemd_service" {
  filename = "${path.module}/bedrock-api.service"
  content  = <<-EOT
[Unit]
Description=Bedrock API Server
After=network.target

[Service]
Environment=AWS_REGION=${var.aws_region}
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/bin/node server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT
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

  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
              sudo apt-get install -y nodejs

              # Install dependencies
              cd /home/ubuntu
              sudo -u ubuntu npm init -y
              sudo -u ubuntu npm install express @aws-sdk/client-bedrock-runtime

              # Setup systemd service
              mv /tmp/bedrock-api.service /etc/systemd/system/
              systemctl enable bedrock-api
              systemctl start bedrock-api
              EOF
  
  tags = {
    Name = "bedrock-api-server"
  }
}

# Elastic IP
resource "aws_eip" "api_ip" {
  instance = aws_instance.api_server.id
  domain   = "vpc"
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

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method
  
  integration_http_method = "POST"
  type                   = "HTTP_PROXY"
  uri                    = "http://${aws_instance.api_server.private_ip}/invoke"
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

# Outputs
output "api_url" {
  value = "${aws_api_gateway_stage.api_stage.invoke_url}/invoke"
}

output "server_ip" {
  value = aws_eip.api_ip.public_ip
}