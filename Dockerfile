# Stage 1: Build the application
FROM node:lts-alpine as builder

ENV NODE_ENV development

RUN npm install -g pnpm

WORKDIR /app

COPY package*.json pnpm-lock.yaml* ./


# Now you can install npm packages
RUN pnpm i

COPY . .

ENV NODE_ENV production

# Set the environment variable
ENV VITE_POCKETBASE_URL="https://mili-lifets-pocketbase.fly.dev/"

RUN pnpm run build

# Stage 2: Create the production image
FROM node:lts-alpine

WORKDIR /app


# Copy the built files from the previous stage
COPY --from=builder /app .

ENV PORT=3000

CMD ["node", "./build"]
