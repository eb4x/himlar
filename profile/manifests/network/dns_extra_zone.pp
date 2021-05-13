#
# This will only work if the dns module is already set up.
# E.G. foreman_proxy with managed dns server
#
class profile::network::dns_extra_zone(
  Boolean $manage_dns_records  = $profile::network::services::manage_dns_records,
  $zone,
) {

  if $manage_dns_records {
    ::dns::zone { $zone:
      soa     => $::fqdn,
      reverse => false,
      soaip   => $::ipaddress_mgmt1,
      update_policy => {'rndc-key' => {'matchtype' => 'zonesub', 'rr' => 'ANY'}}
    }
  }

}
