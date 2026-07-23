{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mapAttrs'
    mkOption
    nameValuePair
    types
    ;
  inherit (types)
    attrsOf
    listOf
    port
    submodule
    str
    ;

  cfg = config.shb.mitmdump;

  mitmdumpScript =
    pkgs.writers.writePython3Bin "mitmdump"
      {
        libraries =
          let
            p = pkgs.python3Packages;
          in
          [
            p.systemd-python
            p.mitmproxy
          ];
        flakeIgnore = [ "E501" ];
      }
      ''
        from systemd.daemon import notify
        import argparse
        import logging
        import os
        import subprocess
        import socket
        import sys
        import time
        from urllib.parse import urlparse


        logging.basicConfig(level=logging.INFO, format='%(message)s')


        def wait_for_port(host, port, timeout):
            deadline = time.time() + timeout
            while time.time() < deadline:
                try:
                    with socket.create_connection((host, port), timeout=0.5):
                        return True
                except Exception:
                    time.sleep(0.1)
            return False


        def flatten(xss):
            return [x for xs in xss for x in xs]


        parser = argparse.ArgumentParser()
        parser.add_argument("--listen_host", default="127.0.0.1", help="Host mitmdump will listen on")
        parser.add_argument("--listen_port", required=True, help="Port mitmdump will listen on")
        parser.add_argument("--upstream_host", default="http://127.0.0.1", help="URL of the upstream host. Must include an http:// or https:// scheme. Example: http://127.0.0.1 or https://otherhost")
        parser.add_argument("--upstream_port", required=True, help="Port mitmdump will connect to for upstream")
        parser.add_argument("--timeout", required=False, type=int, default=10, help="Timeout to wait for port availability")
        args, rest = parser.parse_known_args()

        MITMDUMP_BIN = os.environ.get("MITMDUMP_BIN")
        if MITMDUMP_BIN is None:
            raise Exception("MITMDUMP_BIN env var must be set to the path of the mitmdump binary")

        upstream_hostname = urlparse(args.upstream_host).hostname
        if upstream_hostname is None:
            parser.error(f"Could not determine hostname from upstream host '{args.upstream_host}'")

        logging.info(f"Waiting for upstream address '{args.upstream_host}:{args.upstream_port}' to be up.")
        if not wait_for_port(upstream_hostname, args.upstream_port, timeout=args.timeout):
            raise TimeoutError(f"Upstream address '{args.upstream_host}:{args.upstream_port}' did not become available within {args.timeout} seconds")
        logging.info(f"Upstream address '{args.upstream_host}:{args.upstream_port}' is up.")

        proc = subprocess.Popen(
            [
                MITMDUMP_BIN,
                "--listen-host", args.listen_host,
                "-p", args.listen_port,
                "--mode", f"reverse:{args.upstream_host}:{args.upstream_port}",
            ] + rest,
            stdout=sys.stdout,
            stderr=sys.stderr,
        )

        logging.info(f"Waiting for mitmdump instance to start on port {args.listen_port}.")
        if wait_for_port("127.0.0.1", args.listen_port, timeout=args.timeout):
            logging.info(f"Mitmdump is started on port {args.listen_port}.")
            notify("READY=1")
        else:
            print(f"Mitmdump instance did not start before the timeout of {args.timeout} seconds, consider increasing the timeout")
            proc.terminate()
            exit(1)

        proc.wait()
      '';

  logger = toString (
    pkgs.writers.writeText "loggerAddon.py" ''
      import logging
      from collections.abc import Sequence
      from mitmproxy import ctx, http
      import re


      logger = logging.getLogger(__name__)


      class RegexLogger:
          def __init__(self):
              self.verbose_patterns = None

          def load(self, loader):
              loader.add_option(
                  name="verbose_pattern",
                  typespec=Sequence[str],
                  default=[],
                  help="Regex patterns for verbose logging",
              )

          def response(self, flow: http.HTTPFlow):
              if self.verbose_patterns is None:
                  self.verbose_patterns = [re.compile(p) for p in ctx.options.verbose_pattern]

              matched = any(p.search(flow.request.path) for p in self.verbose_patterns)
              if matched:
                  logger.info(format_flow(flow))


      def format_flow(flow: http.HTTPFlow) -> str:
          return (
              "\n"
              "RequestHeaders:\n"
              f"    {format_headers(flow.request.headers.items())}\n"
              f"RequestBody:     {flow.request.get_text()}\n"
              f"Status:          {flow.response.data.status_code}\n"
              "ResponseHeaders:\n"
              f"    {format_headers(flow.response.headers.items())}\n"
              f"ResponseBody:    {flow.response.get_text()}\n"
          )


      def format_headers(headers) -> str:
          return "\n    ".join(k + ": " + v for k, v in headers)


      addons = [RegexLogger()]
    ''
  );
in
{
  options.shb.mitmdump = {
    addons = mkOption {
      type = attrsOf str;
      default = [ ];
      description = ''
        Addons available to the be added to the mitmdump instance.

        To enabled them, add them to the `enabledAddons` option.
      '';
    };

    instances = mkOption {
      default = { };
      description = "Mitmdump instance.";
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              package = lib.mkPackageOption pkgs "mitmproxy" { };

              serviceName = mkOption {
                type = str;
                description = ''
                  Name of the mitmdump system service.
                '';
                default = "mitmdump-${name}.service";
                readOnly = true;
              };

              listenHost = mkOption {
                type = str;
                default = "127.0.0.1";
                description = ''
                  Host the mitmdump instance will connect on.
                '';
              };

              listenPort = mkOption {
                type = port;
                description = ''
                  Port the mitmdump instance will listen on.

                  The upstream port from the client's perspective.
                '';
              };

              upstreamHost = mkOption {
                type = str;
                default = "http://127.0.0.1";
                description = ''
                  URL of the upstream host the mitmdump instance will connect to.

                  Must include an `http://` or `https://` scheme.
                  Configure the port separately with `upstreamPort`.
                '';
              };

              upstreamPort = mkOption {
                type = port;
                description = ''
                  Port the mitmdump instance will connect to.

                  The port the server is listening on.
                '';
              };

              timeout = mkOption {
                type = types.int;
                default = 30;
                description = ''
                  Time to wait for upstream to start and mitmdump to start.
                '';
              };

              after = mkOption {
                type = listOf str;
                default = [ ];
                description = ''
                  Systemd services that must be started before this mitmdump proxy instance.

                  You are guaranteed the mitmdump is listening on the `listenPort`
                  when its systemd service has started.
                '';
              };

              enabledAddons = mkOption {
                type = listOf str;
                default = [ ];
                description = ''
                  Addons to enable on this mitmdump instance.
                '';
                example = lib.literalExpression "[ config.shb.mitmdump.addons.logger ]";
              };

              extraArgs = mkOption {
                type = listOf str;
                default = [ ];
                description = ''
                  Extra arguments to pass to the mitmdump instance.

                  See upstream [manual](https://docs.mitmproxy.org/stable/concepts/options/#flow_detail) for all possible options.
                '';
                example = lib.literalExpression ''[ "--set" "verbose_pattern=/api" ]'';
              };
            };
          }
        )
      );
    };
  };

  config = {
    systemd.services = mapAttrs' (
      name: cfg':
      nameValuePair "mitmdump-${name}" {
        environment = {
          "HOME" = "/var/lib/private/mitmdump-${name}";
          "MITMDUMP_BIN" = "${cfg'.package}/bin/mitmdump";
        };
        serviceConfig = {
          Type = "notify";
          Restart = "on-failure";
          StandardOutput = "journal";
          StandardError = "journal";

          DynamicUser = true;
          WorkingDirectory = "/var/lib/mitmdump-${name}";
          StateDirectory = "mitmdump-${name}";

          ExecStart =
            let
              addons = lib.concatMapStringsSep " " (addon: "-s ${addon}") cfg'.enabledAddons;
              extraArgs = lib.concatStringsSep " " cfg'.extraArgs;
            in
            "${lib.getExe mitmdumpScript} --listen_host ${cfg'.listenHost} --listen_port ${toString cfg'.listenPort} --upstream_host ${cfg'.upstreamHost} --upstream_port ${toString cfg'.upstreamPort} --timeout ${toString cfg'.timeout} ${addons} ${extraArgs}";
        };
        requires = cfg'.after;
        after = cfg'.after;
        wantedBy = [ "multi-user.target" ];
      }
    ) cfg.instances;

    shb.mitmdump.addons = {
      inherit logger;
    };
  };
}
