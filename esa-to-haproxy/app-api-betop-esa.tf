variable "esa_token_value" {
  description = "Shared secret injected by ESA on every back-to-origin request and verified by haproxy frontend esa-in. Source of truth is the deploy-time secret store (tfvars / TF_VAR_esa_token_value / env). Repo only carries the placeholder."
  type        = string
  sensitive   = true
  default     = "<YOUR_ESA_TOKEN>"
}

locals {
  site_id           = 165447474077904
  record_name       = "app-api"
  accelerate_domain = "app-api.betop.vip"
  # ESA → haproxy 直连（无 NLB），公网入口 IP 在 haproxy 宿主机上
  origin_ip         = "43.112.127.244"
  origin_port       = "8080"
  # 与 taim-doc/鉴权和用户数据加密/haproxy配置/haproxy.cfg frontend esa-in 校验的 header 对齐。
  # header 名称属链路协议契约，不走参数化；改它必须同步改 haproxy.cfg。
  esa_token_header  = "x-esa-token"
  esa_token_value   = var.esa_token_value
}

# DNS 加速记录：app-api.betop.vip 走 ESA 代理加速
resource "alicloud_esa_record" "app_api" {
  record_name = local.accelerate_domain
  record_type = "A/AAAA"
  site_id     = local.site_id
  proxied     = true
  biz_name    = "api"
  ttl         = 1

  data {
    # TODO(esa-to-haproxy): 现有样本里 data.value 都填域名（CNAME 目标），
    # 但本链路没有 NLB，回源目标是裸 IP 43.112.127.244。
    # 阿里云 ESA Terraform provider 在该资源下是否允许裸 IP、应改用哪个字段
    # （data.value / dns_record / 别的）需要 apply 前到 provider 文档/控制台确认。
    value = local.origin_ip
  }
}

# 回源协议和端口：http://43.112.127.244:8080，对应 haproxy frontend esa-in 监听端口
# 匹配条件只命中 app-api.betop.vip，避免与 betop.vip 主站 / www 子域的路由冲突
resource "alicloud_esa_origin_rule" "app_api" {
  site_id          = local.site_id
  origin_scheme    = "http"
  origin_http_port = local.origin_port
  dns_record       = local.accelerate_domain
  origin_host      = local.accelerate_domain
  rule_enable      = "on"
  rule             = "(http.host eq \"${local.accelerate_domain}\")"
  rule_name        = "app-api-betop-route"

  # TODO(esa-to-haproxy): haproxy frontend esa-in 强制要求 x-esa-token 必须存在且匹配，
  # 否则直接 deny。需要在 ESA 端给回源请求注入该 header（value = <YOUR_ESA_TOKEN>）。
  # 阿里云 ESA provider 是否有 alicloud_esa_header_rule / transform_rule 之类的资源、
  # 或者只能在 ESA 控制台手工配 Modify Origin Request Headers，需在 apply 前确认。
}

# 免费证书：为 app-api.betop.vip 申请单域名边缘证书
resource "alicloud_esa_certificate" "app_api" {
  site_id      = local.site_id
  created_type = "free"
  domains      = local.accelerate_domain
}
