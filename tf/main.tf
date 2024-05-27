terraform {
  backend "s3" {
    bucket  = "cyclemap-function-terraform"
    key     = "terraform.tfstate"
    region  = "eu-west-1"
    profile = "vdna"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.51.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region  = "eu-central-1"
  profile = "vdna"
}

variable "mongodb_uri" {
  type      = string
  nullable  = false
  sensitive = true
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

locals {
  deployment_package = "../src/deployment_package-0.0.2.zip"
}

resource "aws_lambda_function" "cyclemap" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = local.deployment_package
  function_name = "cyclemap_entries"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256(local.deployment_package)

  architectures = ["arm64"]
  runtime       = "python3.12"

  environment {
    variables = {
      MONGODB_URI = var.mongodb_uri
    }
  }
}

resource "aws_lambda_function_url" "cyclemap_latest" {
  function_name      = aws_lambda_function.cyclemap.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

output "function_url" {
  description = "Lambda function URL"
  value       = aws_lambda_function_url.cyclemap_latest.function_url
}
