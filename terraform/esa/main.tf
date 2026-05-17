locals {
  site_id          = "156759048689904"
  record_name      = "apple-api-esa-prod"
  accelerate_domain = "apple-api-esa-prod.apple-app.cn"
  nlb_dns_name     = "nlb-eawmxizy6mlwetlt1q.us-east-1.nlb.aliyuncsslbintl.com"
  stack_name       = "stack_esa_prod"
  cert_domain      = "*.apple-app.cn"
  name_prefix      = local.stack_name != "" ? local.stack_name : local.record_name
}

resource "alicloud_esa_origin_pool" "this" {
  origin_pool_name = "${local.name_prefix}_origin_pool"
  site_id          = local.site_id
  enabled          = "true"

  origins {
    type    = "ip_domain"
    name    = "nlb-origin"
    address = local.nlb_dns_name
    weight  = "100"
    enabled = "true"
    header  = "{\"Host\":[\"${local.nlb_dns_name}\"]}"
  }
}

resource "alicloud_esa_origin_rule" "this" {
  site_id           = local.site_id
  origin_scheme     = "http"
  origin_http_port = "8080"
  origin_https_port = "443"
  origin_host       = local.accelerate_domain
  origin_sni        = local.accelerate_domain
  dns_record        = local.record_name
  rule_enable       = "on"
  rule              = "true"
  rule_name         = "default-route"
  range             = "off"

  depends_on = [alicloud_esa_origin_pool.this]
}

resource "alicloud_esa_record" "this" {
  record_name = local.record_name
  record_type = "CNAME"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "api"
  source_type = "LB"
  host_policy = "follow_hostname"
  ttl         = 1

  data {
    value = local.nlb_dns_name
  }

  depends_on = [alicloud_esa_origin_pool.this]
}

resource "alicloud_esa_certificate" "this" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.cert_domain

  depends_on = [alicloud_esa_record.this]
}
