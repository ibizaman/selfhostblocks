{ config, pkgs, lib, ... }:

let
  cfg = config.shb.nginx;
in
{
  options.shb.nginx = {
    accessLog = lib.mkOption {
      type = lib.types.bool;
      description = "Log all requests";
      default = false;
      example = true;
    };

    debugLog = lib.mkOption {
      type = lib.types.bool;
      description = "Verbose debug of internal. This will print what servers were matched and why.";
      default = false;
      example = true;
    };
  };

  config = {
    services.nginx.logError = lib.mkIf cfg.debugLog "stderr warn";
    services.nginx.appendHttpConfig = lib.mkIf cfg.accessLog ''
        log_format apm
          '{'
          '"remote_addr":"$remote_addr",'
          '"remote_user":"$remote_user",'
          '"time_local":"$time_local",'
          '"request":"$request",'
          '"request_length":"$request_length",'
          '"server_name":"$server_name",'
          '"status":"$status",'
          '"bytes_sent":"$bytes_sent",'
          '"body_bytes_sent":"$body_bytes_sent",'
          '"referrer":"$http_referrer",'
          '"user_agent":"$http_user_agent",'
          '"gzip_ration":"$gzip_ratio",'
          '"post":"$request_body",'
          '"upstream_addr":"$upstream_addr",'
          '"upstream_status":"$upstream_status",'
          '"request_time":"$request_time",'
          '"upstream_response_time":"$upstream_response_time",'
          '"upstream_connect_time":"$upstream_connect_time",'
          '"upstream_header_time":"$upstream_header_time"'
          '}';

        access_log syslog:server=unix:/dev/log apm;
      '';
  };
}
