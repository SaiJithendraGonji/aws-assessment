import json
import os
import boto3


def handler(event, context):
    region = os.environ["AWS_REGION"]
    cluster_arn = os.environ["ECS_CLUSTER_ARN"]
    task_definition = os.environ["ECS_TASK_DEFINITION"]
    subnet_ids = os.environ["ECS_SUBNET_IDS"].split(",")
    security_group_id = os.environ["ECS_SECURITY_GROUP_ID"]

    ecs = boto3.client("ecs", region_name=region)

    response = ecs.run_task(
        cluster=cluster_arn,
        taskDefinition=task_definition,
        launchType="FARGATE",
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": subnet_ids,
                "securityGroups": [security_group_id],
                # Public IP required - public subnet, no NAT Gateway
                "assignPublicIp": "ENABLED",
            }
        },
    )

    task_arns = [t["taskArn"] for t in response.get("tasks", [])]
    failures = response.get("failures", [])

    if failures:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "ECS RunTask returned failures",
                "region": region,
                "failures": failures,
            }),
        }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": "Fargate task dispatched successfully",
            "region": region,
            "task_arns": task_arns,
        }),
    }
