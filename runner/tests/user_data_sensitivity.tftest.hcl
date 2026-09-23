mock_provider "aws" {}

mock_provider "cloudinit" {
  mock_data "cloudinit_config" {
    defaults = {
      rendered = "rendered-cloud-init-containing-secrets"
    }
  }
}

mock_provider "terracurl" {
  mock_resource "terracurl_request" {
    defaults = {
      response = "{\"apiKey\":\"runner-registration-token\",\"id\":\"runner-id\"}"
    }
  }
}

run "rendered_user_data_is_sensitive" {
  command = plan

  variables {
    ami_id    = "ami-0123456789abcdef0"
    api_key   = "daytona-api-key"
    api_url   = "https://daytona.example.com/api"
    region_id = "region-id"
    subnet_id = "subnet-0123456789abcdef0"
    vpc_id    = "vpc-0123456789abcdef0"
  }

  assert {
    condition     = issensitive(aws_instance.runner.user_data_base64)
    error_message = "Rendered cloud-init contains credentials and must be marked sensitive at the aws_instance consumption point."
  }
}
