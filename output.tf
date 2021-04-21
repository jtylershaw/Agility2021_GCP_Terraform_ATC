output bigip_1_host {
  value = "${module.bigip_1.f5_username}@${module.bigip_1.mgmtPublicIP}"
  
}
output bigip_2_host {
  value = "${module.bigip_2.f5_username}@${module.bigip_2.mgmtPublicIP}"
  
}
output bigip_username {
  value = "${module.bigip_2.f5_username}"
  
}
output bigip_1_mgmtIP {
  value = "https://${module.bigip_1.mgmtPublicIP}"
  
}
output bigip_2_mgmtIP {
  value = "https://${module.bigip_2.mgmtPublicIP}"
  
}
output bigip_password {
  value = module.bigip_2.bigip_password
  
}
output webapp_1_IP {
  value = "http://${module.bigip_1.public_addresses[0][1][0]}"
  
}
output webapp_2_IP {
  value = "http://${module.bigip_2.public_addresses[0][1][0]}"
  
}
