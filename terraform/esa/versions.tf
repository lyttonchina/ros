terraform {
  required_version = ">= 1.3.0"

  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = ">= 1.210.0"
    }
  }
}

provider "alicloud" {
  # region = var.region
}
