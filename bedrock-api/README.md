# AWS Bedrock API with EC2 Backend

This project deploys an API for AWS Bedrock using EC2 and API Gateway. It uses a Node.js server running on a t4g.small instance to handle API requests, with integrated prompt templates and guardrails.

## Architecture

- EC2 (t4g.small) running Node.js server
- API Gateway for request routing
- CloudWatch for logging
- IAM roles for Bedrock access
- Elastic IP for stable addressing
- Systemd service for process management

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- AWS account with access to Bedrock service
- Access to the specified Bedrock prompt template and guardrail

## Project Structure

```
.
├── README.md
├── variables.tf    # Variable definitions
└── main.tf        # Main infrastructure configuration
```

## Configuration Files

### variables.tf
Contains configurable variables:
- AWS region (default: us-west-2)
- Instance type (default: t4g.small)
- Volume size (default: 20GB)

### main.tf
Contains:
- Infrastructure configuration
- Node.js server code
- Systemd service configuration
- API Gateway setup
- Security group rules
- IAM roles and policies

## Deployment

1. Clone this repository:
```bash
git clone <repository-url>
cd <repository-directory>
```

2. Initialize Terraform:
```bash
terraform init
```

3. Deploy the infrastructure:
```bash
terraform apply
```

4. After deployment, Terraform will output:
- `api_url`: The API Gateway URL for making requests
- `server_ip`: The EC2 instance's public IP

## API Usage

Send requests to the API:
```bash
curl -X POST https://your-api-url \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "us-west-2",
    "model_id": "meta.llama3-2-90b-instruct-v1:0",
    "max_tokens": 4000,
    "temperature": 0.7
  }'
```

## Configuration Details

### Ports
- 80: HTTP API
- 22: SSH access
- 11434: Ollama compatibility

### AWS Bedrock Configuration
- Prompt Template ARN: arn:aws:bedrock:us-west-2:381492005022:prompt/4NLYS6J1L0
- Guardrail ARN: arn:aws:bedrock:us-west-2:381492005022:guardrail/k6tcx8eogg3w

### EC2 Instance
- ARM-based t4g.small instance
- Ubuntu 22.04 LTS
- 20GB gp3 root volume
- Node.js 20.x

## Monitoring and Logging

Logs are available in CloudWatch:
- Path: /aws/ec2/bedrock-api
- Retention: 2 days

On the EC2 instance:
- Application logs: `journalctl -u bedrock-api`
- System logs: `/var/log/syslog`

## Security

- IAM roles with least privilege
- Security group with minimal required ports
- API Gateway integration
- Content safety through Bedrock guardrails

## Maintenance

### Accessing the EC2 Instance
```bash
ssh ubuntu@<server_ip>
```

### Managing the API Service
```bash
# Check service status
sudo systemctl status bedrock-api

# Restart service
sudo systemctl restart bedrock-api

# View logs
journalctl -u bedrock-api -f
```

### Updating the Application
1. SSH into the instance
2. Navigate to /home/ubuntu
3. Update the code
4. Restart the service

## Cost Considerations

This setup incurs costs for:
- EC2 t4g.small instance (24/7 running)
- API Gateway requests
- Bedrock model usage
- CloudWatch logs
- Elastic IP (when not attached to a running instance)

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Troubleshooting

1. API not responding:
   - Check EC2 instance status
   - Verify service is running: `systemctl status bedrock-api`
   - Check security group rules

2. Bedrock errors:
   - Verify IAM roles and permissions
   - Check prompt template and guardrail access
   - Review CloudWatch logs

3. Deployment issues:
   - Ensure AWS credentials are configured
   - Verify region compatibility
   - Check terraform.tfstate file

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License