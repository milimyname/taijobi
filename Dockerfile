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
# Note: Secret management is a bit tricky. Make sure the secret is available at build time.
# If you're using Docker secrets, the secret should be available as a file in /run/secrets/
# Here, we're assuming VITE_POCKETBASE_URL is available as a file at /run/secrets/VITE_POCKETBASE_URL
ARG VITE_POCKETBASE_URL
RUN --mount=type=secret,id=VITE_POCKETBASE_URL \
    export VITE_POCKETBASE_URL="$(cat /run/secrets/VITE_POCKETBASE_URL)" && \
    pnpm run build

# Remove dev dependencies
RUN pnpm prune --prod

# Stage 2: Create the production image
FROM node:lts-alpine

WORKDIR /app

# Copy the built files from the previous stage
COPY --from=builder /app .

ENV PORT=3000

ENV NODE_ENV production

# Set the environment variable here. It's important to understand that this value will not be
# the secret value from the build stage, but rather a placeholder to be set at container runtime.
ENV VITE_POCKETBASE_URL=${VITE_POCKETBASE_URL}

CMD ["node", "./build"]
