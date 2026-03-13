resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs-${var.region}"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "id"
  range_key    = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name   = "GreetingLogs-${var.region}"
    Region = var.region
  }
}
