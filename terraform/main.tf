terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "fake"
  secret_key = "fake"

  # only required for non virtual hosted-style endpoint use case.
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs#s3_force_path_style
  s3_use_path_style           = false
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    sts        = "http://localhost:4566"
    s3         = "http://s3.localhost.localstack.cloud:4566"
    lambda     = "http://localhost:4566"
    iam        = "http://localhost:4566"
    apigateway = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_website_configuration" "s3_bucket_website" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_acl" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          "${aws_s3_bucket.s3_bucket.arn}/*",
        ]
      }
    ]
  })
}

locals {
  bucket_name = "testbucket"
  dist_dir    = abspath("${path.module}/../frontend/dist")

  asset_files = {
    for file in fileset(local.dist_dir, "assets/*") : file => lookup({
      "js"  = "text/javascript"
      "css" = "text/css"
      "svg" = "image/svg+xml"
    }, replace(regex("\\.[^.]*$", file), ".", ""), "application/octet-stream")
  }

  lambda_dir = abspath("${path.module}/../lambda")
}

resource "aws_s3_object" "object_www" {
  for_each     = fileset(local.dist_dir, "*.html")
  bucket       = local.bucket_name
  key          = basename(each.value)
  source       = "${local.dist_dir}/${each.value}"
  content_type = "text/html"
  acl          = "public-read"
}

resource "aws_s3_object" "object_assets" {
  for_each     = local.asset_files
  bucket       = local.bucket_name
  key          = each.key
  source       = "${local.dist_dir}/${each.key}"
  content_type = each.value
  acl          = "public-read"
}

# Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${local.lambda_dir}/index.js"
  output_path = "${path.module}/files/index.zip"
}

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "lambda-code-bucket"
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_code_bucket.bucket
  key    = "index.zip"
  source = data.archive_file.lambda_zip.output_path
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "handler"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_code_bucket.id
  s3_key    = aws_s3_object.lambda_code.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "lambda_exec_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


# APIGateway
resource "aws_api_gateway_rest_api" "api" {
  name = "lambda-api"
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "api"
      version = "1.0.0"
    }
    paths = {
      "/health" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "POST"
            payloadFormatVersion = "1.0"
            type                 = "AWS_PROXY"
            uri                  = aws_lambda_function.lambda_function.invoke_arn
          }
        }
      }
    }
  })
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev_stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
