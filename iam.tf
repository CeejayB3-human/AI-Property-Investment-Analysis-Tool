# ── LAMBDA EXECUTION ROLE ────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_role" {
  name = "property-ai-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "bedrock_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "textract_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonTextractFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── BEDROCK KNOWLEDGE BASE ROLE ───────────────────────────────────────────────

resource "aws_iam_role" "bedrock_kb_role" {
  name = "AmazonBedrockExecutionRoleForKnowledgeBase-sokad"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_s3" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_bedrock" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_marketplace" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSMarketplaceFullAccess"
}
