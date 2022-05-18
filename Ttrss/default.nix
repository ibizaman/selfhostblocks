{ stdenv
, pkgs
, lib
}:
{ documentRoot
, name ? "ttrss"
, user ? "http"
, group ? "http"
, lock_directory ? "/run/${name}/lock"
, cache_dir ? "/run/${name}/cache"
, icons_dir ? "${documentRoot}/feed-icons"
}:
{ TtrssPostgresDB
}:

let
  asTtrssConfig = attrs: builtins.concatStringsSep "\n" (
    ["<?php" ""]
    ++ lib.attrsets.mapAttrsToList wrapPutenv attrs
    ++ [""] # Needs a newline at the end
  );
  wrapPutenv = key: value: "putenv('TTRSS_${lib.toUpper key}=${value}');";

  config = self_url_path: {
    db_type = "pgsql";
    db_host = TtrssPostgresDB.target.properties.hostname;
    db_user = TtrssPostgresDB.postgresUsername;
    db_name = TtrssPostgresDB.postgresDatabase;
    db_pass = TtrssPostgresDB.postgresPassword;
    db_port = builtins.toString TtrssPostgresDB.postgresPort;

    self_url_path = self_url_path;
    single_user_mode = "true";
    simple_update_mode = "false";
    php_executable = "${pkgs.php}/bin/php";

    lock_directory = "${lock_directory}";
    cache_dir = "${cache_dir}";
    icons_dir = "${icons_dir}";
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
  };
in
stdenv.mkDerivation rec {
  inherit name;
  src = pkgs.tt-rss;

  buildCommand =
    let
      configFile = pkgs.writeText "config.php" (asTtrssConfig (config "https://${name}.tiserbox.com/"));
    in
      ''
      mkdir -p $out/${name}
      cp -ra $src/* $out/${name}
      cp ${configFile} $out/${name}/config.php

      echo "${documentRoot}" > $out/.dysnomia-targetdir
      echo "${user}:${group}" > $out/.dysnomia-filesetowner
      
      cat > $out/.dysnomia-fileset <<FILESET
        symlink $out/${name}
        target ${documentRoot}
      FILESET
      '';
}
