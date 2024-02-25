## Description
AWS Terraform NestJS boilerplate that runs on AWS ECS Fargate.

## Installation

```bash
$ npm install
```

## Running the app

```bash
# development
$ npm run start

# watch mode
$ npm run start:dev

# production mode
$ npm run start:prod
```

## Test

```bash
# unit tests
$ npm run test

# e2e tests
$ npm run test:e2e

# test coverage
$ npm run test:cov
```

## AWS and Terraform
- Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) or [OpenTofu](https://opentofu.org/)
- Set up your AWS credentials and AWS CLI
- Run the following commands to create the infrastructure on AWS
```bash
cd terraform
terraform init
terraform plan
terraform apply
```
or use `tofu` if you prefer it to `terraform`.

### Docker
- Build the image

<small>swap <IMAGE_NAME> with the name of your image in the following command:</small>
```bash
docker build -t <IMAGE_NAME> .
```
- Run the image to test it locally
```bash
docker run -p 3000:3000 --rm <IMAGE_NAME>
```
- Login to ECR

<small>replace <MY_REGION> with the region of your ECR and <ACCOUNT_ID> with your AWS account id in the following command:</small>
```bash
aws ecr get-login-password --region <MY_REGION> | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com
```
- Tag the image

<small>replace <MY_REPOSITORY> with the name of your ECR repository in the following command:</small>
```bash
 docker tag <IMAGE_NAME>:latest <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/<MY_REPOSITORY>:latest
```
- Push the image to ECR
```bash
docker push <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/<MY_REPOSITORY>:latest
```

After this, service should be available on AWS.
