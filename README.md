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
curl -X POST http://localhost/invoke \
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

## Running Locally with Docker

You can run the Bedrock API locally on the EC2 instance using Docker instead of the systemd service.

### Prerequisites
- Docker installed on the EC2 instance
```bash
# Install Docker on Ubuntu
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu
# Log out and back in for group changes to take effect
```

### Docker Setup
1. Create a directory for the API:
```bash
mkdir bedrock-api
cd bedrock-api
```

2. Create two files:

`Dockerfile`:
```dockerfile
FROM node:20-slim

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Create package.json if it doesn't exist
RUN if [ ! -f package.json ]; then echo '{"name": "bedrock-api","version": "1.0.0","main": "server.js"}' > package.json; fi

# Install dependencies
RUN npm install express @aws-sdk/client-bedrock-runtime

# Copy server code
COPY server.js .

# Set required environment variables
ENV PORT=80
ENV AWS_REGION=us-west-2

# Expose the port
EXPOSE 80

# Start the server
CMD ["node", "server.js"]
```

`server.js`:
```javascript
const express = require('express');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
const app = express();
const port = process.env.PORT || 80;

// Initialize Bedrock client
const bedrock = new BedrockRuntimeClient({ 
    region: process.env.AWS_REGION || 'us-west-2'
});

app.use(express.json());

app.post('/invoke', async (req, res) => {
    try {
        const { prompt, model_id = 'meta.llama3-2-90b-instruct-v1:0', max_tokens = 1000, temperature = 0.7 } = req.body;

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

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on port ${port}`);
});
```

3. Build the Docker image:
```bash
docker build -t bedrock-api .
```

4. Run the container:
```bash
docker run -d -p 80:80 \
  -e AWS_ACCESS_KEY_ID=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/bedrock_access_role | jq -r '.AccessKeyId') \
  -e AWS_SECRET_ACCESS_KEY=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/bedrock_access_role | jq -r '.SecretAccessKey') \
  -e AWS_SESSION_TOKEN=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/bedrock_access_role | jq -r '.Token') \
  -e AWS_REGION=us-west-2 \
  --name bedrock-api \
  --restart unless-stopped \
  bedrock-api
```

### Managing the Container

Check container status:
```bash
docker ps
```

View logs:
```bash
docker logs bedrock-api
```

Stop the container:
```bash
docker stop bedrock-api
```

Start the container:
```bash
docker start bedrock-api
```

Remove the container:
```bash
docker rm bedrock-api
```

### Testing the API

Test the health endpoint:
```bash
curl http://localhost/health
```

Test the API:
```bash
curl -X POST http://localhost/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "us-west-2",
    "model_id": "meta.llama3-2-90b-instruct-v1:0",
    "max_tokens": 1000,
    "temperature": 0.7
  }'
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