{
  "ROSTemplateFormatVersion": "2015-09-01",
  "Transform": "Aliyun::Terraform-v1.5",
  "Workspace": {
    "versions.tf": "terraform {\n  required_version = \">= 1.3.0\"\n\n  required_providers {\n    alicloud = {\n      source  = \"aliyun/alicloud\"\n      version = \">= 1.210.0\"\n    }\n  }\n}\n\nprovider \"alicloud\" {\n}",
    "variables.tf": "variable \"site_id\" {\n  type        = number\n  description = \"ESA 站点的 SiteId，可在 ESA 控制台 → 站点管理 → 站点信息 中查看\"\n}\n\nvariable \"cert_domain\" {\n  type        = string\n  description = \"要申请的免费证书域名，支持通配符（如 *.apple-app.cn）\"\n  default     = \"*.apple-app.cn\"\n}\n\nvariable \"accelerate_domain\" {\n  type        = string\n  description = \"完整的加速域名（如 api-prod.apple-app.cn），ESA 将此值作为回源 Host 头发送\"\n}\n\nvariable \"nlb_dns_name\" {\n  type        = string\n  description = \"NLB 的公网 DNS 名称（来自 apple-api-esa-prod 栈的输出 NlbDNSName，如 xxx.alb.us-east-1.aliyuncs.com）\"\n}\n\nvariable \"record_name\" {\n  type        = string\n  description = \"ESA Record 记录名（即加速域名的前缀，如 api-prod，与 AccelerateDomain 前缀保持一致）\"\n}\n\nvariable \"stack_name\" {\n  type        = string\n  description = \"用于命名资源的前缀，默认为 record_name\"\n  default     = \"\"\n}\n\nvariable \"tags\" {\n  type        = map(string)\n  description = \"标签\"\n  default     = {}\n}",
    "main.tf": "locals {\n  name_prefix = var.stack_name != \"\" ? var.stack_name : var.record_name\n}\n\nresource \"alicloud_esa_origin_pool\" \"this\" {\n  origin_pool_name = \"${local.name_prefix}_origin_pool\"\n  site_id          = var.site_id\n  enabled          = \"true\"\n\n  origins {\n    type    = \"ip_domain\"\n    name    = \"nlb-origin\"\n    address = var.nlb_dns_name\n    enabled = \"true\"\n    header  = \"{\\\"Host\\\":[\\\"${var.nlb_dns_name}\\\"]}\"\n    weight  = \"100\"\n  }\n}\n\nresource \"alicloud_esa_origin_rule\" \"this\" {\n  site_id           = var.site_id\n  origin_scheme     = \"http\"\n  origin_http_port  = \"8080\"\n  origin_https_port = \"443\"\n  origin_host       = var.accelerate_domain\n  origin_sni        = var.accelerate_domain\n  dns_record        = var.record_name\n  rule_enable       = \"on\"\n  rule              = \"true\"\n  rule_name         = \"default-route\"\n  range             = \"off\"\n\n  depends_on = [alicloud_esa_origin_pool.this]\n}\n\nresource \"alicloud_esa_record\" \"this\" {\n  record_name  = var.record_name\n  record_type  = \"CNAME\"\n  site_id      = var.site_id\n  proxied      = true\n  biz_name     = \"api\"\n  source_type  = \"LB\"\n  host_policy  = \"follow_hostname\"\n  ttl          = 1\n\n  data {\n    value = var.nlb_dns_name\n  }\n\n  depends_on = [alicloud_esa_origin_pool.this]\n}\n\nresource \"alicloud_esa_certificate\" \"this\" {\n  site_id      = var.site_id\n  created_type = \"free\"\n  domains      = var.cert_domain\n\n  depends_on = [alicloud_esa_record.this]\n}",
    "outputs.tf": "output \"origin_pool_id\" {\n  description = \"ESA 源地址池 ID\"\n  value       = alicloud_esa_origin_pool.this.id\n}\n\noutput \"origin_id\" {\n  description = \"源站记录的 origin_id\"\n  value       = alicloud_esa_origin_pool.this.origins[0].origin_id\n}\n\noutput \"origin_rule_config_id\" {\n  description = \"ESA 回源规则配置 ID\"\n  value       = alicloud_esa_origin_rule.this.config_id\n}\n\noutput \"esa_record_id\" {\n  description = \"ESA DNS 记录 ID\"\n  value       = alicloud_esa_record.this.id\n}"
  },
  "Parameters": {
    "site_id": {
      "Type": "Number",
      "Description": "ESA 站点的 SiteId，可在 ESA 控制台 → 站点管理 → 站点信息 中查看"
    },
    "accelerate_domain": {
      "Type": "String",
      "Description": "完整的加速域名（如 api-prod.apple-app.cn），ESA 将此值作为回源 Host 头发送"
    },
    "nlb_dns_name": {
      "Type": "String",
      "Description": "NLB 的公网 DNS 名称（来自 apple-api-esa-prod 栈的输出 NlbDNSName，如 xxx.alb.us-east-1.aliyuncs.com）"
    },
    "record_name": {
      "Type": "String",
      "Description": "ESA Record 记录名（即加速域名的前缀，如 api-prod，与 AccelerateDomain 前缀保持一致）"
    },
    "stack_name": {
      "Type": "String",
      "Description": "用于命名资源的前缀，默认为 record_name",
      "Default": ""
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
    "origin_id": {
      "Value": null,
      "Description": "源站记录的 origin_id"
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
