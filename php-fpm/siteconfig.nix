{ stdenv
, pkgs
, utils
}:
{ siteConfigDir
, service
, serviceRoot ? "/usr/share/webapps/${service}"
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
}:
  
  # user = ${user}
  # group = ${group}
  # 
  # listen.owner = ${socketUser}
  # listen.group = ${socketGroup}

utils.mkConfigFile {
  name = "${service}.conf";
  dir = siteConfigDir;
  content = ''
  [${service}]
  
  listen = ${siteSocket}
  listen.allowed_clients = ${allowedClients}
  
  env[PATH] = /usr/local/bin:/usr/bin:/bin
  env[TMP] = /tmp
  
  chdir = ${serviceRoot}
  
  pm = dynamic
  
  pm.max_children = ${builtins.toString maxChildren}
  pm.start_servers = ${builtins.toString startServers}
  pm.min_spare_servers = ${builtins.toString minSpareServers}
  pm.max_spare_servers = ${builtins.toString maxSpareServers}
  
  catch_workers_output = yes
  
  pm.status_path = ${statusPath}
  '';
}
