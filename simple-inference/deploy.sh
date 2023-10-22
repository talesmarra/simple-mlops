#!/bin/bash


# Build the container image
just build-inf-image

# Login to AWS ECR
just login-ecr

# Tag the container image
just tag-inf-image

# Push the container image to ECR
just push-inf-image

# update lambda function
just update-inf-code