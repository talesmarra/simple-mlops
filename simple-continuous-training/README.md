# Simple MLOps #1: Continuous Training Pipeline

This is a simple example of how to use Terraform, Lambda and Docker to create a continuous training pipeline.

The pipeline consists of a Lambda function that is triggered by a CloudWatch event every 1 week. 

The Lambda function reads data from a S3 bucket, trains a model and stores the model in another S3 bucket (the registry).

To use this example, you need to have Terraform installed and configured to use your AWS account.

First, login to ECR create an ECR repository to store the Docker image:

```bash
aws ecr create-repository \
    --repository-name ct-image-repo \
    --image-scanning-configuration scanOnPush=true \
    --region region
```

Then, create a .env file with the following variables:

```bash
AWS_REGION=(YOUR AWS REGION)
AWS_CT_ECR_REPO=(YOUR ECR REPO)
FUNCTION_NAME=ct-function
```

After that, run the following command:

```bash
just deploy-ct
```
