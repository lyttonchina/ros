variable "site_id" {
  description = "ESA Site ID"
  type        = string
}

variable "oss_region" {
  description = "OSS Region"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

locals {
  site_id    = var.site_id
  oss_region = var.oss_region
}

# ============================================================
# App: lockwake - 独立 Bucket
# ============================================================

locals {
  lockwake_bucket_name   = "lockwake-app-homepage"
  lockwake_oss_endpoint  = "${local.lockwake_bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  lockwake_accelerate_domain = "lockwake.shiningapps.top"
}

locals {
  homepage_cache_rule_hosts = "(http.host eq \"${local.lockwake_accelerate_domain}\")"
}

# 创建 lockwake 应用的 OSS 存储桶
resource "alicloud_oss_bucket" "lockwake" {
  bucket        = local.lockwake_bucket_name
  acl           = "public-read"  # 公共读权限，允许匿名访问静态文件
  force_destroy = false

  # 网站托管配置：支持 SPA 路由
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  # 版本控制（可选）
  versioning {
    status = "Suspended"
  }

  # 冗余类型：LRS（本地冗余存储）
  redundancy_type = "LRS"

  # 存储类型：Standard（标准存储）
  storage_class = "Standard"

  tags = merge(var.tags, { app = "lockwake" })
}

# DNS 加速记录：lockwake.shiningapps.top
resource "alicloud_esa_record" "lockwake" {
  record_name    = local.lockwake_accelerate_domain
  record_type    = "CNAME"
  site_id        = local.site_id
  proxied        = true
  biz_name       = "web"
  ttl            = 600
  source_type    = "OSS"  # 选择 OSS 源站类型，享受回源流量优惠

  data {
    value = local.lockwake_oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.lockwake]
}

# 免费证书：lockwake.shiningapps.top
resource "alicloud_esa_certificate" "lockwake" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.lockwake_accelerate_domain
}

# 回源规则：lockwake.shiningapps.top → OSS
resource "alicloud_esa_origin_rule" "lockwake" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.lockwake_accelerate_domain
  origin_host      = local.lockwake_oss_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.lockwake_accelerate_domain}\")"
  rule_name        = "lockwake-route"

  depends_on = [alicloud_esa_record.lockwake]
}

# 静态主页缓存：避免 HTML 被 ESA 判为 DYNAMIC 后每次跨区回源 OSS。
resource "alicloud_esa_cache_rule" "homepage_static" {
  site_id     = local.site_id
  rule_name   = "homepage-static-cache"
  rule_enable = "on"
  rule        = "(${local.homepage_cache_rule_hosts})"

  bypass_cache                 = "cache_all"
  edge_cache_mode              = "override_origin"
  edge_cache_ttl               = "3600"
  browser_cache_mode           = "override_origin"
  browser_cache_ttl            = "300"
  query_string_mode            = "reserve_all"
  sort_query_string_for_cache  = "on"
  serve_stale                  = "on"

  depends_on = [
    alicloud_esa_origin_rule.lockwake,
  ]
}

# 注意：WAF Ruleset 已由 apple-api-esa-prod.tf 创建，此处复用
