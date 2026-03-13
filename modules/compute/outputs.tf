output "api_endpoint" {
  description = "API Gateway invoke URL for this region"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.this.id
}

output "greeter_function_name" {
  description = "Greeter Lambda function name"
  value       = aws_lambda_function.greeter.function_name
}

output "dispatcher_function_name" {
  description = "Dispatcher Lambda function name"
  value       = aws_lambda_function.dispatcher.function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB GreetingLogs table name"
  value       = aws_dynamodb_table.greeting_logs.name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}
