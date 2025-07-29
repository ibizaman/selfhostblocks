{ config, lib, pkgs, ... }:
let
  inherit (lib) mapAttrs' mkOption nameValuePair types;
  inherit (types) attrsOf listOf port submodule str;

  cfg = config.shb.mitmdump;
in
{
  options.shb.mitmdump = {
    instances = mkOption {
      default = {};
      description = "Mitmdump instance.";
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          listenPort = mkOption {
            type = port;
            description = ''
              Port the mitmdump instance will listen to.

              The upstream port from the client's perspective.
            '';
          };

          upstreamHost = mkOption {
            type = str;
            default = "http://127.0.0.1";
            description = ''
              Host the mitmdump instance will connect to.

              If only an IP or domain is provided,
              mitmdump will default to connect using HTTPS.
              If this is not wanted, prefix the IP or domain with the 'http://' protocol.
            '';
          };

          upstreamPort = mkOption {
            type = port;
            description = ''
              Port the mitmdump instance will connect to.

              The port the server is listening on.
            '';
          };

          after = mkOption {
            type = listOf str;
            default = [];
            description = ''
              Systemd services that must be started before this mitmdump proxy instance.

              You are guaranteed the mitmdump is listening on the `listenPort`
              when its systemd service has started.
            '';
          };
        };
      }));
    };
  };

  config = {
    systemd.services = mapAttrs' (name: cfg: nameValuePair "mitmdump-${name}" {
      environment = {
        "HOME" = "/var/lib/private/mitmdump-${name}";
      };
      serviceConfig = {
        Type = "notify";
        Restart = "on-failure";
        StandardOutput = "journal";
        StandardError = "journal";

        DynamicUser = true;
        WorkingDirectory = "/var/lib/mitmdump-${name}";
        StateDirectory = "mitmdump-${name}";

        ExecStart = lib.getExe (pkgs.writers.writePython3Bin "mitmdump-${name}"
          {
            libraries = [ pkgs.python3Packages.systemd ];
            flakeIgnore = [ "E501" ];
          }
          ''
            from systemd.daemon import notify
            import logging
            import subprocess
            import socket
            import sys
            import time


            logging.basicConfig(level=logging.INFO, format='%(message)s')
            

            def wait_for_port(host, port, timeout=10):
                deadline = time.time() + timeout
                while time.time() < deadline:
                    try:
                        with socket.create_connection((host, port), timeout=0.5):
                            return True
                    except Exception:
                        time.sleep(0.1)
                return False


            logging.info("Waiting for upstream address '${cfg.upstreamHost}:${toString cfg.upstreamPort}' to be up.")
            wait_for_port("${cfg.upstreamHost}", ${toString cfg.upstreamPort}, timeout=10)
            logging.info("Upstream address '${cfg.upstreamHost}:${toString cfg.upstreamPort}' to is up.")
            
            proc = subprocess.Popen(
                [
                    "${pkgs.mitmproxy}/bin/mitmdump",
                    "--listen-host", "127.0.0.1",
                    "-p", "${toString cfg.listenPort}",
                    "--set", "flow_detail=3",
                    "--set", "content_view_lines_cutoff=2000",
                    "--mode", "reverse:${cfg.upstreamHost}:${toString cfg.upstreamPort}",
                ],
                stdout=sys.stdout,
                stderr=sys.stderr,
            )

            logging.info("Waiting for mitmdump instance to start on port ${toString cfg.listenPort}.")
            if wait_for_port("127.0.0.1", ${toString cfg.listenPort}, timeout=10):
                logging.info("Mitmdump is started on port ${toString cfg.listenPort}.")
                notify("READY=1")
            else:
                proc.terminate()
                exit(1)
            
            proc.wait()
          '');
      };
      requires = cfg.after;
      after = cfg.after;
      wantedBy = [ "multi-user.target" ];
    }) cfg.instances;
  };
}
