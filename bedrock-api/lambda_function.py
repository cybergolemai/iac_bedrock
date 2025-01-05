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
        model_id = body.get('model_id', 'anthropic.claude-v2')
        max_tokens = body.get('max_tokens', 1000)
        temperature = body.get('temperature', 0.7)
        
        if not prompt:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'prompt is required'})
            }
        
        # Prepare request for Bedrock
        request_body = json.dumps({
            "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
            "max_tokens": max_tokens,
            "temperature": temperature
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
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'completion': response_body.get('completion'),
                'model': model_id
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }