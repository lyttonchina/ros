variable "site_id" {
  type        = number
  description = "ESA 站点的 SiteId，可在 ESA 控制台 → 站点管理 → 站点信息 中查看"
}

variable "cert_domain" {
  type        = string
  description = "要申请的免费证书域名，支持通配符（如 *.apple-app.cn）"
  default     = "*.apple-app.cn"
}

variable "accelerate_domain" {
  type        = string
  description = "完整的加速域名（如 api-prod.apple-app.cn），ESA 将此值作为回源 Host 头发送"
}

variable "nlb_dns_name" {
  type        = string
  description = "NLB 的公网 DNS 名称（来自 apple-api-esa-prod 栈的输出 NlbDNSName，如 xxx.alb.us-east-1.aliyuncs.com）"
}

variable "record_name" {
  type        = string
  description = "ESA Record 记录名（即加速域名的前缀，如 api-prod，与 AccelerateDomain 前缀保持一致）"
}

variable "stack_name" {
  type        = string
  description = "用于命名资源的前缀，默认为 record_name"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "标签"
  default     = {}
}
