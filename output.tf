output bigip_1_mgmtIP {
  value = module.bigip_1.mgmtPublicIP
  
}
output bigip_2_mgmtIP {
  value = module.bigip_2.mgmtPublicIP
  
}
output bigip_username {
  value = module.bigip_2.f5_username
  
}
output bigip_password {
  value = module.bigip_2.bigip_password
  
}


