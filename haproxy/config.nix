{ stdenv
, pkgs
, lib
, utils
}:
{ configDir ? "/etc/haproxy"
, configFile ? "haproxy.cfg"
, frontends ? []
, backends ? []
, certPath
, user ? "haproxy"
, group ? "haproxy"

, statsEnable ? false
, statsPort ? 8404
, statsUri ? "/stats"
, statsRefresh ? "10s"
, prometheusStatsUri ? null
}:

let

  stats = if statsEnable then "" else ''
  frontend stats
      bind localhost:${builtins.toString statsPort}
      mode http
      stats enable
      # stats hide-version
      stats uri ${statsUri}
      stats refresh ${statsRefresh}
  '' + (if prometheusStatsUri == null then "" else ''
      http-request use-service prometheus-exporter if { path ${prometheusStatsUri} }
  '');

  indent = spaces: content:
    lib.strings.concatMapStrings
      (x: spaces + x + "\n")
      (lib.strings.splitString "\n" content);

  frontends_str = lib.strings.concatMapStrings (acl: indent "    " acl) frontends;
  backends_str = builtins.concatStringsSep "\n" backends;

in

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = ''
  global
      # Load the plugin handling Let's Encrypt request
      # lua-load /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua
  
      # Silence a warning issued by haproxy. Using 2048
      # instead of the default 1024 makes the connection stronger.
      tune.ssl.default-dh-param  2048
  
      maxconn 20000
  
      user ${user}
      group ${group}
  
      log /dev/log local0 info

      # Include ssl cipher in log output.
      # tune.ssl.capture-cipherlist-size 800
  
  defaults
      log global
      option httplog
  
      timeout connect  10s
      timeout client   15s
      timeout server   30s
      timeout queue    100s
  
  frontend http-to-https
      mode http
      bind *:80
      redirect scheme https code 301 if !{ ssl_fc }
  
  ${stats}

  frontend https
      mode http

      # log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %sslv %sslc %[ssl_fc_cipherlist_str]"

      bind *:443 ssl crt ${certPath}
      http-request set-header X-Forwarded-Port %[dst_port]
      http-request set-header X-Forwarded-For %[src]
      http-request add-header X-Forwarded-Proto https
      http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"

  ${frontends_str}

  ${backends_str}
  '';
} 
