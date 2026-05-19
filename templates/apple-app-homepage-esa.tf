locals {
  site_id           = 156759048689904
  record_name       = "www"
  accelerate_domain = "www.apple-app.cn"
  bucket_name       = "apple-app-homepage-gz"
  oss_region        = "cn-hangzhou"
  oss_endpoint      = "${local.bucket_name}.oss-${local.oss_region}.aliyuncs.com"
  cert_domain       = "*.apple-app.cn"
}

# 创建 OSS 存储桶
data "alicloud_regions" "current" {
  current = true
}

resource "alicloud_oss_bucket" "homepage" {
  bucket        = local.bucket_name
  acl           = "public-read"
  force_destroy = false

  # 网站托管配置：支持 SPA 路由
  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  # 版本控制（可选）
  versioning {
    status = "Disabled"
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
  biz_name    = "homepage"
  ttl         = 600

  data {
    value = local.oss_endpoint
  }

  depends_on = [alicloud_oss_bucket.homepage]
}

# 回源协议和端口：配置回源协议 HTTP 和端口 80（OSS 默认端口）
resource "alicloud_esa_origin_rule" "homepage" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "80"
  dns_record       = local.accelerate_domain
  origin_host      = local.oss_endpoint
  rule_enable      = "on"
  rule             = "true"
  rule_name        = "homepage-route"
}

# WAF Ruleset: 定义一个 http_ratelimit 阶段的规则集（用于频率控制，防止恶意请求）
resource "alicloud_esa_waf_ruleset" "homepage_rate_limit" {
  site_id      = local.site_id
  phase        = "http_ratelimit"
  site_version = "0"
}

# 官网 Rate Limiting 规则：
#   - 按 IP 维度统计，10 秒内超过 50 次请求则拦截（自动返回 429）
#   - 保护官网免受恶意爬虫或 DDoS 攻击
resource "alicloud_esa_waf_rule" "homepage_rate_limit" {
  ruleset_id = alicloud_esa_waf_ruleset.homepage_rate_limit.ruleset_id
  phase      = "http_ratelimit"
  site_id    = local.site_id

  config {
    status = "on"
    # 匹配加速域名
    expression = "(http.host eq \"${local.accelerate_domain}\")"
    name       = "homepage-rate-limit"
    action     = "deny"

    # 频率限制配置
    rate_limit {
      on_hit = true
      
      # 统计维度：按客户端 IP
      characteristics {
        logic = "or"
        criteria {
          match_type = "ip.src"
        }
      }

      # 统计时间窗口：10 秒
      interval = 10

      # 阈值：10 秒内最多 50 次请求（相当于每分钟300次，适合官网浏览场景）
      threshold {
        request = 50
      }

      # 触发后的 TTL（封禁 10 秒，与统计窗口一致）
      ttl = 10
    }
  }
}
