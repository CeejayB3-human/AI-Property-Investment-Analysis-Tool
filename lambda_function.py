import boto3
import json
import io
import time
import re
import os
from fpdf import FPDF
from urllib.parse import unquote_plus

textract     = boto3.client('textract',             region_name='us-west-2')
bedrock_agent= boto3.client('bedrock-agent-runtime',region_name='us-west-2')
bedrock      = boto3.client('bedrock-runtime',      region_name='us-west-2')
s3           = boto3.client('s3',                   region_name='us-west-2')

KB_ID    = os.environ.get('KB_ID',    '9B2IANUVFA')
MODEL_ID = os.environ.get('MODEL_ID', 'arn:aws:bedrock:us-west-2:055370383525:inference-profile/global.anthropic.claude-sonnet-4-6')
BUCKET   = os.environ.get('BUCKET',   'sokad-property-ai')

SYSTEM_PROMPT = """You are a senior property investment analyst for Sokad Creations Limited,
a UK property investment firm.
You will be given extracted property document data and relevant UK market data from
Sokad's knowledge base.

Generate a complete investment report with these sections:

PROPERTY SUMMARY
Address, property type, tenure, asking price, EPC rating, flood risk

ROI PROJECTION
Monthly rent, annual rent, gross yield percentage, estimated costs, net income, net yield

SOKAD CRITERIA CHECK
Check each criterion and mark as PASS or FAIL
Minimum yield 6 percent, maximum price 250000, minimum 2 bedrooms, EPC minimum D,
flood risk low or very low only

RISK FLAGS
List any concerns or items that need attention

MARKET CONTEXT
How this area compares to Sokad target areas, comparable sales, rental demand

VERDICT
MEETS SOKAD CRITERIA or DOES NOT MEET SOKAD CRITERIA
One sentence explanation only

CLIENT EMAIL DRAFT
Write a professional warm email from the Sokad Creations team to the client
3 short paragraphs only
Be transparent about any risk flags
Do not invent numbers not in the data

Rules:
Be concise. Use only data provided. No markdown, no hashtags, no asterisks.
Plain text only. Write CAPITALISED TEXT for section headings."""


def clean_text(text):
    replacements = {
        '\u2019': "'", '\u2018': "'", '\u201c': '"', '\u201d': '"',
        '\u2013': '-', '\u2014': '-', '\u2022': '-',
        '\u00a3': 'GBP', '#': '', '*': '',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    if all(c in '-= \t' for c in text) and len(text.strip()) > 3:
        return ''
    text = text.encode('latin-1', 'replace').decode('latin-1')
    return text.strip()


SECTION_HEADERS = [
    'PROPERTY SUMMARY', 'ROI PROJECTION', 'SOKAD CRITERIA',
    'RISK FLAGS', 'MARKET CONTEXT', 'VERDICT', 'CLIENT EMAIL'
]

def is_section_header(text):
    upper = text.upper().strip()
    return any(upper.startswith(h) for h in SECTION_HEADERS)


def build_pdf(analysis_text, property_id):
    NAVY = (13, 43, 78)
    BLUE = (26, 90, 158)

    pdf = FPDF()
    pdf.set_margins(18, 18, 18)
    pdf.add_page()
    w = pdf.w - 36

    # Header
    pdf.set_fill_color(*NAVY)
    pdf.rect(0, 0, pdf.w, 36, 'F')
    pdf.set_text_color(255, 255, 255)
    pdf.set_font('Helvetica', 'B', 22)
    pdf.set_xy(18, 8)
    pdf.cell(w, 12, 'Sokad Creations Limited', ln=True, align='L')
    pdf.set_font('Helvetica', '', 10)
    pdf.set_xy(18, 22)
    pdf.cell(w, 8, 'Property Investment Analysis Report', ln=True, align='L')

    pdf.set_text_color(0, 0, 0)
    pdf.ln(14)

    for line in analysis_text.split('\n'):
        clean = clean_text(line)
        if not clean:
            pdf.ln(2)
            continue
        if is_section_header(clean):
            pdf.ln(4)
            pdf.set_fill_color(230, 238, 250)
            pdf.set_font('Helvetica', 'B', 10)
            pdf.set_text_color(*BLUE)
            pdf.cell(w, 8, '  ' + clean.upper(), ln=True, fill=True)
            pdf.set_text_color(0, 0, 0)
            pdf.ln(2)
            continue
        if clean.startswith('-'):
            pdf.set_font('Helvetica', '', 9.5)
            pdf.set_x(22)
            pdf.multi_cell(w - 4, 6, '- ' + clean.lstrip('-').strip())
            continue
        pdf.set_font('Helvetica', '', 9.5)
        pdf.set_x(18)
        pdf.multi_cell(w, 6, clean)

    # Footer
    pdf.set_y(-18)
    pdf.set_draw_color(*NAVY)
    pdf.line(18, pdf.get_y(), pdf.w - 18, pdf.get_y())
    pdf.set_font('Helvetica', 'I', 8)
    pdf.set_text_color(120, 120, 120)
    pdf.cell(w, 8, 'Sokad Creations Limited  |  Confidential Investment Report', align='C')

    buffer = io.BytesIO()
    pdf.output(buffer)
    buffer.seek(0)
    return buffer


def lambda_handler(event, context):
    bucket  = event['Records'][0]['s3']['bucket']['name']
    raw_key = event['Records'][0]['s3']['object']['key']
    key     = unquote_plus(raw_key)

    raw_id      = key.replace('uploads/', '').replace('.pdf', '')
    property_id = re.sub(r'-+', '-', re.sub(r'[^a-zA-Z0-9-]', '-', raw_id)).strip('-')

    print(f"Processing: {key}")
    print(f"Property ID: {property_id}")

    # Step 1 — Textract
    print("Starting Textract...")
    response = textract.start_document_analysis(
        DocumentLocation={'S3Object': {'Bucket': bucket, 'Name': key}},
        FeatureTypes=['FORMS', 'TABLES']
    )
    job_id = response['JobId']

    while True:
        result = textract.get_document_analysis(JobId=job_id)
        status = result['JobStatus']
        if status == 'SUCCEEDED':
            break
        elif status == 'FAILED':
            raise Exception('Textract job failed')
        time.sleep(3)

    extracted_text = []
    for block in result['Blocks']:
        if block['BlockType'] == 'LINE':
            extracted_text.append(block['Text'])

    property_text = '\n'.join(extracted_text)[:3000]
    print("Textract complete")

    # Step 2 — Knowledge Base
    print("Retrieving from Knowledge Base...")
    retrieval = bedrock_agent.retrieve(
        knowledgeBaseId=KB_ID,
        retrievalQuery={'text': property_text[:500]},
        retrievalConfiguration={'vectorSearchConfiguration': {'numberOfResults': 5}}
    )
    catalog_context = ''
    for r in retrieval.get('retrievalResults', []):
        content = r.get('content', {}).get('text', '')
        if content:
            catalog_context += content + '\n\n'
    print("Knowledge Base retrieval complete")

    # Step 3 — Claude
    print("Calling Claude...")
    claude_response = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps({
            'anthropic_version': 'bedrock-2023-05-31',
            'max_tokens': 2500,
            'system': SYSTEM_PROMPT,
            'messages': [{
                'role': 'user',
                'content': f"""Sokad market data and sourcing criteria:\n\n{catalog_context}
Property document data:\n\n{property_text}
Generate the complete Sokad investment report and client email draft. Be concise."""
            }]
        })
    )
    response_body = json.loads(claude_response['body'].read())
    analysis = response_body['content'][0]['text']
    print("Claude complete")

    # Step 4 — Build PDF
    print("Building PDF...")
    pdf_buffer = build_pdf(analysis, property_id)

    # Step 5 — Save to S3
    report_key = f'reports/{property_id}-sokad-report.pdf'
    s3.put_object(
        Bucket=BUCKET,
        Key=report_key,
        Body=pdf_buffer.read(),
        ContentType='application/pdf'
    )
    print(f"Report saved: {report_key}")

    return {
        'status': 'success',
        'property_id': property_id,
        'report_key': report_key
    }
