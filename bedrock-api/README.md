# Serverless AWS Bedrock API

This project deploys a serverless API for AWS Bedrock using AWS Lambda and API Gateway. It provides a simple HTTP endpoint to interact with various AI models available through Amazon Bedrock.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- Python 3.11 or later
- AWS account with access to Bedrock service

## Project Structure

```
.
├── README.md
├── main.tf                 # Main Terraform configuration
├── variables.tf           # Terraform variables
└── lambda_function.py    # Lambda function code
```

## Configuration

The project uses the following AWS services:
- AWS Lambda
- Amazon API Gateway
- AWS IAM (for permissions)
- AWS CloudWatch (for logging)
- Amazon Bedrock

## Deployment

1. Create a zip file containing the Lambda function:
```bash
zip lambda_function.zip lambda_function.py
```

2. Initialize and apply the Terraform configuration:
```bash
terraform init
terraform apply
```

3. After deployment, Terraform will output the API URL. You can test it using curl:
```bash
curl -X POST https://your-api-url/api/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Hello, how are you?",
    "model_id": "anthropic.claude-v2",
    "max_tokens": 1000,
    "temperature": 0.7
  }'
```

## API Reference

### Endpoint: POST /invoke

Request Body:
```json
{
  "prompt": string,           // Required: The prompt to send to the model
  "model_id": string,        // Optional: Bedrock model ID (default: anthropic.claude-v2)
  "max_tokens": number,      // Optional: Maximum tokens to generate (default: 1000)
  "temperature": number      // Optional: Temperature for sampling (default: 0.7)
}
```

Response:
```json
{
  "completion": string,      // The model's response
  "model": string           // The model ID used for the response
}
```

## Available Models

Some commonly used model IDs include:
- `anthropic.claude-v2`
- `anthropic.claude-instant-v1`
- `amazon.titan-text-express-v1`
- `ai21.j2-ultra-v1`

## Error Handling

The API returns appropriate HTTP status codes:
- 200: Successful response
- 400: Invalid request (missing prompt)
- 500: Server error (includes error message in response)

## Logging

Logs are stored in CloudWatch with a 48-hour retention period. The log group name is `/aws/lambda/bedrock-api`.

## Cost Considerations

This setup uses serverless architecture, so you only pay for:
- Lambda invocations and compute time
- API Gateway requests
- Bedrock model usage
- CloudWatch logs storage

## Security

The deployment includes:
- IAM roles with least privilege access
- CloudWatch logging
- API Gateway integration

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License