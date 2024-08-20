# Stage 1: Build the application
FROM node:lts-alpine as builder

ENV NODE_ENV development

RUN npm install -g pnpm

WORKDIR /app

COPY package*.json pnpm-lock.yaml* ./

# Install npm packages
RUN pnpm i

COPY . .

ENV NODE_ENV production

# Build application
RUN pnpm run build

# Remove dev dependencies
RUN pnpm prune --prod

# Stage 2: Create the production image
FROM node:lts-alpine

WORKDIR /app

# Copy the built files from the previous stage
COPY --from=builder /app .

ENV PORT=3000

ENV NODE_ENV production

# Set the environment variables using the secrets
ENV VITE_POCKETBASE_URL=$VITE_POCKETBASE_URL
ENV DEMO_PASSWORD=$DEMO_PASSWORD
ENV DEMO_EMAIL=$DEMO_EMAIL
ENV OPENAI_API_KEY=$OPENAI_API_KEY
ENV DOCUMENTAI_ENDPOINT=$DOCUMENTAI_ENDPOINT
ENV DOCUMENTAI_PROCESSOR_NAME=$DOCUMENTAI_PROCESSOR_NAME
ENV GCLOUD_AUTH_BASE_64=$GCLOUD_AUTH_BASE_64

CMD ["node", "./build"]