# ── OPENSEARCH SERVERLESS (Vector Store) ─────────────────────────────────────

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "sokad-kb-encryption"
  type        = "encryption"
  description = "Encryption policy for Sokad market KB vector store"
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/sokad-kb-vectors"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "sokad-kb-network"
  type        = "network"
  description = "Network policy for Sokad market KB vector store"
  policy = jsonencode([{
    Rules = [
      { ResourceType = "collection", Resource = ["collection/sokad-kb-vectors"] },
      { ResourceType = "dashboard",  Resource = ["collection/sokad-kb-vectors"] }
    ]
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_access_policy" "data" {
  name        = "sokad-kb-data-access"
  type        = "data"
  description = "Data access policy for Bedrock Knowledge Base"
  policy = jsonencode([{
    Rules = [
      { ResourceType = "index",      Resource = ["index/sokad-kb-vectors/*"], Permission = ["aoss:*"] },
      { ResourceType = "collection", Resource = ["collection/sokad-kb-vectors"], Permission = ["aoss:*"] }
    ]
    Principal = [
      aws_iam_role.bedrock_kb_role.arn,
      "arn:aws:iam::${var.aws_account_id}:root"
    ]
  }])
}

resource "aws_opensearchserverless_collection" "kb_vectors" {
  name        = "sokad-kb-vectors"
  type        = "VECTORSEARCH"
  description = "Vector store for Sokad UK property market data"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
  ]

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

# ── BEDROCK KNOWLEDGE BASE ────────────────────────────────────────────────────

resource "aws_bedrockagent_knowledge_base" "main" {
  name        = "sokad-market-kb"
  description = "Sokad UK property market data, sourcing criteria and ROI methodology"
  role_arn    = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = var.knowledge_base_embedding_model
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.kb_vectors.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  depends_on = [
    aws_opensearchserverless_collection.kb_vectors,
    aws_iam_role_policy_attachment.bedrock_kb_bedrock,
    aws_iam_role_policy_attachment.bedrock_kb_s3,
  ]

  tags = {
    Project   = "Sokad-PropertyAI"
    ManagedBy = "Terraform"
  }
}

# ── KNOWLEDGE BASE DATA SOURCE ────────────────────────────────────────────────

resource "aws_bedrockagent_data_source" "market_data" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "sokad-market-data"
  description       = "Sokad UK property market data PDF"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.main.arn
      inclusion_prefixes = ["market-data/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}
