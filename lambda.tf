# ── PACKAGE LAMBDA FUNCTIONS ─────────────────────────────────────────────────

data "archive_file" "analyse_property" {
  type        = "zip"
  source_file = "${path.module}/../lambda/sokad-analyse-property/lambda_function.py"
  output_path = "${path.module}/../lambda/sokad-analyse-property/sokad-analyse-property.zip"
}

data "archive_file" "get_report" {
  type        = "zip"
  source_file = "${path.module}/../lambda/sokad-get-report/lambda_function.py"
  output_path = "${path.module}/../lambda/sokad-get-report/sokad-get-report.zip"
}

# ── CLOUDWATCH LOG GROUPS ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "analyse_property" {
  name              = "/aws/lambda/sokad-analyse-property"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "get_report" {
  name              = "/aws/lambda/sokad-get-report"
  retention_in_days = 30
}

# ── LAMBDA: sokad-analyse-property ───────────────────────────────────────────

resource "aws_lambda_function" "analyse_property" {
  function_name    = "sokad-analyse-property"
  filename         = data.archive_file.analyse_property.output_path
  source_code_hash = data.archive_file.analyse_property.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 600   # 10 minutes
  memory_size      = 1024

  layers = var.fpdf_layer_arn != "" ? [var.fpdf_layer_arn] : []

  environment {
    variables = {
      KB_ID    = aws_bedrockagent_knowledge_base.main.id
      MODEL_ID = "arn:aws:bedrock:${var.aws_region}:${var.aws_account_id}:inference-profile/global.anthropic.claude-sonnet-4-6"
      BUCKET   = var.bucket_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.analyse_property,
    aws_iam_role_policy_attachment.lambda_basic,
  ]

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

# ── LAMBDA: sokad-get-report ──────────────────────────────────────────────────

resource "aws_lambda_function" "get_report" {
  function_name    = "sokad-get-report"
  filename         = data.archive_file.get_report.output_path
  source_code_hash = data.archive_file.get_report.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BUCKET = var.bucket_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.get_report,
    aws_iam_role_policy_attachment.lambda_basic,
  ]

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

# ── S3 PERMISSION TO INVOKE Lambda ───────────────────────────────────────────

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analyse_property.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.main.arn
}

# ── API GATEWAY PERMISSIONS ───────────────────────────────────────────────────

resource "aws_lambda_permission" "apigw_get_report" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_report.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
