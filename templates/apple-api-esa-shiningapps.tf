locals {
  site_id           = 157859014523116
  record_name       = "api-shiningapps-top"
  accelerate_domain = "api.shiningapps.top"
  nlb_dns_name      = "nlb-eawmxizy6mlwetlt1q.us-east-1.nlb.aliyuncsslbintl.com"
  cert_domain       = "*.shiningapps.top"
}

# DNS 加速记录：对应截图1 - 创建 CNAME 记录并开启代理加速
resource "alicloud_esa_record" "this" {
  record_name = local.accelerate_domain
  record_type = "CNAME"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "api"
  ttl         = 1

  data {
    value = local.nlb_dns_name
  }
}

# 回源协议和端口：对应截图2 - 配置回源协议 HTTP 和端口 8080
# 使用精确匹配条件，只匹配 API 域名，避免拦截官网等其他域名的请求
resource "alicloud_esa_origin_rule" "this" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "8080"
  dns_record       = local.accelerate_domain
  origin_host      = local.accelerate_domain
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.accelerate_domain}\")"
  rule_name        = "default-route"
}

# 免费证书：对应截图3和4 - 申请免费边缘证书
resource "alicloud_esa_certificate" "this" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.cert_domain
}

# WAF Ruleset:定义一个 http_ratelimit 阶段的规则集(用于频率控制)
resource "alicloud_esa_waf_ruleset" "login_rate_limit" {
  site_id      = local.site_id
  phase        = "http_ratelimit"
  site_version = "0"
}

# 登录接口 Rate Limiting 规则:
#   - 按 IP 维度统计,60 秒内超过 100 次请求则拦截(自动返回 429)
#   - 注意:由于套餐限制,此规则对指定域名的所有请求生效
resource "alicloud_esa_waf_rule" "login_rate_limit" {
  ruleset_id = alicloud_esa_waf_ruleset.login_rate_limit.ruleset_id
  phase      = "http_ratelimit"
  site_id    = local.site_id

  config {
    status = "on"
    # 匹配加速域名(http_ratelimit 阶段 expression 仅支持 http.host 等少数字段)
    expression = "(http.host eq \"${local.accelerate_domain}\")"
    name       = "domain-rate-limit"
    action     = "deny"

    # 频率限制配置
    rate_limit {
      on_hit = true
      
      # 统计维度:按客户端 IP
      characteristics {
        logic = "or"
        criteria {
          match_type = "ip.src"
        }
      }

      # 统计时间窗口:10 秒(免费版/基础版仅支持10秒)
      interval = 10

      # 阈值:10 秒内最多 20 次请求(相当于每分钟120次,避免误伤正常用户)
      threshold {
        request = 20
      }

      # 触发后的 TTL(封禁 10 秒,与统计窗口一致)
      ttl = 10
    }
  }
}
