{ pkgs
, siteName
, logLevel ? "notice"
, siteRoot ? "/usr/share/webapps/${siteName}"
, user
, group
, siteSocket
, allowedClients ? "127.0.0.1"
, socketUser
, socketGroup

, statusPath ? "/status"
, maxChildren ? 5
, startServers ? 2
, minSpareServers ? 1
, maxSpareServers ? 3
}: pkgs.writeText "php-fpm-${siteName}.conf" ''
[global]
  error_log = syslog
  syslog.ident = php-fpm
  log_level = ${logLevel}

[${siteName}]
  user = ${user}
  group = ${group}
  listen = ${siteSocket}
  listen.allowed_clients = ${allowedClients}
  listen.owner = ${socketUser}
  listen.group = ${socketGroup}
  
  env[PATH] = /usr/local/bin:/usr/bin:/bin
  env[TMP] = /tmp
  
  chdir = ${siteRoot}
  
  pm = dynamic
  
  pm.max_children = ${builtins.toString maxChildren}
  pm.start_servers = ${builtins.toString startServers}
  pm.min_spare_servers = ${builtins.toString minSpareServers}
  pm.max_spare_servers = ${builtins.toString maxSpareServers}
  
  catch_workers_output = yes
  
  pm.status_path = ${statusPath}
''
