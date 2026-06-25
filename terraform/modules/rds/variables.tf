variable "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  type        = string
}

variable "db_subnet_ids" {
  description = "List of database subnet IDs used by RDS."
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID for RDS."
  type        = string
}

variable "db_identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
}

variable "db_username" {
  description = "Master username for PostgreSQL."
  type        = string
}

variable "db_password" {
  description = "Master password for PostgreSQL."
  type        = string
  sensitive   = true
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated database storage in GB."
  type        = number
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment."
  type        = bool
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot when deleting."
  type        = bool
}

variable "tags" {
  description = "Common tags applied to RDS resources."
  type        = map(string)
  default     = {}
}