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

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on port ${port}`);
});