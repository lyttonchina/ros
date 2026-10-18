# ROS 模板：Web Admin 前端部署

## 模板说明

使用阿里云 ROS (Resource Orchestration Service) 自动化创建 Web Admin 前端所需的云资源。

## 资源清单

- 创建 OSS 存储桶 (存储前端静态文件)
- CDN 加速域名
- CDN 回源至 OSS 存储桶指定目录
- DNS 解析记录（指向 CDN 加速域名）
- 绑定ssl证书

## 要求

- 阿里云地域放在成都
- 需创建config文件和ros文件，参考项目里其它文件
