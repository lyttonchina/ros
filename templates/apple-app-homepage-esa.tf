locals {
  site_id           = 156759048689904
  record_name       = "www"
  accelerate_domain = "www.apple-app.cn"
  bucket_name       = "apple-app-homepage-gz"
  oss_region        = "cn-guangzhou"  # 广州区域（与 Bucket 实际位置一致）
  oss_endpoint      = "${local.bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  # 静态网站托管：启用 website 配置后，使用标准 Endpoint 即可自动返回 HTML
  # 不需要特殊的 oss-website 域名，标准 Endpoint 已支持静态网站托管
  oss_web_endpoint  = local.oss_endpoint
  cert_domain       = "*.apple-app.cn"
}

# 创建 OSS 存储桶
data "alicloud_regions" "current" {
  current = true
}

resource "alicloud_oss_bucket" "homepage" {
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

  tags = {
    env     = "homepage"
    project = "apple-app"
  }
}

# DNS 加速记录：创建 CNAME 记录并开启代理加速，指向 OSS
resource "alicloud_esa_record" "homepage" {
  record_name = local.accelerate_domain
  record_type = "CNAME"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "web"
  ttl         = 600

  data {
    value = local.oss_endpoint
  }

  depends_on = [alicloud_oss_bucket.homepage]
}

# 免费证书：申请免费边缘证书（如果站点已有泛域名证书，会自动复用）
resource "alicloud_esa_certificate" "homepage" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.cert_domain
}

# 回源协议和端口：配置回源协议 HTTP 和端口 80（OSS 默认端口）
# 使用精确匹配条件，只匹配 www.apple-app.cn 域名，避免与 API 的默认路由冲突
# 使用标准 OSS Endpoint，Bucket 已启用静态网站托管，会自动返回 HTML 内容
resource "alicloud_esa_origin_rule" "homepage" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.accelerate_domain
  origin_host      = local.oss_web_endpoint  # 使用标准 OSS Endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.accelerate_domain}\")"
  rule_name        = "homepage-route"

  depends_on = [alicloud_esa_record.homepage]
}

# 注意：WAF Ruleset 已由 apple-api-esa-prod.tf 创建，此处复用
# 如需为官网添加独立的速率限制规则，请在阿里云 ESA 控制台手动配置
# 或在 apple-api-esa-prod.tf 中添加新的 waf_rule 资源
