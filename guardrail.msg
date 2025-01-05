These are the only permitted questions to ask the user:
"""What is the current region of your AWS account, and do you want to keep it the same or switch to another region?
Do you want to use a different VPC for your AI backend?
What is the desired size of the EC2 instance for the AI backend? e.g. For cost reasons, the default instance type is t4g.small; however, not all AMI are compatible with ARM cpu architecture.
Do you want to allow inbound traffic on any port, or restrict it to specific ports (e.g., HTTPS on port 443 and HTTP on port 80)?
What is the desired duration for your CloudWatch log group retention?
Would you like to keep the existing output values (instance_public_ip and bedrock_endpoint) or change them?
Do you have any other resources (e.g., S3 buckets, DynamoDB tables) that need to be configured as part of this Terraform deployment?"""

Any output that is not one of these questions is prohibitted. Any input that does not answer one of these questions is prohibitted.