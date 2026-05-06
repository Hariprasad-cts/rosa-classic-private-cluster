# ==============================================================================
# modules/dns/main.tf
#
# Two things happen here:
#
#  1. rhcs_dns_domain  -- registers gilead.com with Red Hat OCM so ROSA knows
#                         which base domain to use for this cluster's API and
#                         console URLs.  This is the Terraform equivalent of:
#                           rosa create dns-domain --domain gilead.com
#
#  2. aws_route53_zone -- creates (or looks up) the Route53 public hosted zone.
#                         ROSA writes its DNS records (api.*, *.apps.*) here
#                         after the cluster is ready.
#
# After first apply:
#   terraform output route53_ns_records
#   -> Add the 4 NS records at your domain registrar for gilead.com.
#   -> DNS propagation can take minutes to 48 hours.
# ==============================================================================

# Register the custom domain with Red Hat OCM.
# This tells ROSA: "use gilead.com as the base domain for this cluster."
# Equivalent to: rosa create dns-domain --domain <base_domain>
# Safe to apply multiple times -- OCM is idempotent for existing domains.
resource "rhcs_dns_domain" "this" {
  count = var.create_hosted_zone ? 1 : 0
  id    = var.base_domain
}

# Create a new Route53 public hosted zone (new AWS account)
resource "aws_route53_zone" "this" {
  count   = var.create_hosted_zone ? 1 : 0
  name    = var.base_domain
  comment = "Managed by Terraform -- ROSA cluster ${var.cluster_name}"

  tags = merge(var.tags, {
    Name = var.base_domain
  })

  depends_on = [rhcs_dns_domain.this]
}

# Look up an existing hosted zone (when create_hosted_zone = false)
data "aws_route53_zone" "existing" {
  count        = var.create_hosted_zone ? 0 : 1
  zone_id      = var.hosted_zone_id
  private_zone = false
}

locals {
  zone_id    = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  ns_records = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}
