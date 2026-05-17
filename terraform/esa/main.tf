locals {
  site_id           = 156759048689904
  record_name       = "apple-api-esa-prod"
  accelerate_domain = "apple-api-esa-prod.apple-app.cn"
  nlb_dns_name      = "nlb-fgk9kda9b1ea1m6ksu.us-east-1.nlb.aliyuncsslbintl.com"
  cert_domain       = "*.apple-app.cn"
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
resource "alicloud_esa_origin_rule" "this" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = "8080"
  dns_record       = local.record_name
  rule_enable      = "on"
  rule             = "true"
  rule_name        = "default-route"
}

# 免费证书：对应截图3和4 - 申请免费边缘证书
resource "alicloud_esa_certificate" "this" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.cert_domain
}
