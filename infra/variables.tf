variable "db_password" {
  description = "Master password for the Sentinel RDS instance"
  type        = string
  sensitive   = true
}