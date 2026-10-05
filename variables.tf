variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "Your AWS account ID"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "sokad"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "sokad-property-ai"
}

variable "fpdf_layer_arn" {
  description = "ARN of the fpdf2 Lambda Layer (built separately via CloudShell — see README)"
  type        = string
  default     = ""
}

variable "knowledge_base_embedding_model" {
  description = "Embedding model ARN for Bedrock Knowledge Base"
  type        = string
  default     = "arn:aws:bedrock:us-west-2::foundation-model/amazon.titan-embed-text-v2:0"
}
