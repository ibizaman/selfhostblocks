{ stdenv
, pkgs
, utils
}:
{ siteConfigDir
, siteConfigFile
, portBinding
, bindService
, serviceRoot ? "/usr/share/webapps/${bindService}"
, siteSocket ? null
, phpFpmSiteSocket ? null
, logLevel ? "WARN"
}:

let
  listen =
    if siteSocket != null then
      "unix:${siteSocket}"
    else
      portBinding;

  fastcgi =
    if phpFpmSiteSocket == null then
      ""
    else
      ''
  	  location ~ \.php$ {
  	  	fastcgi_split_path_info ^(.+\.php)(/.+)$;
  	  	fastcgi_pass unix:${phpFpmSiteSocket};
  	  	fastcgi_index index.php;

        fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
        fastcgi_param  SERVER_SOFTWARE    nginx;
        fastcgi_param  QUERY_STRING       $query_string;
        fastcgi_param  REQUEST_METHOD     $request_method;
        fastcgi_param  CONTENT_TYPE       $content_type;
        fastcgi_param  CONTENT_LENGTH     $content_length;
        fastcgi_param  SCRIPT_FILENAME    ${serviceRoot}$fastcgi_script_name;
        # fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
        fastcgi_param  REQUEST_URI        $request_uri;
        fastcgi_param  DOCUMENT_URI       $document_uri;
        fastcgi_param  DOCUMENT_ROOT      ${serviceRoot};
        fastcgi_param  SERVER_PROTOCOL    $server_protocol;
        fastcgi_param  REMOTE_ADDR        $remote_addr;
        fastcgi_param  REMOTE_PORT        $remote_port;
        fastcgi_param  SERVER_ADDR        $server_addr;
        fastcgi_param  SERVER_PORT        $server_port;
        fastcgi_param  SERVER_NAME        $server_name;
  	  }
      '';

in
utils.mkConfigFile {
  name = siteConfigFile;
  dir = siteConfigDir;

  content = ''
  error_log  syslog:server=unix:/dev/log,tag=nginx${bindService},nohostname,severity=error;

  worker_processes 5;
  worker_rlimit_nofile 8192;

  events {
    worker_connections 4096;
  }

  http {
    access_log syslog:server=unix:/dev/log,tag=nginx${bindService},nohostname,severity=info combined;

    server {
    	listen ${listen};
    	root ${serviceRoot};
    
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
}
