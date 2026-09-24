variable "db_password" {
  description = "Master password for the Sentinel RDS instance"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address subscribed to Critical-vulnerability SNS alerts"
  type        = string
}