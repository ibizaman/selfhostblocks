{ lib
, pkgs

, siteName
, prependFile ? null
, extensions ? [
  #  "bcmath"
  #  "curl"
  #  "gd"
  #  "gmp"
  #  "iconv"
  #  "imagick"
  #  "intl"
  #  "ldap"
  #  "pdo_pgsql"
  #  "pdo_sqlite"
  #  "pgsql"
  #  "soap"
  #  "sqlite3"
  #  "zip"
]
, zend_extensions ? [
  #  "opcache"
]
}:

let
  concatWithPrefix = prefix: content:
    lib.strings.concatMapStrings
      (x: prefix + x + "\n")
      content;
in

pkgs.writeText "php-${siteName}.ini" ''
  [PHP]
  engine = On
  short_open_tag = Off
  precision = 14
  output_buffering = 4096
  zlib.output_compression = Off
  implicit_flush = Off
  serialize_precision = -1
  zend.enable_gc = On
  zend.exception_ignore_args = On
  expose_php = Off
  max_execution_time = 30 ; seconds
  max_input_time = 60
  memory_limit = 1024M
  error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
  display_errors = Off
  display_startup_errors = Off
  log_errors = On
  log_errors_max_len = 1024
  ignore_repeated_errors = On
  ignore_repeated_source = On
  report_memleaks = On
  error_log = syslog
  syslog.ident = php

  cgi.fix_pathinfo=1

  post_max_size = 8M

  auto_prepend_file = "${if prependFile == null then "" else prependFile}"
  auto_append_file =

  extension_dir = "/usr/lib/php/modules/"

  ${concatWithPrefix "extension=" extensions}
  ${concatWithPrefix "zend_extension=" zend_extensions}

  [CLI Server]
  cli_server.color = On

  ; [PostgreSQL]
  ; pgsql.allow_persistent = On
  ; pgsql.auto_reset_persistent = Off
  ; pgsql.max_persistent = -1
  ; pgsql.max_links = -1
  ; pgsql.ignore_notice = 0
  ; pgsql.log_notice = 0

  ; [Session]
  ; session.save_handler = redis
  ; session.save_path = "unix:///run/redis/redis.sock?database=1"
  ; session.use_strict_mode = 1
  ; session.use_cookies = 1
  ; session.use_only_cookies = 1

  ; [opcache]
  ; opcache.enable=1
  ; opcache.memory_consumption=128
  ; opcache.interned_strings_buffer=16
  ; opcache.max_accelerated_files=20000
''
