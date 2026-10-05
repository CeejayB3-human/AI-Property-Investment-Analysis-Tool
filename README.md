# AI Property Investment Analysis Tool

> An AI-powered property investment analysis tool built on AWS. An agent uploads a property PDF, and within 90 seconds receives a complete branded investment report — including ROI projection, Sokad criteria check, risk flags, market context and a client email draft — ready to download.

<img width="822" height="1280" alt="1780651118857" src="https://github.com/user-attachments/assets/329470c1-1c68-4c3f-a19b-c04ff556219f" />





---

## Architecture

```

Agent (Browser)
        │
        ▼
AWS Amplify (Agent UI)
        │
  GET /upload-url
        │
        ▼
Amazon API Gateway
        │
        ▼
AWS Lambda (sokad-get-report)
generates presigned URL
        │
        ▼
Agent uploads PDF directly
Amazon S3 (uploads/ folder)
        │
  S3 ObjectCreated trigger
        │
        ▼
AWS Lambda (sokad-analyse-property)
        │
   ┌────┴─────────────────┐
   │                       │
   ▼                       ▼
Amazon Textract      Bedrock KB
reads PDF            (sokad-market-kb)
extracts text        retrieves Sokad
                     market data via RAG
   │                       │
   └────────┬──────────────┘
            │
            ▼
   Claude Sonnet 4.6
   generates investment report:
   - Property Summary
   - ROI Projection
   - Sokad Criteria Check (PASS/FAIL)
   - Risk Flags
   - Market Context
   - Verdict
   - Client Email Draft
            │
            ▼
   fpdf2 builds branded PDF
            │
            ▼
   Amazon S3 (reports/ folder)
            │
   Agent polls /report-status
            │
            ▼
   Agent downloads PDF report
```

---

## AWS Services Used

| Service | Component | Purpose |
|---|---|---|
| Amazon S3 | sokad-property-ai | Stores uploaded PDFs (uploads/), market data (market-data/) and reports (reports/) |
| Amazon Textract | Document Analysis API | Reads and extracts structured text from property PDF documents |
| Amazon Bedrock | Knowledge Base (sokad-market-kb) | Indexes Sokad UK market data for RAG retrieval |
| Amazon Bedrock | Claude Sonnet 4.6 | Generates the complete investment report |
| Amazon Bedrock | Titan Text Embeddings V2 | Converts market data to vector embeddings |
| Amazon OpenSearch Serverless | Auto-provisioned vector store | Stores and searches vector embeddings |
| AWS Lambda | sokad-analyse-property | Core: Textract + KB retrieval + Claude + PDF generation |
| AWS Lambda | sokad-get-report | Generates presigned URLs and checks report status |
| Amazon API Gateway | sokad-property-api | GET /upload-url and GET /report-status endpoints |
| AWS Amplify | Agent UI | Hosts the agent-facing web interface |
| AWS IAM | property-ai-lambda-role | Execution role for Lambda functions |
| Amazon CloudWatch | Log groups | Execution logs for both Lambda functions |

---

## Repository Structure

```
sokad-property-ai/
├── README.md
├── .gitignore
├── terraform/
│   ├── main.tf             # Provider configuration
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Outputs + next steps
│   ├── s3.tf               # S3 bucket, folders, CORS, S3 trigger
│   ├── iam.tf              # IAM roles and policies
│   ├── bedrock.tf          # Knowledge Base and OpenSearch
│   ├── lambda.tf           # Lambda functions and permissions
│   ├── api_gateway.tf      # HTTP API and routes
│   └── amplify.tf          # Amplify hosting
├── lambda/
│   ├── sokad-analyse-property/
│   │   └── lambda_function.py   # Textract + RAG + Claude + PDF
│   └── sokad-get-report/
│       └── lambda_function.py   # Presigned URL + status check
├── ui/
│   └── index.html          # Agent chat interface
└── market-data/
    └── (add sokad-market-data.pdf here)
```

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- AWS account with Amazon Bedrock access enabled
  - Claude Sonnet 4.6 model access granted in us-west-2
  - Titan Text Embeddings V2 access granted
- AWSMarketplaceFullAccess attached to your IAM user

---

## Deployment Guide

### Step 1 — Build the fpdf2 Lambda Layer

Run these commands in AWS CloudShell (us-west-2):

```bash
mkdir -p /tmp/fpdf-layer/python

pip install fpdf2 -t /tmp/fpdf-layer/python --quiet

cd /tmp/fpdf-layer && zip -r fpdf-layer.zip python/

aws lambda publish-layer-version \
  --layer-name fpdf-layer \
  --zip-file fileb://fpdf-layer.zip \
  --compatible-runtimes python3.12 \
  --region us-west-2
```

Copy the `LayerVersionArn` from the output — you will need it in Step 3.

---

### Step 2 — Clone and configure

```bash
git clone https://github.com/YOUR_USERNAME/sokad-property-ai.git
cd sokad-property-ai
```

---

### Step 3 — Set Terraform variables

Create `terraform/terraform.tfvars`:

```hcl
aws_account_id = "YOUR_12_DIGIT_ACCOUNT_ID"
aws_region     = "us-west-2"
bucket_name    = "sokad-property-ai"
fpdf_layer_arn = "arn:aws:lambda:us-west-2:YOUR_ACCOUNT_ID:layer:fpdf-layer:1"
```

> **Important:** Do not commit `terraform.tfvars` to GitHub — it is already in `.gitignore`.

---

### Step 4 — Deploy with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

### Step 5 — Upload Sokad market data

```bash
aws s3 cp market-data/sokad-market-data.pdf \
  s3://sokad-property-ai/market-data/ \
  --region us-west-2
```

---

### Step 6 — Sync the Knowledge Base

1. Go to **Amazon Bedrock → Knowledge bases** in the AWS console
2. Click on **sokad-market-kb**
3. Click **Sync** and wait for completion
4. Test with these queries:
   - *"What is the minimum rental yield requirement?"*
   - *"What areas does Sokad target for property investment?"*
   - *"What is the maximum property price?"*

---

### Step 7 — Update the UI with your API URL

Open `ui/index.html` and find:

```javascript
const API = 'https://YOUR_API_GATEWAY_URL';
```

Replace with the `api_gateway_endpoint` value from Terraform output.

---

### Step 8 — Deploy the UI to Amplify

```bash
cd ui
zip -j ui.zip index.html
```

Go to **AWS Amplify → Apps → sokad-property-ai** in the console and upload `ui.zip` via manual deployment.

---

### Step 9 — Test end to end

1. Open the Amplify URL
2. Upload a property PDF (valuation report or survey)
3. Click **Run Investment Analysis**
4. Watch the 4-step progress indicator
5. Download the generated PDF report

---

## How It Works

1. Agent uploads property PDF via the Amplify UI
2. UI calls `/upload-url` to get a presigned S3 URL
3. PDF is uploaded directly to S3 `uploads/` folder
4. S3 event trigger fires `sokad-analyse-property` Lambda automatically
5. Lambda calls Amazon Textract to read and extract all text from the PDF
6. Lambda queries the Knowledge Base for Sokad's market data and criteria
7. Lambda calls Claude Sonnet with extracted property data + market context
8. Claude generates a complete structured investment report
9. fpdf2 builds a branded PDF with Sokad header and section formatting
10. PDF saved to S3 `reports/` folder
11. UI polls `/report-status` every 5 seconds until report is ready
12. Agent downloads the completed PDF report

---

## Report Sections Generated

| Section | Contents |
|---|---|
| Property Summary | Address, type, tenure, price, EPC, flood risk |
| ROI Projection | Monthly/annual rent, gross yield, costs, net yield |
| Sokad Criteria Check | PASS/FAIL for yield, price, location, bedrooms, EPC, flood risk |
| Risk Flags | Items needing attention before proceeding |
| Market Context | Area comparison, comparable sales, rental demand |
| Verdict | MEETS or DOES NOT MEET Sokad criteria |
| Client Email Draft | Professional 3-paragraph email to the client |

---

## Sokad Sourcing Criteria

| Criterion | Requirement |
|---|---|
| Gross Rental Yield | Minimum 6% (7%+ preferred) |
| Maximum Price | Under £250,000 (sub £180k preferred) |
| Location | Manchester, Leeds, Birmingham, Sheffield |
| Bedrooms | Minimum 2 (3-bed preferred) |
| EPC Rating | Minimum D |
| Flood Risk | Low or Very Low only |

---

## Estimated AWS Costs

| Service | Estimated Monthly Cost |
|---|---|
| Amazon Textract | ~$0.02 per report |
| Claude Sonnet 4.6 | ~$0.10-0.20 per report |
| Bedrock Knowledge Base | ~$0.002 per report |
| OpenSearch Serverless | ~$5-10/month |
| AWS Lambda | Negligible |
| Amazon S3 | Negligible |
| **Cost per report** | **~$0.12-0.25 USD** |

---

## Destroying Resources

```bash
# Empty the S3 bucket first
aws s3 rm s3://sokad-property-ai --recursive

# Then destroy all Terraform resources
cd terraform
terraform destroy
```

---

## Built With

- [Amazon Bedrock](https://aws.amazon.com/bedrock/) — Claude Sonnet 4.6 and Knowledge Bases
- [Amazon Textract](https://aws.amazon.com/textract/) — Document text extraction
- [AWS Lambda](https://aws.amazon.com/lambda/) — Serverless compute
- [Amazon API Gateway](https://aws.amazon.com/api-gateway/) — HTTP API
- [Amazon S3](https://aws.amazon.com/s3/) — Object storage
- [AWS Amplify](https://aws.amazon.com/amplify/) — Web hosting
- [Terraform](https://www.terraform.io/) — Infrastructure as Code
- [fpdf2](https://py-pdf.github.io/fpdf2/) — PDF generation

---

## Author

Built by **Digitspots Solutions Ltd** as part of the AWS AI Competency Program.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
