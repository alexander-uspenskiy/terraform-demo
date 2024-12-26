# Terraform Demo Project

## Scope

Demo Progect - how to create a high performance and secure web server architecture in AWS with a Terraform script 

## Description

The main.ts script creates two servers with Ngnix web server in private subnet with Application Load Balancer, NAT (for egress trafic) and Internet Gateway - ready to use architecture

## Architecture Diagram

![Architecture Diagram](Resourses/Terraform-Demo.png)

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/)
- [Terraform](https://www.terraform.io/)

## Installation

### AWS CLI

1. Install the AWS CLI using Homebrew:
    ```sh
    brew install awscli
    ```

2. Verify the installation:
    ```sh
    aws --version
    ```

3. Configure the AWS CLI:
    ```sh
    aws configure
    ```

### Terraform

1. Install Terraform using Homebrew:
    ```sh
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
    ```

2. Verify the installation:
    ```sh
    terraform -version
    ```

## Usage

1. Initialize the Terraform configuration:
    ```sh
    terraform init
    ```

2. Create an execution plan:
    ```sh
    terraform plan
    ```

3. Apply the Terraform configuration:
    ```sh
    terraform apply
    ```

4. Destroy the Terraform-managed infrastructure:
    ```sh
    terraform destroy
    ```
## How to execute

1. Create a Free Tier Account in AWS (https://aws.amazon.com/free/)

2. Setup CLI

3. Install Terraform

4. Apply configuration

5. See output (for example alb_dns_name = "terraform-alb-1525092884.us-east-1.elb.amazonaws.com")

6. Browse to your alb_dns_name url (don't forgrt to use **http://**)

7. Refresh the page several time to make sure ALB routes you to web-server-1 or web-server-2

8. Do terraform destroy to releadse resources and stay on free tier credit.


## Resources

- [Terraform Documentation](https://www.terraform.io/docs/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

Happy Coding!
