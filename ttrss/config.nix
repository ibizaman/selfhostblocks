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
# , domain
# , smtp_host
# , smtp_login
# , smtp_password
# , feedback_url ? ""
, allow_remote_user_auth ? false
, enabled_plugins ? [ "auth_internal" "note" ]
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
    single_user_mode = "false";
    simple_update_mode = "false";
    php_executable = "${pkgs.php}/bin/php";

    lock_directory = "${lock_directory}";
    cache_dir = "${cache_directory}";
    icons_dir = "${feed_icons_directory}";
    icons_url = "feed-icons";

    auth_auto_create = "true";
    auth_auto_login = "true";
    allow_remote_user_auth = if allow_remote_user_auth then "true" else "false";
    enable_registration = "false";

    force_article_purge = "0";
    sphinx_server = "localhost:9312";
    sphinx_index = "ttrss, delta";

    session_check_address = "true";
    session_cookie_lifetime = "0";
    session_expire_time = "86400";

    smtp_from_name = "Tiny Tiny RSS";
    # smtp_from_address = "noreply@${domain}";
    # inherit smtp_host smtp_login smtp_password;
    # inherit feedback_url;
    digest_enable = "true";
    digest_email_limit = "10";
    digest_subject = "[tt-rss] New headlines for last 24 hours";

    deamon_sends_digest = "true";

    check_for_new_version = "false";
    plugins = builtins.concatStringsSep ", " enabled_plugins;

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
