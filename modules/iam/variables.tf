variable "cluster_name" {
  type        = string
  description = "ROSA cluster name — used in IAM resource names and trust conditions."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all IAM resources."
  default     = {}
}
