# @summary
#   Class to query `icinga2::objects` from puppetdb.
#
# @param destination
#   Destination equal to what was set in parameter `export` for objects.
#
# @param environments
#   limits the response to objects of these environments
#
class icinga2::query_objects (
  String        $destination  = $facts['networking']['fqdn'],
  Array[String] $environments = [$environment],
) {
  $_environments = join($environments, "'")

  case $facts['os']['family'] {
    'windows': {
    } # windows
    default: {
      Concat {
        owner => $icinga2::globals::user,
        group => $icinga2::globals::group,
        mode  => '0640',
      }
    } # default
  }

  $pql_query =  puppetdb_query("resources[parameters] { environment in ['${_environments}'] and type = 'Icinga2::Object' and exported = true and tag = 'icinga2::instance::${destination}' and nodes { deactivated is null and expired is null } order by certname }")

  $file_list = $pql_query.map |$object| {
    $object['parameters']['target']
  }

  unique($file_list).each |$target| {
    $objects = $pql_query.filter |$object| { $target == $object['parameters']['target'] }

    $_content = $facts['os']['family'] ? {
      'windows' => regsubst(epp('icinga2/objects.epp', { 'objects' => $objects }), '\n', "\r\n", 'EMG'),
      default   => epp('icinga2/objects.epp', { 'objects' => $objects }),
    }

    if !defined(Concat[$target]) {
      concat { $target:
        ensure => present,
        tag    => 'icinga2::config::file',
        warn   => true,
      }
    }

    concat::fragment { "custom-${target}":
      target  => $target,
      content => $_content,
      order   => 99,
    }
  }
}
