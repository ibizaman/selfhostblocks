{ stdenv
, pkgs
, lib
}:
{ document_root
, name ? "ttrss"
, user ? "http"
, group ? "http"
, lock_directory
, cache_directory
, feed_icons_directory
, db_host
, db_port
, db_username
, db_database
, db_password
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
    db_host = db_host {inherit TtrssPostgresDB;};
    db_port = builtins.toString db_port;
    db_user = db_username;
    db_name = db_database;
    db_pass = db_password;

    self_url_path = self_url_path;
    single_user_mode = "true";
    simple_update_mode = "false";
    php_executable = "${pkgs.php}/bin/php";

    lock_directory = "${lock_directory}";
    cache_dir = "${cache_directory}";
    icons_dir = "${feed_icons_directory}";
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
      dr = dirOf document_root;
    in
      ''
      mkdir -p $out/${name}
      cp -ra $src/* $out/${name}
      cp ${configFile} $out/${name}/config.php

      echo "${dr}" > $out/.dysnomia-targetdir
      echo "${user}:${group}" > $out/.dysnomia-filesetowner
      
      cat > $out/.dysnomia-fileset <<FILESET
        symlink $out/${name}
        target ${dr}
      FILESET
      '';
}
