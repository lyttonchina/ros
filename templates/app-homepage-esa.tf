variable "site_id" {
  description = "ESA Site ID"
  type        = string
}

variable "bucket_name" {
  description = "OSS Bucket name"
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
  site_id      = var.site_id
  bucket_name  = var.bucket_name
  oss_region   = var.oss_region
  oss_endpoint = "${local.bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  # 静态网站托管：启用 website 配置后，使用标准 Endpoint 即可自动返回 HTML
  oss_web_endpoint = local.oss_endpoint
}

# 创建 OSS 存储桶（两个 App 共用同一 Bucket，不同子目录隔离）
data "alicloud_regions" "current" {
  current = true
}

resource "alicloud_oss_bucket" "app" {
  bucket        = local.bucket_name
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

  tags = var.tags
}

# ============================================================
# App 1: taim
# ============================================================

# DNS 加速记录：taim.apple-app.cn
resource "alicloud_esa_record" "taim" {
  record_name    = "taim.apple-app.cn"
  record_type    = "CNAME"
  site_id        = local.site_id
  proxied        = true
  biz_name       = "web"
  ttl            = 600
  source_type    = "OSS"  # 选择 OSS 源站类型，享受回源流量优惠

  data {
    value = local.oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.app]
}

# 免费证书：taim.apple-app.cn
resource "alicloud_esa_certificate" "taim" {
  site_id      = local.site_id
  created_type = "free"
  domains      = "taim.apple-app.cn"
}

# 回源规则：taim.apple-app.cn → OSS
resource "alicloud_esa_origin_rule" "taim" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = "taim.apple-app.cn"
  origin_host      = local.oss_web_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"taim.apple-app.cn\")"
  rule_name        = "taim-route"

  depends_on = [alicloud_esa_record.taim]
}

# URL 重写规则：taim.apple-app.cn 根路径 → /taim/index.html
resource "alicloud_esa_rewrite_url_rule" "taim_root" {
  site_id         = local.site_id
  rule_name       = "taim-root-rewrite"
  rule            = "(http.host eq \"taim.apple-app.cn\" and http.request.uri.path eq \"/\")"
  rule_enable     = "on"
  rewrite_uri_type = "static"
  uri             = "/taim/index.html"

  depends_on = [alicloud_esa_origin_rule.taim]
}

# URL 重写规则：taim.apple-app.cn 其他路径 → 添加 taim/ 前缀回源
resource "alicloud_esa_rewrite_url_rule" "taim" {
  site_id         = local.site_id
  rule_name       = "taim-rewrite"
  rule            = "(http.host eq \"taim.apple-app.cn\" and http.request.uri.path ne \"/\")"
  rule_enable     = "on"
  rewrite_uri_type = "dynamic"
  uri             = "concat(\"/taim\", http.request.uri.path)"

  depends_on = [alicloud_esa_rewrite_url_rule.taim_root]
}

# ============================================================
# App 2: tunneling
# ============================================================

# DNS 加速记录：tunneling.apple-app.cn
resource "alicloud_esa_record" "tunneling" {
  record_name    = "tunneling.apple-app.cn"
  record_type    = "CNAME"
  site_id        = local.site_id
  proxied        = true
  biz_name       = "web"
  ttl            = 600
  source_type    = "OSS"  # 选择 OSS 源站类型，享受回源流量优惠

  data {
    value = local.oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.app]
}

# 免费证书：tunneling.apple-app.cn
resource "alicloud_esa_certificate" "tunneling" {
  site_id      = local.site_id
  created_type = "free"
  domains      = "tunneling.apple-app.cn"
}

# 回源规则：tunneling.apple-app.cn → OSS
resource "alicloud_esa_origin_rule" "tunneling" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = "tunneling.apple-app.cn"
  origin_host      = local.oss_web_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"tunneling.apple-app.cn\")"
  rule_name        = "tunneling-route"

  depends_on = [alicloud_esa_record.tunneling]
}

# URL 重写规则：tunneling.apple-app.cn 根路径 → /tunneling/index.html
resource "alicloud_esa_rewrite_url_rule" "tunneling_root" {
  site_id         = local.site_id
  rule_name       = "tunneling-root-rewrite"
  rule            = "(http.host eq \"tunneling.apple-app.cn\" and http.request.uri.path eq \"/\")"
  rule_enable     = "on"
  rewrite_uri_type = "static"
  uri             = "/tunneling/index.html"

  depends_on = [alicloud_esa_origin_rule.tunneling]
}

# URL 重写规则：tunneling.apple-app.cn 其他路径 → 添加 tunneling/ 前缀回源
resource "alicloud_esa_rewrite_url_rule" "tunneling" {
  site_id         = local.site_id
  rule_name       = "tunneling-rewrite"
  rule            = "(http.host eq \"tunneling.apple-app.cn\" and http.request.uri.path ne \"/\")"
  rule_enable     = "on"
  rewrite_uri_type = "dynamic"
  uri             = "concat(\"/tunneling\", http.request.uri.path)"

  depends_on = [alicloud_esa_rewrite_url_rule.tunneling_root]
}

# 注意：WAF Ruleset 已由 apple-api-esa-prod.tf 创建，此处复用
