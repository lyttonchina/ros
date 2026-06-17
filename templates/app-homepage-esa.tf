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
# App 1: taim - 独立 Bucket
# ============================================================

locals {
  taim_bucket_name   = "taim-homepage-gz"
  taim_oss_endpoint  = "${local.taim_bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  taim_accelerate_domain = "taim.apple-app.cn"
}

# 创建 taim 应用的 OSS 存储桶
resource "alicloud_oss_bucket" "taim" {
  bucket        = local.taim_bucket_name
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

  tags = merge(var.tags, { app = "taim" })
}

# DNS 加速记录：taim.apple-app.cn
resource "alicloud_esa_record" "taim" {
  record_name    = local.taim_accelerate_domain
  record_type    = "CNAME"
  site_id        = local.site_id
  proxied        = true
  biz_name       = "web"
  ttl            = 600
  source_type    = "OSS"  # 选择 OSS 源站类型，享受回源流量优惠

  data {
    value = local.taim_oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.taim]
}

# 免费证书：taim.apple-app.cn
resource "alicloud_esa_certificate" "taim" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.taim_accelerate_domain
}

# 回源规则：taim.apple-app.cn → OSS
resource "alicloud_esa_origin_rule" "taim" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.taim_accelerate_domain
  origin_host      = local.taim_oss_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.taim_accelerate_domain}\")"
  rule_name        = "taim-route"

  depends_on = [alicloud_esa_record.taim]
}

# ============================================================
# App 2: tunneling - 独立 Bucket
# ============================================================

locals {
  tunneling_bucket_name   = "tunneling-homepage-gz"
  tunneling_oss_endpoint  = "${local.tunneling_bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  tunneling_accelerate_domain = "tunneling.apple-app.cn"
}

# 创建 tunneling 应用的 OSS 存储桶
resource "alicloud_oss_bucket" "tunneling" {
  bucket        = local.tunneling_bucket_name
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

  tags = merge(var.tags, { app = "tunneling" })
}

# DNS 加速记录：tunneling.apple-app.cn
resource "alicloud_esa_record" "tunneling" {
  record_name    = local.tunneling_accelerate_domain
  record_type    = "CNAME"
  site_id        = local.site_id
  proxied        = true
  biz_name       = "web"
  ttl            = 600
  source_type    = "OSS"  # 选择 OSS 源站类型，享受回源流量优惠

  data {
    value = local.tunneling_oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.tunneling]
}

# 免费证书：tunneling.apple-app.cn
resource "alicloud_esa_certificate" "tunneling" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.tunneling_accelerate_domain
}

# 回源规则：tunneling.apple-app.cn → OSS
resource "alicloud_esa_origin_rule" "tunneling" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.tunneling_accelerate_domain
  origin_host      = local.tunneling_oss_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.tunneling_accelerate_domain}\")"
  rule_name        = "tunneling-route"

  depends_on = [alicloud_esa_record.tunneling]
}

# ============================================================
# App 3: awakemac - 独立 Bucket
# ============================================================

locals {
  awakemac_bucket_name   = "awakemac-homepage-gz"
  awakemac_oss_endpoint  = "${local.awakemac_bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  awakemac_accelerate_domain = "awakemac.apple-app.cn"
}

# 创建 awakemac 应用的 OSS 存储桶
resource "alicloud_oss_bucket" "awakemac" {
  bucket        = local.awakemac_bucket_name
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

  tags = merge(var.tags, { app = "awakemac" })
}

# DNS 加速记录：awakemac.apple-app.cn
resource "alicloud_esa_record" "awakemac" {
  record_name    = local.awakemac_accelerate_domain
  record_type    = "CNAME"
  site_id        = local.site_id
  proxied        = true
  biz_name       = "web"
  ttl            = 600
  source_type    = "OSS"  # 选择 OSS 源站类型，享受回源流量优惠

  data {
    value = local.awakemac_oss_endpoint
  }

  auth_conf {
    auth_type = "public"
  }

  depends_on = [alicloud_oss_bucket.awakemac]
}

# 免费证书：awakemac.apple-app.cn
resource "alicloud_esa_certificate" "awakemac" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.awakemac_accelerate_domain
}

# 回源规则：awakemac.apple-app.cn → OSS
resource "alicloud_esa_origin_rule" "awakemac" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.awakemac_accelerate_domain
  origin_host      = local.awakemac_oss_endpoint
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.awakemac_accelerate_domain}\")"
  rule_name        = "awakemac-route"

  depends_on = [alicloud_esa_record.awakemac]
}

# 注意：WAF Ruleset 已由 apple-api-esa-prod.tf 创建，此处复用
