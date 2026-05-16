output "origin_pool_id" {
  description = "ESA 源地址池 ID"
  value       = alicloud_esa_origin_pool.this.id
}

output "origin_pool_record_name" {
  description = "源地址池的 CNAME 记录名（可作为源站在其他配置中引用）"
  value       = alicloud_esa_origin_pool.this.record_name
}

output "origin_rule_config_id" {
  description = "ESA 回源规则配置 ID"
  value       = alicloud_esa_origin_rule.this.config_id
}

output "esa_record_id" {
  description = "ESA DNS 记录 ID"
  value       = alicloud_esa_record.this.record_id
}
