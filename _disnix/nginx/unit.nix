{ stdenv
, pkgs
, utils
}:
{ name
, siteName
, user ? "http"
, group ? "http"
, pidFile ? "/run/nginx/nginx.pid"
, runtimeDirectory

, config ? {}
, dependsOn ? {}
}:

let
  nginxSocket = "${runtimeDirectory}/${config.siteName}.sock";

  listen =
    if nginxSocket != null then
      "unix:${nginxSocket}"
    else
      config.port;

  fastcgi =
    if config.phpFpmSiteSocket == null then
      ""
    else
      ''
  	  location ~ \.php$ {
  	  	fastcgi_split_path_info ^(.+\.php)(/.+)$;
  	  	fastcgi_pass unix:${config.phpFpmSiteSocket};
  	  	fastcgi_index index.php;

        fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
        fastcgi_param  SERVER_SOFTWARE    nginx;
        fastcgi_param  QUERY_STRING       $query_string;
        fastcgi_param  REQUEST_METHOD     $request_method;
        fastcgi_param  CONTENT_TYPE       $content_type;
        fastcgi_param  CONTENT_LENGTH     $content_length;
        fastcgi_param  SCRIPT_FILENAME    ${config.siteRoot}$fastcgi_script_name;
        # fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
        fastcgi_param  REQUEST_URI        $request_uri;
        fastcgi_param  DOCUMENT_URI       $document_uri;
        fastcgi_param  DOCUMENT_ROOT      ${config.siteRoot};
        fastcgi_param  SERVER_PROTOCOL    $server_protocol;
        fastcgi_param  REMOTE_ADDR        $remote_addr;
        fastcgi_param  REMOTE_PORT        $remote_port;
        fastcgi_param  SERVER_ADDR        $server_addr;
        fastcgi_param  SERVER_PORT        $server_port;
        fastcgi_param  SERVER_NAME        $server_name;
  	  }
      '';

  mkConfig =
    { port
    , siteName
    , siteRoot ? "/usr/share/webapps/${siteName}"
    , siteSocket ? null
    , phpFpmSiteSocket ? null
    , logLevel ? "WARN"
    }: ''
      error_log  syslog:server=unix:/dev/log,tag=nginx${siteName},nohostname,severity=error;

      worker_processes 5;
      worker_rlimit_nofile 8192;

      events {
        worker_connections 4096;
      }

      http {
        access_log syslog:server=unix:/dev/log,tag=nginx${siteName},nohostname,severity=info combined;

        server {
        	listen ${listen};
        	root ${siteRoot};

        	index index.php index.html;

        	location / {
        		try_files $uri $uri/ =404;
        	}

      ${fastcgi}
        }

        types {
          text/html                             html htm shtml;
          text/css                              css;
          text/xml                              xml;
          image/gif                             gif;
          image/jpeg                            jpeg jpg;
          application/x-javascript              js;
          application/atom+xml                  atom;
          application/rss+xml                   rss;

          text/mathml                           mml;
          text/plain                            txt;
          text/vnd.sun.j2me.app-descriptor      jad;
          text/vnd.wap.wml                      wml;
          text/x-component                      htc;

          image/png                             png;
          image/tiff                            tif tiff;
          image/vnd.wap.wbmp                    wbmp;
          image/x-icon                          ico;
          image/x-jng                           jng;
          image/x-ms-bmp                        bmp;
          image/svg+xml                         svg svgz;
          image/webp                            webp;

          application/java-archive              jar war ear;
          application/mac-binhex40              hqx;
          application/msword                    doc;
          application/pdf                       pdf;
          application/postscript                ps eps ai;
          application/rtf                       rtf;
          application/vnd.ms-excel              xls;
          application/vnd.ms-powerpoint         ppt;
          application/vnd.wap.wmlc              wmlc;
          application/vnd.google-earth.kml+xml  kml;
          application/vnd.google-earth.kmz      kmz;
          application/x-7z-compressed           7z;
          application/x-cocoa                   cco;
          application/x-java-archive-diff       jardiff;
          application/x-java-jnlp-file          jnlp;
          application/x-makeself                run;
          application/x-perl                    pl pm;
          application/x-pilot                   prc pdb;
          application/x-rar-compressed          rar;
          application/x-redhat-package-manager  rpm;
          application/x-sea                     sea;
          application/x-shockwave-flash         swf;
          application/x-stuffit                 sit;
          application/x-tcl                     tcl tk;
          application/x-x509-ca-cert            der pem crt;
          application/x-xpinstall               xpi;
          application/xhtml+xml                 xhtml;
          application/zip                       zip;

          application/octet-stream              bin exe dll;
          application/octet-stream              deb;
          application/octet-stream              dmg;
          application/octet-stream              eot;
          application/octet-stream              iso img;
          application/octet-stream              msi msp msm;

          audio/midi                            mid midi kar;
          audio/mpeg                            mp3;
          audio/ogg                             ogg;
          audio/x-m4a                           m4a;
          audio/x-realaudio                     ra;

          video/3gpp                            3gpp 3gp;
          video/mp4                             mp4;
          video/mpeg                            mpeg mpg;
          video/quicktime                       mov;
          video/webm                            webm;
          video/x-flv                           flv;
          video/x-m4v                           m4v;
          video/x-mng                           mng;
          video/x-ms-asf                        asx asf;
          video/x-ms-wmv                        wmv;
          video/x-msvideo                       avi;
        }

        default_type application/octet-stream;

        gzip_types text/plain text/xml text/css
                   text/comma-separated-values
                   text/javascript application/x-javascript
                   application/atom+xml;

      }
    '';

  configFile = pkgs.writeText "nginx.conf" (mkConfig config);
in
{
  inherit name;
  inherit runtimeDirectory nginxSocket;
  inherit user group;

  pkg = utils.systemd.mkService rec {
    name = "nginx-${siteName}";

    content = ''
    [Unit]
    Description=Nginx webserver

    After=network.target network-online.target
    Wants=network-online.target systemd-networkd-wait-online.target
    ${utils.unitDepends "After" dependsOn}
    ${utils.unitDepends "Wants" dependsOn}

    StartLimitInterval=14400
    StartLimitBurst=10

    [Service]
    Type=forking
    User=${user}
    Group=${group}
    PIDFile=${pidFile}
    ExecStart=${pkgs.nginx}/bin/nginx -c ${configFile} -g 'pid ${pidFile};'
    ExecReload=${pkgs.nginx}/bin/nginx -s reload
    KillMode=mixed
    # Nginx verifies it can open a file under here even when configured
    # to write elsewhere.
    LogsDirectory=nginx
    CacheDirectory=nginx
    RuntimeDirectory=nginx

    #  Restart=on-abnormal

    #  KillSignal=SIGQUIT
    TimeoutStopSec=5s

    LimitNOFILE=1048576
    LimitNPROC=512

    LockPersonality=true
    NoNewPrivileges=true
    PrivateDevices=true
    PrivateTmp=true
    ProtectClock=true
    ProtectControlGroups=true
    ProtectHome=true
    ProtectHostname=true
    ProtectKernelLogs=true
    ProtectKernelModules=true
    ProtectKernelTunables=true
    ProtectSystem=full
    RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
    RestrictNamespaces=true
    RestrictRealtime=true
    RestrictSUIDSGID=true

    #  CapabilityBoundingSet=CAP_NET_BIND_SERVICE
    AmbientCapabilities=CAP_NET_BIND_SERVICE

    #  ProtectSystem=strict
    #  ReadWritePaths=/var/lib/nginx /var/log/nginx

    [Install]
    WantedBy=multi-user.target
    '';
  };

  inherit dependsOn;
  type = "systemd-unit";
}
