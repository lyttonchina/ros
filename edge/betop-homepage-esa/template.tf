variable "site_id" {
  description = "ESA Site ID for betop.vip"
  type        = string
}

variable "oss_region" {
  description = "OSS Region"
  type        = string
  default     = "cn-guangzhou"
}

variable "bucket_name" {
  description = "OSS bucket for the betop.vip homepage"
  type        = string
  default     = "betop-vip-homepage"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

locals {
  site_id      = var.site_id
  bucket_name  = var.bucket_name
  oss_region   = var.oss_region
  oss_endpoint = "${local.bucket_name}.oss-${local.oss_region}.aliyuncs.com"

  homepage_domains = {
    apex = "betop.vip"
    www  = "www.betop.vip"
  }
}

resource "alicloud_oss_bucket" "homepage" {
  bucket        = local.bucket_name
  acl           = "public-read"
  force_destroy = false

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  versioning {
    status = "Suspended"
  }

  redundancy_type = "LRS"
  storage_class   = "Standard"

  tags = merge(var.tags, { site = "betop.vip" })
}

resource "alicloud_oss_bucket_object" "index" {
  bucket        = alicloud_oss_bucket.homepage.bucket
  key           = "index.html"
  content_type  = "text/html"
  cache_control = "no-cache"
  content       = <<-HTML
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="0; url=https://www.apple-app.cn/">
  <title>betop.vip</title>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #222; display: grid; min-height: 100vh; place-items: center; }
    main { text-align: center; line-height: 1.8; }
    a { color: #0b63ce; }
  </style>
</head>
<body>
  <main>
    <h1>betop.vip</h1>
    <p>正在打开主页...</p>
    <p><a href="https://www.apple-app.cn/">https://www.apple-app.cn/</a></p>
  </main>
</body>
</html>
HTML
}

resource "alicloud_esa_record" "homepage" {
  for_each    = local.homepage_domains
  record_name = each.value
  record_type = "CNAME"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "web"
  ttl         = 600
  source_type = "OSS"

  data {
    value = local.oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.homepage]
}

resource "alicloud_esa_certificate" "homepage" {
  for_each     = local.homepage_domains
  site_id      = local.site_id
  created_type = "free"
  domains      = each.value
}

resource "alicloud_esa_origin_rule" "homepage" {
  for_each         = local.homepage_domains
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = each.value
  origin_host      = local.oss_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"${each.value}\")"
  rule_name        = "betop-${each.key}-homepage-route"

  depends_on = [alicloud_esa_record.homepage]
}

resource "alicloud_esa_cache_rule" "homepage_static" {
  for_each    = local.homepage_domains
  site_id     = local.site_id
  rule_name   = "betop-${each.key}-homepage-static-cache"
  rule_enable = "on"
  rule        = "(http.host eq \"${each.value}\")"

  bypass_cache                = "cache_all"
  edge_cache_mode             = "override_origin"
  edge_cache_ttl              = "300"
  browser_cache_mode          = "override_origin"
  browser_cache_ttl           = "60"
  query_string_mode           = "reserve_all"
  sort_query_string_for_cache = "on"
  serve_stale                 = "on"

  depends_on = [alicloud_esa_origin_rule.homepage]
}
