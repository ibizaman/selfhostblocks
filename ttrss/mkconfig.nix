{ TtrssConfig
}:
{ name
, user
, group
, domain
, serviceName
, document_root
, lock_directory
, cache_directory
, feed_icons_directory
, enabled_plugins ? []
, auth_remote_post_logout_url ? null

, db_host
, db_port
, db_username
, db_password
, db_database

, dependsOn ? {}
}:

{
  inherit name;
  pkg = TtrssConfig {
    name = serviceName;
    inherit document_root lock_directory cache_directory feed_icons_directory;
    inherit user group;
    inherit domain;

    inherit db_host db_port db_username db_password db_database;
    inherit enabled_plugins;
    inherit auth_remote_post_logout_url;
  };

  inherit dependsOn;
  type = "fileset";
}
