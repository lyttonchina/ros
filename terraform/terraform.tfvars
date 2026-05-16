# ESA Origin 配置

# Site ID（从 ESA 控制台 → 站点管理 → 站点信息中查看）
site_id = 156759048689904

# 加速域名的前缀（DNS 记录名）
record_name = "apple-api-esa-prod"

# 完整的加速域名
accelerate_domain = "apple-api-esa-prod.apple-app.cn"

# NLB 的公网 DNS 名称（从截图看是这个）
nlb_dns_name = "nlb-fgk9kda9b1ea1m6ksu.us-east-1.nlb.aliyunsslbtintl.com"

# 可选：资源名称前缀，默认使用 record_name
stack_name = "stack_apple_api_esa_prod"

# 标签
tags = {
  env  = "prod"
  arch = "esa"
}