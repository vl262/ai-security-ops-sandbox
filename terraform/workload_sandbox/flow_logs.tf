# VPC Flow Logs — diagnostický nástroj. Zachycuje syrová síťová data
# (zdrojová IP, port, akce ACCEPT/REJECT) nezávisle na tom, jestli
# GuardDuty daný provoz vyhodnotí jako finding. GuardDuty totiž
# generuje Recon:EC2/PortProbeUnprotectedPort jen pro provoz ze zdrojů
# na jeho vlastním threat intelligence listu — obyčejné oportunistické
# skenování z neznámé IP nemusí vygenerovat žádný finding, i když
# reálně dorazí. Flow Logs tohle potvrdí přímo.

resource "aws_cloudwatch_log_group" "honeypot_flow_logs" {
  name              = "/vpc/vl-honeypot-flow-logs"
  retention_in_days = 7 # krátká retence — diagnostický účel, ne dlouhodobý audit

  tags = {
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

# IAM role, kterou VPC Flow Logs služba používá k zápisu do CloudWatch Logs
resource "aws_iam_role" "flow_logs" {
  name = "vl-honeypot-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "vl-honeypot-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.honeypot_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "honeypot" {
  vpc_id               = aws_vpc.honeypot.id
  traffic_type          = "ALL" # ACCEPT i REJECT — zajímá nás obojí (i odmítnuté pokusy)
  log_destination_type = "cloud-watch-logs"
  log_destination       = aws_cloudwatch_log_group.honeypot_flow_logs.arn
  iam_role_arn           = aws_iam_role.flow_logs.arn

  tags = {
    Name    = "vl-honeypot-flow-log"
    Purpose = "honeypot"
    Owner   = var.owner_tag
  }
}
