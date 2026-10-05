# ── AMPLIFY APP ───────────────────────────────────────────────────────────────

resource "aws_amplify_app" "main" {
  name        = "sokad-property-ai"
  description = "Sokad Creations AI Property Investment Analysis Tool"

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.main.id
  branch_name = "main"
  stage       = "PRODUCTION"

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}
