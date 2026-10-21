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
# App: taim Apple OAuth2 SPA
#
# 当前仅服务 Apple Sign-In 流程：
#   1. /               入口 SPA 静态资源（index.html、JS、CSS）
#   2. /callback?…     接收 Apple 一次性 authorization_code / state 的回调
#   3. /.well-known/   OIDC discovery / JWKS metadata（未来如需）
#
# 与 app-homepage（公共主页模板）共用同一 site_id（157859014523116），
# 但本模板不并入 homepage_static cache rule：Apple OAuth2 路径的
# `code` / `state` / `id_token` 必须禁止边缘缓存，故
# bypass_cache = "bypass_all"（每次都回源 OSS） + 浏览器不缓存。
#
# 桶名固定 taim-apple-oauth2-spa：与加速域 taim-apple-sign.betop.vip
# 同属 Apple 身份场景；Google / GitHub 等其他 provider 将使用独立桶
# 与独立 host（本模板不为其预留位置）。
# ============================================================

locals {
  taim_oauth2_spa_bucket_name       = "taim-apple-oauth2-spa"
  taim_oauth2_spa_oss_endpoint      = "${local.taim_oauth2_spa_bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  taim_oauth2_spa_accelerate_domain = "taim-apple-sign.betop.vip"

  # host 列表仅包含当前 Apple OAuth2 域名；未来加入 Google / GitHub 时
  # 应当各自走独立 host 与独立 cache rule，不应把本 host 列表扩大。
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

# DNS 加速记录：taim-apple-sign.betop.vip
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

# 免费证书：taim-apple-sign.betop.vip
resource "alicloud_esa_certificate" "taim_oauth2_spa" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.taim_oauth2_spa_accelerate_domain
}

# 回源规则：taim-apple-sign.betop.vip → OSS
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
# - bypass_cache = "bypass_all" → ESA 边缘节点不缓存任何内容，
#   防止 IdP 一次性 `code` / `state` / `id_token` 被边缘存下来。
# - browser_cache_ttl = 0 → 浏览器也不缓存，避免 `/callback?code=…`
#   命中历史响应。
# - serve_stale = "off"  → 回源失败时不要用陈旧响应（OAuth2 流程对一致性
#   高度敏感，宁可 502 让客户端重试）。
# 后续如需接入 Google / GitHub 等其他 provider 的 OAuth2 流程，
# 应当各自建立独立 host、独立 cache rule，不应扩大本规则的 host 列表。
resource "alicloud_esa_cache_rule" "taim_oauth2_spa_bypass" {
  site_id     = local.site_id
  rule_name   = "taim-oauth2-spa-bypass"
  rule_enable = "on"
  rule        = local.oauth2_spa_cache_rule_hosts

  bypass_cache        = "bypass_all"
  browser_cache_mode  = "override_origin"
  browser_cache_ttl   = "0"
  serve_stale         = "off"
  query_string_mode   = "reserve_all"

  depends_on = [
    alicloud_esa_origin_rule.taim_oauth2_spa,
  ]
}

# 注意：WAF Ruleset 已由 apple-api-esa-prod.tf 创建，此处复用
