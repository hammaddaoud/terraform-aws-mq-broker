locals {
  enabled = module.this.enabled

  mq_admin_user_enabled = local.enabled && var.engine_type == "ActiveMQ"

  mq_admin_user_needed = local.mq_admin_user_enabled && length(var.mq_admin_user) == 0
  mq_admin_user        = local.mq_admin_user_needed ? random_pet.mq_admin_user[0].id : try(var.mq_admin_user[0], "")

  mq_admin_password_needed = local.mq_admin_user_enabled && length(var.mq_admin_password) == 0
  mq_admin_password        = local.mq_admin_password_needed ? random_password.mq_admin_password[0].result : try(var.mq_admin_password[0], "")

  mq_application_user_needed = local.enabled && length(var.mq_application_user) == 0
  mq_application_user        = local.mq_application_user_needed ? random_pet.mq_application_user[0].id : try(var.mq_application_user[0], "")

  mq_application_password_needed = local.enabled && length(var.mq_application_password) == 0
  mq_application_password        = local.mq_application_password_needed ? random_password.mq_application_password[0].result : try(var.mq_application_password[0], "")

}

resource "random_pet" "mq_admin_user" {
  count     = local.mq_admin_user_needed ? 1 : 0
  length    = 2
  separator = "-"
}

resource "random_password" "mq_admin_password" {
  count   = local.mq_admin_password_needed ? 1 : 0
  length  = 24
  special = false
}

resource "random_pet" "mq_application_user" {
  count     = local.mq_application_user_needed ? 1 : 0
  length    = 2
  separator = "-"
}

resource "random_password" "mq_application_password" {
  count   = local.mq_application_password_needed ? 1 : 0
  length  = 24
  special = false
}
  
resource "aws_ssm_parameter" "mq_master_username" {
  count       = local.mq_admin_user_enabled ? 1 : 0
  name        = format(var.ssm_parameter_name_format, var.ssm_path, var.mq_admin_user_ssm_parameter_name)
  value       = local.mq_admin_user
  description = "MQ Username for the admin user"
  type        = "String"
  overwrite   = var.overwrite_ssm_parameter
  tags        = module.this.tags
}

resource "aws_ssm_parameter" "mq_master_password" {
  count       = local.mq_admin_user_enabled ? 1 : 0
  name        = format(var.ssm_parameter_name_format, var.ssm_path, var.mq_admin_password_ssm_parameter_name)
  value       = local.mq_admin_password
  description = "MQ Password for the admin user"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  overwrite   = var.overwrite_ssm_parameter
  tags        = module.this.tags
}

resource "aws_ssm_parameter" "mq_application_username" {
  count       = local.enabled ? 1 : 0
  name        = format(var.ssm_parameter_name_format, var.ssm_path, var.mq_application_user_ssm_parameter_name)
  value       = local.mq_application_user
  description = "AMQ username for the application user"
  type        = "String"
  overwrite   = var.overwrite_ssm_parameter
  tags        = module.this.tags
}

resource "aws_ssm_parameter" "mq_application_password" {
  count       = local.enabled ? 1 : 0
  name        = format(var.ssm_parameter_name_format, var.ssm_path, var.mq_application_password_ssm_parameter_name)
  value       = local.mq_application_password
  description = "AMQ password for the application user"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  overwrite   = var.overwrite_ssm_parameter
  tags        = module.this.tags
}

  
  
  
resource "aws_security_group" "mq_broker" {
  name        = "mq-broker-security-group"
  description = "Security group for MQ broker"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    security_groups = var.allowed_security_groups

  }


  tags = {
    Name = "mq-broker-security-group"
  }
}

  
  

  
  
resource "aws_mq_broker" "default" {
  count                      = local.enabled ? 1 : 0
  broker_name                = module.this.id
  deployment_mode            = var.deployment_mode
  engine_type                = var.engine_type
  engine_version             = var.engine_version
  host_instance_type         = var.host_instance_type
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  publicly_accessible        = var.publicly_accessible
  subnet_ids                 = var.subnet_ids
  tags                       = module.this.tags

  security_groups            = [aws_security_group.mq_broker.id]
    
  dynamic "encryption_options" {
    for_each = var.encryption_enabled ? ["true"] : []
    content {
      kms_key_id        = var.kms_mq_key_arn
      use_aws_owned_key = var.use_aws_owned_key
    }
  }


  maintenance_window_start_time {
    day_of_week = var.maintenance_day_of_week
    time_of_day = var.maintenance_time_of_day
    time_zone   = var.maintenance_time_zone
  }

  dynamic "user" {
    for_each = local.mq_admin_user_enabled ? ["true"] : []
    content {
      username       = local.mq_admin_user
      password       = local.mq_admin_password
      groups         = ["admin"]
      console_access = true
    }
  }
  user {
    username = local.mq_application_user
    password = local.mq_application_password
  }
}
