# ── S3 BUCKET ────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── BUCKET FOLDERS ────────────────────────────────────────────────────────────

resource "aws_s3_object" "uploads_folder" {
  bucket  = aws_s3_bucket.main.id
  key     = "uploads/"
  content = ""
}

resource "aws_s3_object" "market_data_folder" {
  bucket  = aws_s3_bucket.main.id
  key     = "market-data/"
  content = ""
}

resource "aws_s3_object" "reports_folder" {
  bucket  = aws_s3_bucket.main.id
  key     = "reports/"
  content = ""
}

# ── CORS (for browser direct upload via presigned URL) ────────────────────────

resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ── S3 TRIGGER → sokad-analyse-property Lambda ───────────────────────────────

resource "aws_s3_bucket_notification" "upload_trigger" {
  bucket = aws_s3_bucket.main.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.analyse_property.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
