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
        log_format postdata '$remote_addr - $remote_user [$time_local] '
                            '"$request" <$server_name> $status $body_bytes_sent '
                            '"$http_referer" "$http_user_agent" "$gzip_ratio" '
                            'post:"$request_body"';

        access_log syslog:server=unix:/dev/log postdata;
      '';
  };
}
