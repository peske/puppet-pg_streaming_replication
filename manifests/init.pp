# == Class: pg_streaming_replication
#
#  Configures and initiates PostgreSQL streaming replication
#  based on "replication slots". 
#
# === Parameters
#
# [*config_dir*]
#   Configuration directory of PostgreSQL database cluster. 
#   IMPORTANT: Should be specified without trailing slash.
#   IMPORTANT: Must be the same on all servers.
#   Default:   If postgresql::server class is used then
#              postgresql::params::confdir is used as default;
#              otherwise '/etc/postgresql/<POSTGRESQL_VERSION>/main'
#              (i.e. '/etc/postgresql/9.5/main')
#
# [*data_dir*]
#   Data directory of PostgreSQL database cluster. 
#   IMPORTANT: Should be specified without trailing slash.
#   IMPORTANT: Must be the same on all servers.
#   Default:   If postgresql::server class is used then
#              postgresql::params::datadir is used as default;
#              otherwise '/var/lib/postgresql/<POSTGRESQL_VERSION>/main'
#              (i.e. '/var/lib/postgresql/9.5/main')
#
# [*pg_ctl*]
#   Path to pg_ctl command (file) 
#   IMPORTANT: Must be the same on all servers.
#   Default:   '/usr/lib/postgresql/<POSTGRESQL_VERSION>/bin/pg_ctl'
#              (i.e. '/usr/lib/postgresql/9.5/bin/pg_ctl')
#
# [*postgres_home_dir*]
#   Data directory of PostgreSQL database cluster. 
#   IMPORTANT: Should be specified without trailing slash.
#   IMPORTANT: Must be the same on all servers.
#   Default:   '/var/lib/postgresql'
#
# [*id_rsa_source*]
#   Location where postgres user's SSH private key file resieds. 
#   IMPORTANT: Default value should be used only for testing.
#   IMPORTANT: Must be the same on all servers.
#   Default:   'puppet:///modules/pg_streaming_replication/id_rsa'
#
# [*id_rsa_pub_source*]
#   Public key that corresponds to id_rsa_source. 
#   IMPORTANT: Default value should be used only for testing.
#   IMPORTANT: Must be the same on all servers.
#   Default:   'puppet:///modules/pg_streaming_replication/id_rsa.pub'
#
# [*nodes*]
#   Array of IP addresses of ALL the servers that will participate
#   in replication (including this server). 
#   IMPORTANT: Must be the same on all servers.
#   Default:   N/A (mandatory)
#
# [*postgresql_version*]
#   PostgreSQL version. 
#   IMPORTANT: Must be the same on all servers.
#   Default:   If not specified, postgresql::server class will be used
#              for obtaining the version.
#
# [*trigger_file*]
#   Path of the trigger file (the file that will exist on primary 
#   server only). There's no reason for setting this value (changing 
#   the default value).
#   IMPORTANT: Must be the same on all servers.
#   Default:   '<config_dir>/im_the_master'
#              (i.e. '/etc/postgresql/9.5/main/im_the_master')
#
# [*standby_file*]
#   Path of standby file (the file that will exist on standby servers 
#   only). There's no reason for setting this value (changing the 
#   default value).
#   IMPORTANT: Must be the same on all servers.
#   Default:   '<config_dir>/im_slave'
#              (i.e. '/etc/postgresql/9.5/main/im_slave')
#
# [*port*]
#   PostgreSQL server listening port.
#   IMPORTANT: Must be the same on all servers.
#   Default:   If postgresql::server class is used then the default
#              value is taken from there; otherwise 5432
#
# [*max_replication_slots*]
#   See PostgreSQL documentation about the meaning of this parameter.
#   IMPORTANT: Must be the same on all servers.
#   Default:   <NUMBER_OF_NODES> + 1
#              (i.e. if you have 5 elements in *nodes* parameter, the
#              default value of this parameter will be 6.)
#
# [*max_wal_senders*]
#   See PostgreSQL documentation about the meaning of this parameter.
#   Default:   equal to *max_replication_slots*
#
# [*replication_password*]
#   For replication purpose 'replication' PostgreSQL login will be created
#   (username cannot be changed). This parameter specifies its password.
#   IMPORTANT: Must be the same on all servers.
#   Default:   N/A (mandatory)
#
# [*initiate_role*]
#   The role of the server in replication. Acceptable values are:
#     'master' and 'primary' - the same meaning - the primary server
#     'slave' and 'standby' - the same meaning - a standby server
#     'none' (default) - neutral configuration.
#   IMPORTANT: Once the replication is initiated, this parameter should
#              be set to 'none' on all the servers to avoid interferring
#              with actual failover mechanism implemented (i.e. pgpool-II)
#   Default:   'none'
#
# [*primary_server_ip*]
#   IP address of the primary server. It is used only if initiate_role 
#   is 'slave' or 'standby'; otherwise it is ignored.
#   Default:   N/A (mandatory if *initiate_role* is 'standby' or 'slave')
#
# === Example
#
#  Basic installation:
#  class { 'pg_streaming_replication': 
#    id_rsa_source        => 'puppet:///files/my_postgres_ssh_id_rsa', 
#    id_rsa_pub_source    => 'puppet:///files/my_postgres_ssh_id_rsa.pub', 
#    nodes                => ['192.168.1.1', '192.168.1.2'], 
#    replication_password => 'BDE4CE17-98E5-4FDC-B03C-B94559FE03D8', 
#  }
#
# === Authors
#
# Author Name: Fat Dragon www.itenlight.com
#
# === Copyright
#
# Copyright 2016 IT Enlight
#
class pg_streaming_replication (
  $config_dir = '',
  $data_dir = '',
  $pg_ctl = '',
  $postgres_home_dir = '/var/lib/postgresql',
  $id_rsa_source = 'puppet:///modules/pg_streaming_replication/id_rsa',
  $id_rsa_pub_source = 'puppet:///modules/pg_streaming_replication/id_rsa.pub',
  $nodes,
  $postgresql_version = '',
  $trigger_file = '',
  $standby_file = '',
  $port = 0,
  $max_replication_slots = 0,
  $max_wal_senders = 0,
  $replication_password,
  $initiate_role = 'none',
  $primary_server_ip = '') {

  #validating inputs
  validate_array($nodes)
  validate_string($replication_password)
  validate_integer($port)

  if $replication_password == '' {
    fail('replication_password cannot be empty.')
  }

  # Getting info
  if $port < 1 {

    if (defined( 'postgresql::server' )) {
      $port_used = $postgresql::server::port
    }
    else {
      $port_used = 5432
    }

  }
  else {
    $port_used = $port
  }

  #notify { "port = ${port_used}": }

  if $max_replication_slots < size($nodes) {
    $max_replication_slots_used = size($nodes) + 1
  }
  else {
    $max_replication_slots_used = $max_replication_slots
  }

  if $max_wal_senders < $max_replication_slots_used {
    $max_wal_senders_used = $max_replication_slots_used
  }
  else {
    $max_wal_senders_used = $max_wal_senders
  }

  if $postgresql_version == '' {

    if (defined( 'postgresql::server' )) {
      $postgresql_version_used = $postgresql::server::_version
    }
    else {
      fail("You must either supply 'postgresql_version' parameter or use 'postgresql::server' class from 'puppetlabs/postgresql' module.")
    }

  }
  else {
    $postgresql_version_used = $postgresql_version
  }

  if $config_dir == '' {

    if (defined( 'postgresql::server' )) {
      $config_dir_used = $postgresql::params::confdir
    }
    else {
      $config_dir_used = "/etc/postgresql/${postgresql_version_used}/main"
    }

  }
  else {
    $config_dir_used = $config_dir
  }

  #notify { "config_dir = ${config_dir_used}": }

  if $data_dir == '' {

    if (defined( 'postgresql::server' )) {
      $data_dir_used = $postgresql::params::datadir
    }
    else {
      $data_dir_used = "/etc/postgresql/${postgresql_version_used}/main"
    }

  }
  else {
    $data_dir_used = $data_dir
  }

  #notify { "data_dir = ${data_dir_used}": }

  $trigger_file_used = $trigger_file ? {
    ''      => "${config_dir_used}/im_the_master",
    default => $trigger_file,
  }

  $standby_file_used = $standby_file ? {
    ''      => "${config_dir_used}/im_slave",
    default => $standby_file,
  }

  if $standby_file_used == $trigger_file_used {
    fail('trigger_file and standby_file cannot be the same.')
  }

  $pg_ctl_used = $pg_ctl ? {
    ''      => "/var/lib/postgresql/${postgresql_version_used}/bin/pg_ctl",
    default => $pg_ctl,
  }

  # pg_hba.conf file
  if defined( 'postgresql::server' ) {
    
    if $postgresql::server::manage_pg_hba_conf {

      $nodes.each |$node_ip| {

        postgresql::server::pg_hba_rule { "replication from ${node_ip}":
          type               => 'host',
          database           => 'replication',
          user               => 'replication',
          address            => "${node_ip}/32",
          auth_method        => 'md5',
          description        => 'Replication access rule created by pg_streaming_replication module.',
          order              => 200,
          target             => "${config_dir_used}/pg_hba.conf",
          postgresql_version => $postgresql_version_used,
        }

      }

    }
    else {

      $nodes.each |$node_ip| {

        file_line { "replication from ${node_ip}":
          ensure  => 'present',
          path    => "${config_dir_used}/pg_hba.conf",
          line    => "host  replication  replication  ${node_ip}/32  md5",
          match   => "^host\s*replication\s*replication\s*${node_ip}/32",
          notify  => Service['postgresql'],
          require => Class['postgresql::server::config'],
        }

      }

    }

  }
  else {

      ensure_resource('service', 'postgresql')

      $nodes.each |$node_ip| {

        file_line { "replication from ${node_ip}":
          ensure => 'present',
          path   => "${config_dir_used}/pg_hba.conf",
          line   => "host  replication  replication  ${node_ip}/32  md5",
          match  => "^host\s*replication\s*replication\s*${node_ip}/32",
          notify => Service['postgresql'],
        }

      }

  }

  # Enabling passwordless SSH for postgres user
  if defined( 'postgresql::server' ) {

    # if postgresql::server is used waiting for it to finish.
    file { '.ssh':
      ensure  => 'directory',
      path    => "${postgres_home_dir}/.ssh",
      owner   => 'postgres',
      group   => 'postgres',
      mode    => '0700',
      require => Class['postgresql::server::config'],
    }

  }
  else {

    file { '.ssh':
      ensure => 'directory',
      path   => "${postgres_home_dir}/.ssh",
      owner  => 'postgres',
      group  => 'postgres',
      mode   => '0700',
    }

  }

  file { 'ssh_config':
    ensure  => 'file',
    path    => "${postgres_home_dir}/.ssh/config",
    source  => 'puppet:///modules/pg_streaming_replication/config',
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0600',
    require => File['.ssh'],
  }
  ->
  file { 'id_rsa':
    ensure  => 'file',
    path    => "${postgres_home_dir}/.ssh/id_rsa",
    source  => $id_rsa_source,
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0600',
    require => File['ssh_config'],
  }
  ->
  file { 'id_rsa.pub':
    ensure  => 'file',
    path    => "${postgres_home_dir}/.ssh/id_rsa.pub",
    source  => $id_rsa_pub_source,
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0644',
    require => File['id_rsa'],
  }
  ->
  file { 'authorized_keys':
    ensure  => 'file',
    path    => "${postgres_home_dir}/.ssh/authorized_keys",
    source  => $id_rsa_pub_source,
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0644',
    require => File['id_rsa.pub'],
  }
  ->
  # Replication scripts
  file { 'replscripts':
    ensure  => 'directory',
    path    => "${config_dir_used}/replscripts",
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0755',
    require => File['authorized_keys'],
  }
  ->
  file { 'disable_postgresql.sh':
    ensure  => 'file',
    path    => "${config_dir_used}/replscripts/disable_postgresql.sh",
    content => template('pg_streaming_replication/disable_postgresql.sh.erb'),
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0744',
    require => File['replscripts'],
  }
  ->
  file { 'promote.sh':
    ensure  => 'file',
    path    => "${config_dir_used}/replscripts/promote.sh",
    content => template('pg_streaming_replication/promote.sh.erb'),
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0744',
    require => File['disable_postgresql.sh'],
  }
  ->
  file { 'create_slot.sh':
    ensure  => 'file',
    path    => "${config_dir_used}/replscripts/create_slot.sh",
    content => template('pg_streaming_replication/create_slot.sh.erb'),
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0744',
    require => File['promote.sh'],
  }
  ->
  file { 'initiate_replication.sh':
    ensure  => 'file',
    path    => "${config_dir_used}/replscripts/initiate_replication.sh",
    content => template('pg_streaming_replication/initiate_replication.sh.erb'),
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0744',
    require => File['create_slot.sh'],
  }
  ->
  file { 'postgresql_conf_changed.sh':
    ensure  => 'file',
    path    => "${config_dir_used}/replscripts/postgresql_conf_changed.sh",
    content => template('pg_streaming_replication/postgresql_conf_changed.sh.erb'),
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0744',
    require => File['initiate_replication.sh'],
  }
  
  file { 'repltemplates':
    ensure  => 'directory',
    path    => "${config_dir_used}/repltemplates",
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0755',
    require => File['postgresql_conf_changed.sh'],
  }
  ->
  exec { 'postgresql_conf_changed':
    command  => '/bin/true',
    path     => ['/sbin', '/bin', '/usr/sbin', '/usr/bin', '/usr/local/sbin',
                '/usr/local/bin'],
    onlyif   => "${config_dir_used}/replscripts/postgresql_conf_changed.sh",
    provider => 'shell',
    require  => File['repltemplates'],
  }
  ->
  file_line { 'data_directory primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => "data_directory = '${data_dir_used}'",
    match   => '^#?\s*data_directory\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'data_directory standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => "data_directory = '${data_dir_used}'",
    match   => '^#?\s*data_directory\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'hba_file primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => "hba_file = '${config_dir_used}/pg_hba.conf'",
    match   => '^#?\s*hba_file\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'hba_file standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => "hba_file = '${config_dir_used}/pg_hba.conf'",
    match   => '^#?\s*hba_file\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'port primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => "port = ${port_used}",
    match   => '^#?\s*port\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'port standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => "port = ${port_used}",
    match   => '^#?\s*port\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'wal_level primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => 'wal_level = hot_standby',
    match   => '^#?\s*wal_level\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'wal_level standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => '#wal_level = minimal',
    match   => '^#?\s*wal_level\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'max_replication_slots primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => "max_replication_slots = ${max_replication_slots_used}",
    match   => '^#?\s*max_replication_slots\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'max_replication_slots standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => '#max_replication_slots = 0',
    match   => '^#?\s*max_replication_slots\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'max_wal_senders primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => "max_wal_senders = ${max_wal_senders_used}",
    match   => '^#?\s*max_wal_senders\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'max_wal_senders standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => '#max_wal_senders = 0',
    match   => '^#?\s*max_wal_senders\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'hot_standby primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => '#hot_standby = off',
    match   => '^#?\s*hot_standby\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'hot_standby standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => 'hot_standby = on',
    match   => '^#?\s*hot_standby\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'hot_standby_feedback primary':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.primary",
    line    => '#hot_standby_feedback = off',
    match   => '^#?\s*hot_standby_feedback\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  file_line { 'hot_standby_feedback standby':
    ensure  => 'present',
    path    => "${config_dir_used}/repltemplates/postgresql.conf.standby",
    line    => 'hot_standby_feedback = on',
    match   => '^#?\s*hot_standby_feedback\s*=',
    require => Exec['postgresql_conf_changed'],
  }
  ->
  # Generating password file  
  file { '.pgpass':
    ensure  => 'file',
    path    => "${postgres_home_dir}/.pgpass",
    owner   => 'postgres',
    group   => 'postgres',
    mode    => '0600',
    require => File['.ssh'],
  }
  ->
  file_line { 'postgres_replication_pass':
    ensure  => present,
    path    => "${postgres_home_dir}/.pgpass",
    line    => "*:*:*:replication:${replication_password}",
    match   => '^\*\:\*\:\*\:replication\:',
    require => File['.pgpass'],
  }
  
  exec { 'is_primary':
    command => '/bin/true',
    path    => ['/sbin', '/bin', '/usr/sbin', '/usr/bin',
                '/usr/local/sbin', '/usr/local/bin'],
    onlyif  => "test -e ${trigger_file_used}",
    require => File['.ssh'],
  }
  
  exec { 'not_primary':
    command => '/bin/true',
    path    => ['/sbin', '/bin', '/usr/sbin', '/usr/bin',
                '/usr/local/sbin', '/usr/local/bin'],
    onlyif  => "test ! -e ${trigger_file_used}",
    require => File['.ssh'],
  }
  
  exec { 'is_standby':
    command => '/bin/true',
    path    => ['/sbin', '/bin', '/usr/sbin', '/usr/bin',
                '/usr/local/sbin', '/usr/local/bin'],
    onlyif  => "test -e ${standby_file_used}",
    require => File['.ssh'],
  }
  
  exec { 'not_standby':
    command => '/bin/true',
    path    => ['/sbin', '/bin', '/usr/sbin', '/usr/bin',
                '/usr/local/sbin', '/usr/local/bin'],
    onlyif  => "test ! -e ${standby_file_used}",
    require => File['.ssh'],
  }
  
  # If replication mode set then creating/removing im_the_master/im_slave files.
  if $initiate_role == 'primary' or $initiate_role == 'master' {
    
    exec { 'promote':
      command => "${config_dir_used}/replscripts/promote.sh -f -t ${trigger_file_used} -s ${standby_file_used} -u replication -p ${replication_password}",
      path    => ['/sbin', '/bin', '/usr/sbin', '/usr/bin',
                  '/usr/local/sbin', '/usr/local/bin'],
      user    => 'postgres',
      require => [ File_line['postgres_replication_pass'],
                    File['promote.sh'],
                    Exec['not_standby', 'not_primary'] ],
      creates => $trigger_file_used,
    }
    
  }
  elsif $initiate_role == 'standby' or $initiate_role == 'slave' {
    
    if $primary_server_ip == '' {
      fail("When 'standby' or 'slave' initiate_role is specified you must also specify primary_server_ip.")
    }

    exec { 'initiate_replication':
      command => "${config_dir_used}/replscripts/initiate_replication.sh -f -t ${trigger_file_used} -s ${standby_file_used} -H ${primary_server_ip} -P ${port_used} -u replication -p ${replication_password}",
      path    => ['/sbin', '/bin', '/usr/sbin', '/usr/bin',
                  '/usr/local/sbin', '/usr/local/bin'],
      user    => 'postgres',
      require => [ File_line['postgres_replication_pass'],
                    File['initiate_replication.sh', 'authorized_keys'],
                    Exec['not_standby', 'not_primary'] ],
      creates => $standby_file_used,
    }
    
  }
  elsif $initiate_role != 'none' {
    fail("Unknown initiate_role value: '${initiate_role}'. Acceptable values are 'primary', 'master', 'standby', 'slave' and 'none'.")
  }
  
}
