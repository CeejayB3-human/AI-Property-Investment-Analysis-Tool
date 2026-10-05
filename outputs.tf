output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.main.bucket
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID — update Lambda environment variable KB_ID with this value"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "api_gateway_endpoint" {
  description = "API Gateway invoke URL — paste this into the UI HTML file"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "analyse_property_lambda_arn" {
  description = "sokad-analyse-property Lambda ARN"
  value       = aws_lambda_function.analyse_property.arn
}

output "get_report_lambda_arn" {
  description = "sokad-get-report Lambda ARN"
  value       = aws_lambda_function.get_report.arn
}

output "lambda_role_arn" {
  description = "IAM role ARN used by all Lambda functions"
  value       = aws_iam_role.lambda_role.arn
}

output "amplify_app_id" {
  description = "Amplify app ID"
  value       = aws_amplify_app.main.id
}

output "amplify_default_domain" {
  description = "Amplify default domain"
  value       = aws_amplify_app.main.default_domain
}

output "next_steps" {
  description = "Manual steps required after terraform apply"
  value = <<-EOT
    ============================================================
    NEXT STEPS AFTER TERRAFORM APPLY
    ============================================================
    1. Build and publish the fpdf2 Lambda Layer (see README)

    2. Upload Sokad market data to S3:
       aws s3 cp market-data/sokad-market-data.pdf \
         s3://${aws_s3_bucket.main.bucket}/market-data/

    3. Sync the Knowledge Base in Bedrock console:
       Knowledge Base ID: ${aws_bedrockagent_knowledge_base.main.id}

    4. Update the API URL in ui/index.html:
       Replace API endpoint with: ${aws_apigatewayv2_stage.default.invoke_url}

    5. Deploy the UI to Amplify:
       cd ui && zip -j ui.zip index.html
       Upload ui.zip via Amplify console manual deployment

    6. Test end to end by uploading a property PDF
    ============================================================
  EOT
}
