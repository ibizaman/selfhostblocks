{ stdenv
, pkgs
, lib
}:
{ TtrssPostgresDB
}:

let
  asTtrssConfig = attrs: builtins.concatStringsSep "\n" (["<php"] ++ lib.attrsets.mapAttrsToList wrapPutenv attrs);
  wrapPutenv = key: value: "putenv('TTRSS_${lib.toUpper key}=${value}')";
in
stdenv.mkDerivation rec {
  name = "ttrss";
  src = pkgs.tt-rss;
  buildCommand =
    let
      configFile = pkgs.writeText "config.php" (asTtrssConfig {
        db_type = "pgsql";
        db_host = TtrssPostgresDB.target.properties.hostname;
        db_user = TtrssPostgresDB.postgresUsername;
        db_name = TtrssPostgresDB.postgresDatabase;
        db_pass = TtrssPostgresDB.postgresPassword;
        db_port = builtins.toString TtrssPostgresDB.postgresPort;

        self_url_path = "https://tt-rss.tiserbox.com/";
        single_user_mode = "true";
        simple_update_mode = "false";
        php_executable = pkgs.php;

        lock_directory = "/usr/share/webapps/tt-rss/lock";
        cache_dir = "/var/cache/tt-rss";
        icons_dir = "feed-icons";
        icons_url = "feed-icons";

        auth_auto_create = "true";
        auth_auto_login = "true";

        force_article_purge = "0";
        sphinx_server = "localhost:9312";
        sphinx_index = "ttrss, delta";

        enable_registration = "false";
        reg_notify_address = "user@your.domain.dom";
        reg_max_users = "10";

	      session_cookie_lifetime = "86400";
	      smtp_from_name = "Tiny Tiny RSS";
	      smtp_from_address = "noreply@tiserbox.com";
	      digest_subject = "[tt-rss] New headlines for last 24 hours";

	      check_for_updates = "true";
	      plugins = "auth_internal, note";

	      log_destination = "syslog";
      });
    in
      ''
      mkdir -p $out/webapps/${name}
      cp -ra $src/* $out/webapps/${name}

      mkdir -p $out/etc/ttrss
      cp ${configFile} $out/etc/ttrss/config.php

      echo "/usr/share/webapps" > $out/.dysnomia-targetdir
      # echo "http:http" > $out/.dysnomia-filesetowner
      
      cat > $out/.dysnomia-fileset <<FILESET
        mkdir /etc/ttrss

        symlink $out/etc/ttrss/config.php
        target /etc/ttrss

        mkdir /usr/share/webapps

        symlink $out/webapps/ttrss
        target /usr/share/webapps
      FILESET

      # mkdir -p $out/webapps/${name}
      # cp -ra $src/* $out/webapps/${name}

      # mkdir -p $out/etc/tt-rss/
      # cp ${configFile} $out/etc/tt-rss/config.php

      # mkdir -p $out/usr/share/webapps/tt-rss/
      # cp -ra $src/* $out/usr/share/webapps/tt-rss/
      '';
}
