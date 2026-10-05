import boto3
import json
import re
import os

s3     = boto3.client('s3', region_name='us-west-2')
BUCKET = os.environ.get('BUCKET', 'sokad-property-ai')

def lambda_handler(event, context):
    params = event.get('queryStringParameters', {}) or {}
    action = params.get('action', '')

    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'GET, OPTIONS'
    }

    # ── GET PRESIGNED UPLOAD URL ──────────────────────────────────────────────
    if action == 'upload' or event.get('rawPath', '').endswith('upload-url'):
        filename   = params.get('filename', 'property.pdf')
        raw_id     = filename.replace('.pdf', '')
        property_id= re.sub(r'-+', '-', re.sub(r'[^a-zA-Z0-9-]', '-', raw_id)).strip('-')
        upload_key = f'uploads/{property_id}.pdf'

        url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET,
                'Key': upload_key,
                'ContentType': 'application/pdf'
            },
            ExpiresIn=300
        )
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'upload_url': url,
                'property_id': property_id
            })
        }

    # ── CHECK REPORT STATUS ───────────────────────────────────────────────────
    property_id = params.get('property_id', '')
    if not property_id:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'property_id is required'})
        }

    report_key = f'reports/{property_id}-sokad-report.pdf'

    try:
        s3.head_object(Bucket=BUCKET, Key=report_key)

        download_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': BUCKET, 'Key': report_key},
            ExpiresIn=3600
        )
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'ready': True,
                'url': download_url,
                'report_key': report_key
            })
        }

    except Exception:
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'ready': False,
                'message': 'Report is still being generated...'
            })
        }
