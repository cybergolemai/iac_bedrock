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
            "guardrailArn": "arn:aws:bedrock:us-west-2:381492005022:guardrail/k6tcx8eogg3w",
            "prompt": prompt,
            "max_gen_len": max_tokens,  # Llama uses max_gen_len instead of max_tokens
            "temperature": temperature,
            "top_p": 0.9  # Common Llama parameter
        })
        
        # Invoke Bedrock model
        response = bedrock.invoke_model(
            modelId=model_id,
            contentType="application/json",
            accept="application/json",
            body=request_body
        )
        
        # Parse response - Llama response structure is different
        response_body = json.loads(response['body'].read())
        completion = response_body.get('generation', '')  # Llama uses 'generation' instead of 'completion'
        
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