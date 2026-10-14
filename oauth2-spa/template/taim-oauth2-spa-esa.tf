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
# App: taim OAuth2 SPA
#
# 这个域名同时承载 Apple / Google / GitHub OAuth2 流程的：
#   1. /               入口 SPA 静态资源（index.html、JS、CSS）
#   2. /callback?…     接收 IdP 一次性 code/state 的回调路径
#   3. /.well-known/   OIDC discovery / JWKS metadata
#
# 与 app-homepage（公共主页模板）共用同一 site_id（157859014523116），
# 但本模板不并入 homepage_static cache rule：OAuth2 路径的
# `code` / `state` / `id_token` 必须禁止边缘缓存，故
# bypass_cache = "disable"（每次都回源 OSS） + 浏览器不缓存。
# 后续 google / github 接入复用同一域名，cache rule 不需调整。
# ============================================================

locals {
  taim_oauth2_spa_bucket_name       = "taim-oauth2-spa"
  taim_oauth2_spa_oss_endpoint      = "${local.taim_oauth2_spa_bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  taim_oauth2_spa_accelerate_domain = "taim-apple-sign.shiningapps.top"

  # 故意只列一个 host：后续 google / github 共用同一域名
  # （taim-apple-sign.shiningapps.top），因此 host 列表与 provider 无关。
  oauth2_spa_cache_rule_hosts = "(http.host eq \"${local.taim_oauth2_spa_accelerate_domain}\")"
}

# 创建 taim OAuth2 SPA 的 OSS 存储桶
resource "alicloud_oss_bucket" "taim_oauth2_spa" {
  bucket        = local.taim_oauth2_spa_bucket_name
  acl           = "public-read"  # 公共读；SPA 静态资源允许匿名拉取
  force_destroy = false

  # 网站托管配置：支持 SPA 路由，/callback 由后端重定向到 /index.html
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  versioning {
    status = "Suspended"
  }

  redundancy_type = "LRS"
  storage_class    = "Standard"

  tags = merge(var.tags, { app = "taim", role = "oauth2-spa" })
}

# DNS 加速记录：taim-apple-sign.shiningapps.top
resource "alicloud_esa_record" "taim_oauth2_spa" {
  record_name = local.taim_oauth2_spa_accelerate_domain
  record_type = "CNAME"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "web"
  ttl         = 600
  source_type = "OSS"

  data {
    value = local.taim_oauth2_spa_oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.taim_oauth2_spa]
}

# 免费证书：taim-apple-sign.shiningapps.top
resource "alicloud_esa_certificate" "taim_oauth2_spa" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.taim_oauth2_spa_accelerate_domain
}

# 回源规则：taim-apple-sign.shiningapps.top → OSS
resource "alicloud_esa_origin_rule" "taim_oauth2_spa" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.taim_oauth2_spa_accelerate_domain
  origin_host      = local.taim_oauth2_spa_oss_endpoint
  rule_enable      = "on"
  rule             = local.oauth2_spa_cache_rule_hosts
  rule_name        = "taim-oauth2-spa-route"

  depends_on = [alicloud_esa_record.taim_oauth2_spa]
}

# 严格全 bypass 缓存规则：
# - bypass_cache = "disable" → ESA 边缘节点不缓存任何内容，
#   防止 IdP 一次性 `code` / `state` / `id_token` 被边缘存下来。
# - browser_cache_ttl = 0 → 浏览器也不缓存，避免 `/callback?code=…`
#   命中历史响应。
# - serve_stale = "off"  → 回源失败时不要用陈旧响应（OAuth2 流程对一致性
#   高度敏感，宁可 502 让客户端重试）。
# 后续接入 google / github OAuth2 时，本规则不需变更 —— 三家共用同一 host
# 与同一 cache rule 即可。
resource "alicloud_esa_cache_rule" "taim_oauth2_spa_bypass" {
  site_id     = local.site_id
  rule_name   = "taim-oauth2-spa-bypass"
  rule_enable = "on"
  rule        = local.oauth2_spa_cache_rule_hosts

  bypass_cache        = "disable"
  browser_cache_mode  = "override_origin"
  browser_cache_ttl   = "0"
  serve_stale         = "off"
  query_string_mode   = "reserve_all"

  depends_on = [
    alicloud_esa_origin_rule.taim_oauth2_spa,
  ]
}

# 注意：WAF Ruleset 已由 apple-api-esa-prod.tf 创建，此处复用
