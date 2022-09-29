{}:
{
  name ? "ttrss",
  document_root ? "/usr/share/webapps/${name}",
  systemd_run ? "/run/${name}",
  persistent_dir ? "/var/lib/${name}"
}:
rec {
  inherit name document_root systemd_run persistent_dir;

  lock_directory = "${systemd_run}/lock";
  cache_directory = "${systemd_run}/cache";
  feed_icons_directory = "${persistent_dir}/feed-icons";

  ro_directories = [];
  rw_directories = [
    lock_directory
    cache_directory
    feed_icons_directory
  ];

  directories_modes = {
    "${systemd_run}" = "0550";
    "${lock_directory}" = "0770";
    "${cache_directory}" = "0770";
    "${cache_directory}/upload" = "0770";
    "${cache_directory}/images" = "0770";
    "${cache_directory}/export" = "0770";
    "${persistent_dir}/feed-icons" = "0770";
  };

  postgresql = {
    username = name;
    password = "ttrsspw";
    database = name;
  };
}
