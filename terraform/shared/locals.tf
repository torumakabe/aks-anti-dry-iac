locals {
  agw_name = "agw-shared" # separate from settings to avoid self-referencing local value
  agw_settings = {
    gateway_ip_configuration_name  = "${local.agw_name}-gwip"
    backend_address_pool_name      = "${local.agw_name}-beap"
    frontend_port_name             = "${local.agw_name}-feport"
    frontend_ip_configuration_name = "${local.agw_name}-feip"
    http_setting_name              = "${local.agw_name}-be-htst"
    listener_name                  = "${local.agw_name}-httplstn"
    request_routing_rule_name      = "${local.agw_name}-rqrt"
    backend_ip_addresses = [
      for key, ip in var.demoapp_svc_ips : ip
    ]
  }
}
