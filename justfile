set dotenv-load

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

update-code:
    aws lambda update-function-code --function-name $FUNCTION_NAME --image-uri $AWS_CT_ECR_REPO:latest

deploy-ct:
    cd simple-continuous-training && sh deploy.sh
