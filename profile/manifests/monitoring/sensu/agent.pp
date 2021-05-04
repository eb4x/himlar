#
class profile::monitoring::sensu::agent (
  Boolean $enable_agent = false,
  Boolean $enable_go_agent = false,
  Boolean $run_in_vrf = false,
  String $merge_strategy = 'deep',
  Array $expanded_checks = [],
  Hash $expanded_defaults = {},
  Boolean $expanded_transform_url = false,
  Boolean $expanded_transform_md5 = false,
  Boolean $purge_check = false
) {

  if $enable_agent {
    include ::sensuclassic

    $gems = lookup('profile::monitoring::sensu::agent::plugin_gems', Hash, $merge_strategy, {})
    $plugins = lookup('profile::monitoring::sensu::agent::plugins', Hash, $merge_strategy, {})
    $checks  = lookup('profile::monitoring::sensu::agent::checks', Hash, $merge_strategy, {})

    create_resources('::sensuclassic::plugin', $plugins)
    create_resources('::sensuclassic::check', $checks)
    create_resources('package', $gems)

    if $expanded_checks {
      $expanded_checks.each |String $prefix| {
        $real_check = merge($expanded_defaults, { 'command' => "${expanded_defaults[command]}${prefix}" })
        # Resource name is also the filename for the check. To make this work
        # with complex prefix use on of the two transform options (URL or MD5)
        if $expanded_transform_url {
          $resource_name = inline_template('<%= URI(@prefix).host %>')
        } elsif $expanded_transform_md5 {
          $resource_name = md5($prefix)
        } else {
          $resource_name = "${prefix}-check"
        }
        create_resources('::sensuclassic::check', { $resource_name => $real_check })
      }
    }

    # this is used for cumulus linux (debian)
    if $run_in_vrf {

      file { 'sensu-systemd-dir':
        ensure => directory,
        path   => '/etc/systemd/system/sensu-client.service.d/',
        owner  => root,
        group  => root,
      }
      -> file { 'sensu-systemd-override':
        ensure => file,
        path   => '/etc/systemd/system/sensu-client.service.d/override.conf',
        owner  => root,
        group  => root,
        source => "puppet:///modules/${module_name}/monitoring/sensu/systemd/override.conf",
        notify => [Exec['debian_systemctl_daemon_reload'], Service['sensu-client']]
      }

      exec { 'debian_systemctl_daemon_reload':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
      }
    }

  } elsif $enable_go_agent {

    include ::sensu
    include ::sensu::agent
    include ::sensu::plugins
    include ::sensu::cli

    # We cannot add sensu check to client agent because puppet will need to
    # pre validate the namespace before the agent is installed!

    $bonsai_assets = lookup('profile::monitoring::sensu::agent::bonsai_assets', Hash, $merge_strategy, {})
    # merge strategy can only be first until we remove sensu classic
    $plugins = lookup('profile::monitoring::sensu::agent::plugins', Hash, 'first', {})

    create_resources('sensu_bonsai_asset', $bonsai_assets)
    create_resources('sensu_plugin', $plugins)

    sensu_resources { 'sensu_check':
      purge => $purge_check,
    }

  }
}
