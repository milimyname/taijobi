# ---- Build Stage ----
FROM node:lts-alpine AS build

# Create app directory
WORKDIR /usr/src/app

# Copy project file
COPY package*.json ./

# Install pnpm and build dependencies
RUN npm install -g pnpm && pnpm install

# Copy app files
COPY . .

# Build app
RUN pnpm build

# ---- Run Stage ----
FROM node:lts-alpine AS run

# Set working directory
WORKDIR /usr/src/app

# Install serve
RUN npm install -g serve

# Copy built app
COPY --from=build /usr/src/app/build ./build

# Expose port
EXPOSE 5000

# Run the app
CMD ["serve", "-s", "build", "-l", "5000"]
