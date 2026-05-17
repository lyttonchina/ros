{
  "ROSTemplateFormatVersion": "2015-09-01",
  "Transform": "Aliyun::Terraform-v1.5",
  "Workspace": {
    "versions.tf": "terraform {\n  required_version = \">= 1.3.0\"\n\n  required_providers {\n    alicloud = {\n      source  = \"aliyun/alicloud\"\n      version = \">= 1.210.0\"\n    }\n  }\n}\n\nprovider \"alicloud\" {\n}",
    "variables.tf": "variable \"site_id\" {\n  type        = string\n  description = \"ESA 站点的 SiteId，可在 ESA 控制台 → 站点管理 → 站点信息 中查看\"\n}\n\nvariable \"cert_domain\" {\n  type        = string\n  description = \"要申请的免费证书域名，支持通配符（如 *.apple-app.cn）\"\n  default     = \"*.apple-app.cn\"\n}\n\nvariable \"accelerate_domain\" {\n  type        = string\n  description = \"完整的加速域名（如 apple-api-esa-prod.apple-app.cn），用于 ESA 负载均衡器名称和回源 Host\"\n}\n\nvariable \"nlb_dns_name\" {\n  type        = string\n  description = \"NLB 的公网 DNS 名称（来自 apple-api-esa-prod 栈的输出 NlbDNSName）\"\n}\n\nvariable \"record_name\" {\n  type        = string\n  description = \"ESA Record 记录名（即加速域名前缀，如 apple-api-esa-prod）\"\n}\n\nvariable \"tags\" {\n  type        = map(string)\n  description = \"标签\"\n  default     = {}\n}",
    "main.tf": "# 源站池：指向 NLB\nresource \"alicloud_esa_origin_pool\" \"this\" {\n  origin_pool_name = \"${var.record_name}-origin-pool\"\n  site_id          = var.site_id\n  enabled          = true\n\n  origins {\n    type    = \"ip_domain\"\n    name    = \"nlb-origin\"\n    address = var.nlb_dns_name\n    weight  = 100\n    enabled = true\n  }\n}\n\n# ESA 负载均衡器：关联源站池\nresource \"alicloud_esa_load_balancer\" \"this\" {\n  site_id            = var.site_id\n  load_balancer_name = var.accelerate_domain\n  default_pools      = [alicloud_esa_origin_pool.this.origin_pool_id]\n  fallback_pool      = alicloud_esa_origin_pool.this.origin_pool_id\n  steering_policy    = \"failover\"\n\n  monitor {\n    type              = \"ICMP Ping\"\n    timeout           = 5\n    monitoring_region = \"ChineseMainland\"\n    consecutive_up    = 3\n    consecutive_down  = 5\n    interval          = 60\n  }\n}\n\n# DNS 加速记录：指向 ESA 负载均衡器\nresource \"alicloud_esa_record\" \"this\" {\n  record_name = var.record_name\n  record_type = \"CNAME\"\n  site_id     = var.site_id\n  proxied     = true\n  biz_name    = \"api\"\n  source_type = \"LB\"\n  ttl         = 1\n\n  data {\n    value = alicloud_esa_load_balancer.this.load_balancer_name\n  }\n}\n\n# 回源协议和端口（透传到 NLB 的 8080）\nresource \"alicloud_esa_origin_rule\" \"this\" {\n  site_id           = var.site_id\n  origin_scheme     = \"http\"\n  origin_http_port  = \"8080\"\n  origin_https_port = \"443\"\n  origin_host       = var.accelerate_domain\n  origin_sni        = var.accelerate_domain\n  dns_record        = var.record_name\n  rule_enable       = \"on\"\n  rule              = \"true\"\n  rule_name         = \"default-route\"\n  range             = \"off\"\n}\n\n# 免费证书\nresource \"alicloud_esa_certificate\" \"this\" {\n  site_id      = var.site_id\n  created_type = \"free\"\n  domains      = var.cert_domain\n}",
    "outputs.tf": "output \"origin_pool_id\" {\n  description = \"ESA 源地址池 ID\"\n  value       = alicloud_esa_origin_pool.this.origin_pool_id\n}\n\noutput \"load_balancer_id\" {\n  description = \"ESA 负载均衡器 ID\"\n  value       = alicloud_esa_load_balancer.this.id\n}\n\noutput \"origin_rule_config_id\" {\n  description = \"ESA 回源规则配置 ID\"\n  value       = alicloud_esa_origin_rule.this.config_id\n}\n\noutput \"esa_record_id\" {\n  description = \"ESA DNS 记录 ID\"\n  value       = alicloud_esa_record.this.id\n}"
  },
  "Parameters": {
    "site_id": {
      "Type": "String",
      "Description": "ESA 站点的 SiteId，可在 ESA 控制台 → 站点管理 → 站点信息 中查看"
    },
    "accelerate_domain": {
      "Type": "String",
      "Description": "完整的加速域名（如 apple-api-esa-prod.apple-app.cn），用于 ESA 负载均衡器名称和回源 Host"
    },
    "nlb_dns_name": {
      "Type": "String",
      "Description": "NLB 的公网 DNS 名称（来自 apple-api-esa-prod 栈的输出 NlbDNSName）"
    },
    "record_name": {
      "Type": "String",
      "Description": "ESA Record 记录名（即加速域名前缀，如 apple-api-esa-prod）"
    },
    "cert_domain": {
      "Type": "String",
      "Description": "要申请的免费证书域名，支持通配符（如 *.apple-app.cn）",
      "Default": "*.apple-app.cn"
    },
    "tags": {
      "Type": "Json",
      "Description": "标签",
      "Default": {}
    }
  },
  "Outputs": {
    "origin_pool_id": {
      "Value": null,
      "Description": "ESA 源地址池 ID"
    },
    "load_balancer_id": {
      "Value": null,
      "Description": "ESA 负载均衡器 ID"
    },
    "origin_rule_config_id": {
      "Value": null,
      "Description": "ESA 回源规则配置 ID"
    },
    "esa_record_id": {
      "Value": null,
      "Description": "ESA DNS 记录 ID"
    }
  }
}
