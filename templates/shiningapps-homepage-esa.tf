variable "site_id" {
  description = "ESA Site ID for shiningapps.top"
  type        = string
}

variable "accelerate_domain" {
  description = "The public homepage domain served by ESA"
  type        = string
  default     = "www.shiningapps.top"
}

variable "origin_domain" {
  description = "Existing homepage domain used as origin"
  type        = string
  default     = "www.apple-app.cn"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

locals {
  site_id           = var.site_id
  accelerate_domain = var.accelerate_domain
  origin_domain     = var.origin_domain
}

# DNS 加速记录：www.shiningapps.top -> 现有 www.apple-app.cn 主页
resource "alicloud_esa_record" "homepage" {
  record_name = local.accelerate_domain
  record_type = "CNAME"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "web"
  ttl         = 600
  source_type = "Domain"
  host_policy = "follow_origin_domain"

  data {
    value = local.origin_domain
  }
}

# 免费证书：www.shiningapps.top
resource "alicloud_esa_certificate" "homepage" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.accelerate_domain
}

# 回源规则：www.shiningapps.top -> www.apple-app.cn
resource "alicloud_esa_origin_rule" "homepage" {
  site_id          = local.site_id
  origin_scheme    = "https"
  origin_https_port = "443"
  dns_record       = local.accelerate_domain
  origin_host      = local.origin_domain
  origin_sni       = local.origin_domain
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.accelerate_domain}\")"
  rule_name        = "shiningapps-homepage-route"

  depends_on = [alicloud_esa_record.homepage]
}

# 静态主页缓存：备案审核页无需每次回源到现有 www 站。
resource "alicloud_esa_cache_rule" "homepage_static" {
  site_id     = local.site_id
  rule_name   = "shiningapps-homepage-static-cache"
  rule_enable = "on"
  rule        = "(http.host eq \"${local.accelerate_domain}\")"

  bypass_cache                = "cache_all"
  edge_cache_mode             = "override_origin"
  edge_cache_ttl              = "3600"
  browser_cache_mode          = "override_origin"
  browser_cache_ttl           = "300"
  query_string_mode           = "reserve_all"
  sort_query_string_for_cache = "on"
  serve_stale                 = "on"

  depends_on = [alicloud_esa_origin_rule.homepage]
}
