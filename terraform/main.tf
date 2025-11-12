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
    sts = "http://localhost:4566"
    s3  = "http://s3.localhost.localstack.cloud:4566"
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
