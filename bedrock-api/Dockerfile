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