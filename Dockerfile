# Stage 1: Build the application
FROM node:lts-alpine as builder

ENV NODE_ENV development

RUN npm install -g pnpm

WORKDIR /app

COPY package*.json pnpm-lock.yaml* ./

# Install Python 3 before installing npm packages
RUN apk add --no-cache python3
RUN ln -sf python3 /usr/bin/python

# Now you can install npm packages
RUN pnpm i

COPY . .

ENV NODE_ENV production

# Set the environment variable with the path to Python 3
ENV YOUTUBE_DL_PYTHON_PATH=/usr/bin/python3
ENV VITE_POCKETBASE_URL="https://mili-lifets-pocketbase.fly.dev/"

RUN pnpm run build

# Stage 2: Create the production image
FROM node:lts-alpine

WORKDIR /app

# Install Python 3 and other required packages
RUN apk add --no-cache python3

# Set up a symlink to 'python' binary to be used by youtube-dl-exec
RUN ln -sf python3 /usr/bin/python

# Copy the built files from the previous stage
COPY --from=builder /app .

ENV PORT=3000

CMD ["node", "./build"]
