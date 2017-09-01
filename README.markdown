# pg_streaming_replication #

The module configures and initiates PostgreSQL streaming replication based on _replication slots_. It is based on tutorial [PostgreSQL HA with pgpool-II](https://www.itenlight.com/blog/2016/05/18/PostgreSQL+HA+with+pgpool-II+-+Part+1) (or to be more precise on the first three parts of the tutorial).

It is an open source module, published under [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0) license and managed at [Github](https://github.com/peske/puppet-pg_streaming_replication). Contributors are welcome!

The complete tutorial is available [here](https://www.itenlight.com/blog/2016/06/04/pg_streaming_replication+Puppet+Module).

## Basic Usage

Assuming that the servers that will participate in replication are:

* 192.168.1.1 (primary)
* 192.168.1.2 (standby)

the primary server can be initialized with something like:

```
class { 'pg_streaming_replication': 
  id_rsa_source        => 'puppet:///files/my_postgres_ssh_id_rsa', 
  id_rsa_pub_source    => 'puppet:///files/my_postgres_ssh_id_rsa.pub', 
  nodes                => ['192.168.1.1', '192.168.1.2'],
  replication_password => 'BDE4CE17-98E5-4FDC-B03C-B94559FE03D8', 
  initiate_role        => 'primary', 
}
```

while the standby server can be initialized with:

```
class { 'pg_streaming_replication': 
  id_rsa_source        => 'puppet:///files/my_postgres_ssh_id_rsa', 
  id_rsa_pub_source    => 'puppet:///files/my_postgres_ssh_id_rsa.pub', 
  nodes                => ['192.168.1.1', '192.168.1.2'],
  replication_password => 'BDE4CE17-98E5-4FDC-B03C-B94559FE03D8', 
  initiate_role        => 'standby', 
  primary_server_ip    => '192.168.1.1', 
}
```

**IMPORTANT NOTE:** PostgreSQL replication is not a thing that you should _configure_ by simply copying few lines of code. Although with the previous code you'll click-up replication - there's a lot more for you to learn and understand, so I **strongly** recommend going through the tutorials mentioned above. Even if you are experienced with replication you have to know what pg_streaming_replication module actually does.

## Release History

### v0.1.1

**Date:** September 1. 2017

**Release Info:**
* Code cosmetics (thanks to puppet-lint).

### v0.1.0

**Date:** Jun 7. 2016

**Release Info:**
* Initial release.