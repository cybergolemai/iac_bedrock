# Serverless AWS Bedrock API with Prompt Template and Guardrails

This project deploys a serverless API for AWS Bedrock using AWS Lambda and API Gateway. It uses a predefined prompt template and guardrails stored in AWS Bedrock and provides a simple HTTP endpoint to interact with the Llama model.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- AWS account with access to Bedrock service
- Access to the specified Bedrock prompt template and guardrail

## Project Structure

```
.
└── main.tf                 # Complete Terraform configuration including Lambda code
```

## Configuration

The project uses the following AWS services:
- AWS Lambda (Python 3.11 runtime)
- Amazon API Gateway
- AWS IAM (for permissions)
- AWS CloudWatch (for logging)
- Amazon Bedrock with:
  - Prompt Template (ARN: arn:aws:bedrock:us-west-2:381492005022:prompt/4NLYS6J1L0)
  - Guardrail (ARN: arn:aws:bedrock:us-west-2:381492005022:guardrail/k6tcx8eogg3w)

## Deployment

1. Clone this repository and navigate to the project directory

2. Deploy using Terraform:
```bash
terraform init
terraform apply
```

3. After deployment, Terraform will output the API URL. You can test it using curl:
```bash
curl -X POST https://your-api-url/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Hello, how are you?",
    "model_id": "meta.llama2-70b-chat-v1",
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
  "model_id": string,        // Optional: Bedrock model ID (default: meta.llama3-2-90b-instruct-v1:0)
  "max_tokens": number,      // Optional: Maximum tokens to generate (default: 4000)
  "temperature": number      // Optional: Temperature for sampling (default: 0.7)
}
```

The provided prompt is:
1. Combined with a predefined prompt template
2. Validated against configured guardrails
3. Sent to the model for processing

Response:
```json
{
  "completion": string,      // The model's response (generation for Llama models)
  "model": string           // The model ID used for the response
}
```

## Prompt Template and Guardrails

This API uses:
- Predefined prompt template (arn:aws:bedrock:us-west-2:381492005022:prompt/4NLYS6J1L0)
- Safety guardrails (arn:aws:bedrock:us-west-2:381492005022:guardrail/k6tcx8eogg3w)

The template provides the base context for all interactions, while the guardrails ensure the responses meet safety and content guidelines. User prompts are integrated into this template and validated before being sent to the model.

## Model Configuration

The API is configured to use Meta's Llama model by default with the following parameters:
- `max_gen_len`: Maximum generation length (from max_tokens parameter)
- `temperature`: Controls randomness in generation
- `top_p`: Set to 0.9 for balanced sampling

## Error Handling

The API returns appropriate HTTP status codes:
- 200: Successful response
- 400: Invalid request (missing prompt)
- 500: Server error (includes error message in response)
- Additional error codes may be returned by the guardrails if content violates guidelines

## Logging

Logs are stored in CloudWatch with a 48-hour retention period. The log group name is `/aws/lambda/bedrock-api`.

## Architecture

The deployment creates:
- A Python Lambda function with Bedrock integration
- API Gateway with a single POST endpoint
- IAM roles and policies for Lambda execution
- CloudWatch log group for monitoring

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
- Content safety through Bedrock guardrails

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Customization

The main.tf file contains all necessary code, including the Lambda function. To customize:

1. Modify the Lambda function code in the `local_file` resource
2. Adjust IAM permissions in the `aws_iam_role_policy` resource
3. Configure API Gateway settings in the respective resources
4. Update environment variables in the Lambda function resource
5. Change the prompt template ARN or guardrail ARN if needed

## Troubleshooting

Common issues:
1. Missing AWS credentials: Ensure AWS CLI is configured
2. Bedrock access: Verify your AWS account has Bedrock enabled
3. Region availability: Check if Bedrock is available in your chosen region
4. Prompt template access: Ensure you have access to the specified promptArn
5. Guardrail access: Verify access to the specified guardrailArn
6. Model availability: Verify access to the Llama model in your region
7. Guardrail rejections: Check CloudWatch logs for details about content that violated guardrails

## License

MIT License