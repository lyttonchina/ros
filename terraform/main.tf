locals {
  name_prefix = var.stack_name != "" ? var.stack_name : var.record_name
}

resource "alicloud_esa_origin_pool" "this" {
  origin_pool_name = "${local.name_prefix}_origin_pool"
  site_id          = var.site_id
  enabled          = "true"

  origins {
    type    = "ip_domain"
    name    = "nlb-origin"
    address = var.nlb_dns_name
    enabled = "true"
    header  = "{\"Host\":[\"${var.nlb_dns_name}\"]}"
    weight  = "100"
  }
}

resource "alicloud_esa_origin_rule" "this" {
  site_id           = var.site_id
  origin_scheme     = "http"
  origin_http_port  = "8080"
  origin_https_port = "443"
  origin_host       = var.accelerate_domain
  origin_sni       = var.accelerate_domain
  dns_record       = var.record_name
  rule_enable       = "on"
  rule              = "true"
  rule_name         = "default-route"
  range             = "off"

  depends_on = [alicloud_esa_origin_pool.this]
}

resource "alicloud_esa_record" "this" {
  record_name  = var.record_name
  record_type  = "CNAME"
  site_id      = var.site_id
  proxied      = true
  biz_name     = "api"
  source_type  = "LB"
  host_policy  = "follow_hostname"
  ttl          = 1

  data {
    value = var.nlb_dns_name
  }

  depends_on = [alicloud_esa_origin_pool.this]
}

resource "alicloud_esa_certificate" "this" {
  site_id      = var.site_id
  created_type = "free"
  domains      = var.accelerate_domain

  depends_on = [alicloud_esa_record.this]
}
