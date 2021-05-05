#
# Author: Yanis Guenane <yguenane@gmail.com>
# License: ApacheV2
#
# Puppet module :
#   mod 'theforeman/foreman'
#   mod 'theforeman/foremam_proxy'
#   mod 'theforeman/puppet'
#   mod 'theforeman/tftp'
#   mod 'zack/r10k'
#   mod 'ghoneycutt/eyaml
#
class profile::application::foreman(
  $manage_eyaml    = false,
  $manage_r10k     = false,
  $manage_firewall = false,
  $manage_repo_dir = false,
  $firewall_extras = {
    'http'   => {},
    'https'  => {},
    'puppet' => {},
    'dns'    => {},
    'dhcp'   => {},
    'tftp'   => {},
    'proxy'  => {},
  },
  $push_facts      = false,
) {

  include ::puppet
  include ::foreman
  include ::foreman_proxy

  include ::foreman::cli
  include ::foreman::compute::libvirt
  include ::foreman::plugin::hooks
  include ::foreman::plugin::discovery
  include ::foreman::plugin::templates

  if $manage_r10k {
    include ::r10k
    file { '/etc/puppetlabs':
      ensure => directory,
      before => Class['r10k']
    }
  }
  if $manage_eyaml {
    include ::eyaml
  }

  if $manage_repo_dir {
    file { '/opt/repo':
      ensure => directory
    }
  }

  # config
  $config = lookup('profile::application::foreman::config', Hash, 'deep', {})
  create_resources('foreman_config_entry', $config, { require => Class['foreman::install']})

  # plugins
  $plugins = lookup('profile::application::foreman::plugins', Hash, 'deep', {})
  create_resources('foreman::plugin', $plugins)

  # Push puppet facts to foreman
  $push_facts_ensure = $push_facts? {
    true    => 'present',
    default => 'absent'
  }
  cron { 'push-puppet-facts-to-foreman':
    ensure  => $push_facts_ensure,
    command => '/etc/puppetlabs/puppet/node.rb --push-facts',
    minute  => '30',
    hour    => '0',
  }

  if $manage_firewall {

    firewall { '190 foreman accept http/https':
      dport  => [80, 443],
      #extras => $firewall_extras['http']
      #extras => $firewall_extras['https']
    }

    firewall { '192 foreman accept puppet':
      dport  => 8140,
      #extras => $firewall_extras['puppet']
    }

    firewall { '193 foreman accept dns':
      dport  => 53,
      proto  => ['tcp', 'udp'],
      #extras => $firewall_extras['dns']
    }

    firewall { '195 foreman accept dhcp in':
      dport  => 67,
      proto  => 'udp',
      #extras => $firewall_extras['dhcp']
    }

    firewall { '196 foreman accept dhcp out':
      dport  => 68,
      proto  => 'udp',
      chain  => 'OUTPUT',
      #extras => $firewall_extras['dhcp']
    }

    firewall { '197 foreman accept tftp':
      dport  => 69,
      proto  => 'udp',
      #extras => $firewall_extras['tftp']
    }

    firewall { '197 foreman accept proxy_https':
      dport  => 8443,
      #extras => $firewall_extras['proxy']
    }
  }
}
