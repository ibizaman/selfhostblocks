{ lib
}:

with builtins;
with lib.attrsets;
with lib.lists;
with lib.strings;
rec {
  default =
    { user
    , group
    , certPath
    , stats ? null
    , debug ? false
    }: {
      global = {
        # Silence a warning issued by haproxy. Using 2048
        # instead of the default 1024 makes the connection stronger.
        "tune.ssl.default-dh-param" = 2048;

        maxconn = 20000;

        inherit user group;

        log = "/dev/log local0 info";
      };

      defaults = {
        log = "global";
        option = "httplog";

        timeout = {
          connect = "10s";
          client = "15s";
          server = "30s";
          queue = "100s";
        };
      };

      frontend = {
        http-to-https = {
          mode = "http";
          bind = "*:80";
          rules = [
            {
              redirect = true;
              scheme = "https";
              code = 301;
              condition = "!{ ssl_fc }";
            }
          ];
        };

        https = {
          mode = "http";
          bind = {
            addr = "*:443";
            ssl = true;
            crt = certPath;
          };
        } // optionalAttrs (debug) {
          log-format = "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %sslv %sslc %[ssl_fc_cipherlist_str]";
        };
      } // optionalAttrs (stats != null)
        (let
          stats_ = {
            port = 8404;
            uri = "/stats";
            refresh = "10s";
            prometheusUri = null;
          } // stats;
        in
          {
            stats = {
              bind = "localhost:${toString stats_.port}";
              mode = "http";
              stats = {
                enable = true;
                hide-version = false;
                uri = stats_.uri;
                refresh = stats_.refresh;
              } // optionalAttrs (stats_.prometheusUri != null) {
                http-request = [
                  "use-service prometheus-exporter if { path ${stats_.prometheusUri} }"
                ];
              };
            };
          });
    };

  mkRule =
    { redirect ? false
    , scheme ? "https"
    , code ? null
    , condition ? null
    }:
    concatStringsSep " " (flatten [
      (optional redirect "redirect")
        scheme
        (optional (code != null) "code ${toString code}")
        (optional (condition != null) "if ${condition}")
    ]);

  mkBind =
    { addr
    , ssl ? false
    , crt ? null
    }:
    concatStringsSep " " (flatten [
      addr
      (optional ssl "ssl")
      (optional (crt != null) "crt ${crt}")
    ]);

  augmentedContent = fieldName: rules: set:
    let
      print = {rule = k: v:
        assert lib.assertMsg (isString v || isInt v) "cannot print key '${k}' of type '${typeOf v}', should be string or int instead";
        "${k} ${toString v}";};

      matchingRule = k: v: findFirst (rule: rule.match k v) print rules;

      augment = k: v:
        let
          match = matchingRule k v;
          rule = if hasAttr "rule" match then match.rule else null;
          rules = if hasAttr "rules" match then match.rules else null;
        in
          if rule != null
          then rule k v
          else
            assert lib.assertMsg (isAttrs v) "attempt to apply rules on key '${k}' which is a '${typeOf v}' but should be a set";
            augmentedContent k rules v;
    in
      flatten (mapAttrsToList augment (
        assert lib.assertMsg (isAttrs set) "attempt to apply rules on field ${fieldName} having type '${typeOf set}'";
        set
      ));

  # mkSection = name: config:
  schema = [
    {
      match = k: v: k == "defaults";
      rules = [
        {
          match = k: v: k == "timeout";
          rule = k: v: mapAttrsToList (k1: v1: "${k}.${k1} ${v1}") v;
        }
      ];
    }
    {
      match = k: v: k == "global";
      rules = [];
    }
    {
      match = k: v: k == "frontend";
      rules = [
        {
          match = k: v: true;
          rules = [
            {
              match = k: v: k == "rules";
              rule = k: v: map mkRule v;
            }
            {
              match = k: v: k == "bind" && isAttrs v;
              rule = k: v: mkBind v;
            }
            {
              match = k: v: k == "http-request" || k == "http-response";
              rule = k: v: v;
            }
          ];
        }
      ];
    }
  ];

  render = config:
    concatStringsSep "\n" (augmentedContent name schema config);
}
