# ── HTTP API ─────────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "main" {
  name          = "sokad-property-api"
  protocol_type = "HTTP"
  description   = "Sokad Creations AI Property Investment Analysis API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

# ── DEFAULT STAGE ─────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# ── INTEGRATION ───────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_integration" "get_report" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_report.invoke_arn
  payload_format_version = "2.0"
}

# ── ROUTES ────────────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_route" "upload_url" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /upload-url"
  target    = "integrations/${aws_apigatewayv2_integration.get_report.id}"
}

resource "aws_apigatewayv2_route" "report_status" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /report-status"
  target    = "integrations/${aws_apigatewayv2_integration.get_report.id}"
}
