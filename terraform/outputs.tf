output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.s3_bucket_website.website_endpoint
}

output "api_gateway_invoke_url" {
  value = "http://${aws_api_gateway_rest_api.api.id}.execute-api.localhost.localstack.cloud:4566/${aws_api_gateway_stage.dev_stage.stage_name}"
}
