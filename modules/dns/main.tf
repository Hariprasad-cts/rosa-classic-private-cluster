# ==============================================================================
# modules/dns/main.tf
#
# Route 53 hosted zone for the custom domain (gilead.com).
#
# New AWS account (create_hosted_zone = true):
#   1. Terraform creates the public hosted zone
#   2. After apply: terraform output route53_ns_records
#   3. Add those 4 NS records at your domain registrar
#   4. Wait for DNS propagation (minutes to 48 hrs)
#   5. ROSA then auto-creates DNS records inside this zone:
#        api.mas-dev-rosa.gilead.com       -- internal API NLB
#        *.apps.mas-dev-rosa.gilead.com    -- internal Ingress NLB
#
# Existing zone (create_hosted_zone = false):
#   Set create_hosted_zone = false and hosted_zone_id = <your zone ID>
# ==============================================================================

resource "aws_route53_zone" "this" {
  count   = var.create_hosted_zone ? 1 : 0
  name    = var.base_domain
  comment = "Managed by Terraform -- ROSA cluster ${var.cluster_name}"

  tags = merge(var.tags, {
    Name = var.base_domain
  })
}

data "aws_route53_zone" "existing" {
  count        = var.create_hosted_zone ? 0 : 1
  zone_id      = var.hosted_zone_id
  private_zone = false
}

locals {
  zone_id    = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  ns_records = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}
