#!/bin/bash


# Build the container image
just build-ct-image

# Login to AWS ECR
just login-ecr

# Tag the container image
just tag-ct-image

# Push the container image to ECR
just push-ct-image

# Deploy infrastructure with Terraform
just deploy-ct-infra


