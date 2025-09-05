# Multi-stage Dockerfile for MinIO Rate Limiting Test Suite
# =======================================================

# Build stage
ARG GO_VERSION=1.24
FROM golang:${GO_VERSION}-alpine AS builder

# Install git and ca-certificates for dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o minio-ratelimit-test .

# Final stage - minimal runtime image
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/minio-ratelimit-test .

# Make it executable
RUN chmod +x ./minio-ratelimit-test

# Expose any ports if needed (none required for this app)
# EXPOSE 8080

# Set default command
ENTRYPOINT ["./minio-ratelimit-test"]

# Default arguments (can be overridden)
CMD ["-duration=30s", "-accounts=1"]

# Add labels for better maintainability
LABEL maintainer="MinIO Rate Limiting Test Suite"
LABEL description="Comprehensive MinIO rate limiting testing tool"
LABEL version="1.0.0"
