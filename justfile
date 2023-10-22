set dotenv-load

# create ECR repository
create-ecr repo_name:
    aws ecr create-repository --repository-name {{repo_name}} --image-scanning-configuration scanOnPush=true --region $AWS_REGION

# ---------------------------
# Continuous Training Recipes
# ---------------------------
build-ct-image:
    cd simple-continuous-training/python && docker build -t ct-image .

login-ecr:
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_CT_ECR_REPO

tag-ct-image:
    docker tag ct-image:latest $AWS_CT_ECR_REPO

push-ct-image:
    docker push $AWS_CT_ECR_REPO

deploy-ct-infra:
    cd simple-continuous-training && terraform plan && terraform apply -auto-approve

update-ct-code:
    aws lambda update-function-code --function-name $CT_FUNCTION_NAME --image-uri $AWS_CT_ECR_REPO:latest

deploy-ct:
    cd simple-continuous-training && sh deploy.sh

test-ct:
    pytest tests/simple-continuous-training/

# ---------------------------
# Registry Recipes
# ---------------------------
deploy-registry:
    cd simple-registry && terraform plan && terraform apply -auto-approve

# ---------------------------
# Inference Recipes
# ---------------------------
build-inf-image:
    cd simple-inference/python && docker build -t inference-image .

tag-inf-image:
    docker tag inference-image:latest $AWS_INF_ECR_REPO

push-inf-image:
    docker push $AWS_INF_ECR_REPO

update-inf-code:
    aws lambda update-function-code --function-name $INF_FUNCTION_NAME --image-uri $AWS_INF_ECR_REPO:latest

deploy-inf:
    cd simple-inference && sh deploy.sh

deploy-inf-infra:
    cd simple-inference && terraform plan && terraform apply -auto-approve

deploy-inference:
    cd simple-inference && sh deploy.sh