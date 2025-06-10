variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "volume_size" {
  description = "Root block device's volume size"
  type        = number
  default     = 20
}

variable "allowed_cidr_blocks" {
  description = "List of CIDRs allowed to access SSH and ClickHouse"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}