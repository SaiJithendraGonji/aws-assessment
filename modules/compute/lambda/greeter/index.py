import json
import os
import uuid
import boto3
from datetime import datetime, timezone


def handler(event, context):
    region = os.environ["AWS_REGION"]
    table_name = os.environ["DYNAMODB_TABLE"]
    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]
    candidate_email = os.environ["CANDIDATE_EMAIL"]
    github_repo = os.environ["GITHUB_REPO"]

    dynamodb = boto3.resource("dynamodb", region_name=region)
    sns = boto3.client("sns", region_name="us-east-1")

    record_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    # Write greeting log to regional DynamoDB table
    table = dynamodb.Table(table_name)
    table.put_item(
        Item={
            "id": record_id,
            "timestamp": timestamp,
            "region": region,
            "source": "greeter-lambda",
            "request_id": context.aws_request_id,
        }
    )

    # Publish verification payload to Unleash Live SNS topic
    # SNS topic is in us-east-1 (cross-account) so we explicitly
    # target us-east-1 regardless of which region this Lambda runs in
    verification_payload = {
        "email": candidate_email,
        "source": "Lambda",
        "region": region,
        "repo": github_repo,
    }

    sns.publish(
        TopicArn=sns_topic_arn,
        Message=json.dumps(verification_payload),
        Subject=f"Candidate Verification - Lambda - {region}",
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({
            "message": "Greeting recorded successfully",
            "region": region,
            "record_id": record_id,
            "timestamp": timestamp,
        }),
    }
