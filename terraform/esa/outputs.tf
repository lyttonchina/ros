output "origin_pool_id" {
  description = "ESA 源地址池 ID"
  value       = alicloud_esa_origin_pool.this.id
}

output "origin_id" {
  description = "源站记录的 origin_id"
  value       = alicloud_esa_origin_pool.this.origins[0].origin_id
}

output "origin_rule_config_id" {
  description = "ESA 回源规则配置 ID"
  value       = alicloud_esa_origin_rule.this.config_id
}

output "esa_record_id" {
  description = "ESA DNS 记录 ID"
  value       = alicloud_esa_record.this.id
}
