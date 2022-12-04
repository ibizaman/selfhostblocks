{ lib
}:

with builtins;
with lib;
with lib.attrsets;
with lib.lists;
with lib.strings;
let
  augmentedContent = fieldName: rules: parent: set:
    let
      print = {rule = k: parent: v:
        assert assertMsg (isString v || isInt v) "cannot print key '${fieldName}.${k}' of type '${typeOf v}', should be string or int instead";
        "${k} ${toString v}";};

      matchingRule = k: v: findFirst (rule: rule.match k parent v) print rules;

      augment = parent: k: v:
        let
          match = matchingRule k v;
          rule = if hasAttr "rule" match then match.rule else null;
          rules = if hasAttr "rules" match then match.rules else null;
          indent = map (x: if hasAttr "indent" match then match.indent + x else x);
          headerFn = if hasAttr "header" match then match.header else null;
          header = optional (headerFn != null) (headerFn k);
          trailer = optional (headerFn != null) "";
        in
          if rule != null
          then rule k parent v
          else
            assert assertMsg (isAttrs v) "attempt to apply rules on key '${toString k}' which is a '${typeOf v}' but should be a set:\n${toString v}";
            header ++ indent (augmentedContent "${fieldName}.${k}" rules (parent ++ [k]) v) ++ trailer;

      augmented = mapAttrsToList (augment parent) (
        assert assertMsg (isAttrs set) "attempt to apply rules on field ${fieldName} having type '${typeOf set}':\n${toString set}";
        set
      );
    in
      flatten augmented;

  updateByPath = path: fn: set:
    if hasAttrByPath path set then
      recursiveUpdate set (setAttrByPath path (fn (getAttrFromPath path set)))
    else
      set;

  schema =
    let
      mkRule =
        { redirect ? false
        , scheme ? "https"
        , code ? null
        , condition ? null
        }:
        concatStringsRecursive " " [
          (optional redirect "redirect")
          "scheme" scheme
          (optional (code != null) "code ${toString code}")
          (optional (condition != null) "if ${condition}")
        ];

      mkBind =
        { addr
        , ssl ? false
        , crt ? null
        }:
        concatStringsRecursive " " [
          "bind"
          addr
          (optional ssl "ssl")
          (optional (crt != null) "crt ${crt}")
        ];

      mkServer =
        { name
        , address
        , balance ? null
        , check ? null
        , httpcheck ? null
        , forwardfor ? true
        }:
        [
          "mode http"
          (optional forwardfor "option forwardfor")
          (optional (httpcheck != null) "option httpchk ${httpcheck}")
          (optional (balance != null) "balance ${balance}")
          (concatStringsRecursive " " [
            "server"
            name
            address
            (optionals (check != null) (mapAttrsToList (k: v: "${k} ${v}") check))
          ])
        ];
    in [
      {
        match = k: parent: v: k == "defaults";
        indent = "    ";
        header = k: k;
        rules = [
          {
            match = k: parent: v: k == "timeout";
            rule = k: parent: v: mapAttrsToList (k1: v1: "${k} ${k1} ${v1}") v;
          }
        ];
      }
      {
        match = k: parent: v: k == "global";
        indent = "    ";
        header = k: k;
        rules = [];
      }
      {
        match = k: parent: v: k == "frontend";
        rules = [
          {
            match = k: parent: v: true;
            header = k: "frontend " + k;
            indent = "    ";
            rules = [
              {
                match = k: parent: v: k == "rules";
                rule = k: parent: v: map mkRule v;
              }
              {
                match = k: parent: v: k == "bind" && isAttrs v;
                rule = k: parent: v: mkBind v;
              }
              {
                match = k: parent: v: k == "use_backend";
                rule = k: parent: v:
                  let
                    use = name: value: "use_backend ${name} ${toString value}";
                  in
                  if isList v then
                    map (v: use v.name v.value) v
                  else
                    use v.name v.value;
              }
              {
                match = k: parent: v: true ;
                rule = k: parent: v:
                  let
                    l = prefix: v:
                      if isAttrs v then
                        mapAttrsToList (k: v: l "${prefix} ${k}" v) v
                      else if isList v then
                        map (l prefix) v
                      else if isBool v then
                        optional v prefix
                      else
                        assert assertMsg (isString v) "value for field ${k} should be a string, bool, attr or list, got: ${typeOf v}";
                        "${prefix} ${v}";
                  in
                    l k v;
              }
            ];
          }
        ];
      }
      {
        match = k: parent: v: k == "backend";
        rules = [
          {
            match = k: parent: v: true;
            header = k: "backend " + k;
            indent = "    ";
            rules = [
              {
                match = k: parent: v: k == "options";
                rule = k: parent: v: v;
              }
              {
                match = k: parent: v: k == "servers";
                rule = k: parent: v: map mkServer v;
              }
            ];
          }
        ];
      }
      # {
      #   match = k: v: k == "plugins";
      #   rule = k: v: mkPlugins v;
      # }
    ];


  concatStringsRecursive = sep: strings:
    concatStringsSep sep (flatten strings);

  recursiveMerge = attrList:
    let f = attrPath:
          zipAttrsWith (n: values:
            if tail values == [] then
              head values
            else if all isList values then
              concatLists values
            else if all isAttrs values then
              f (attrPath ++ [n]) values
            else
              last values
          );
    in f [] attrList;

  assertHasAttr = name: attrPath: v:
    assertMsg
      (hasAttrByPath attrPath v)
      "no ${last attrPath} defined in config for site ${name}.${concatStringsSep "." (init attrPath)}, found attr names: ${toString (attrNames (getAttrFromPath (init attrPath) v))}";

  # Takes a function producing a [nameValuePair], applies it to
  # all name-value pair in the given set and merges the resulting
  # [[nameValuePair]].
  mapAttrsFlatten = f: set: listToAttrs (concatLists (mapAttrsToList f set));
 
  mapIfIsAttrs = f: value:
    if isAttrs value
    then f value
    else value;
 
  flattenAttrs = sep: cond: set:
    let
      recurse = mapIfIsAttrs (mapAttrsFlatten (
        n: v: let
          result = recurse v;
        in
          if isAttrs result && cond n v
          then mapAttrsToList (n2: v2: nameValuePair "${n}${sep}${n2}" v2) result
          else [(nameValuePair n result)]
      ));
    in recurse set;
in
{
  inherit updateByPath recursiveMerge;

  default =
    { user
    , group
    , certPath
    , plugins ? []
    , stats ? null
    , debug ? false
    , sites ? {}
    }: {
      # inherit plugins;

      global = {
        # Load the plugin handling Let's Encrypt request
        # lua-load /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua

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
          backend = {};
        };

        https = (
          let 
            r = (
              [{
                mode = "http";
                bind = {
                  addr = "*:443";
                  ssl = true;
                  crt = certPath;
                };

                http-request = {
                  set-header = [
                    "X-Forwarded-Port %[dst_port]"
                    "X-Forwarded-For %[src]"
                  ];
                  add-header = [
                    "X-Forwarded-Proto https"
                  ];
                };

                http-response = [
                  ''set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"''
                ];

                # acl = flatten (mapAttrsToList (name: config:
                #   assert assertHasAttr name ["frontend" "acl"] config;
                #   config.frontend.acl
                # ) sites);
                # use_backend = mapAttrsToList (name: config:
                #   assert assertHasAttr name ["frontend" "use_backend"] config;
                #   nameValuePair name config.frontend.use_backend
                # ) sites;
              }]
              ++ (mapAttrsToList (name: config:
                assert assertHasAttr name ["frontend"] config;
                #(filterAttrs (k: v: k != "use_backend" && k != "acl")
                # (mapAttrsRecursive
                #   (ks: v: optionalAttrs (hasAttrByPath ["frontend" "use_backend"] v) (setAttrByPath ["frontend" "use_backend"] (nameValuePair name v.frontend.use_backend)))
                # config.frontend
                (updateByPath ["frontend" "use_backend"] (x: (nameValuePair name x)) config).frontend
                #)
              ) sites)
              ++ (mapAttrsToList (name: config:
                if (hasAttr "debugHeaders" config && (getAttr "debugHeaders" config) != null) then {
                  option = "httplog";
                  http-request = {
                    capture = "req.hdrs len 512 if ${config.debugHeaders}";
                  };
                  log-format = ''"%ci:%cp [%tr] %ft [[%hr]] %hs %{+Q}r"'';
                } else {}
              ) sites)
            );
          in
            recursiveMerge r
        )
        // optionalAttrs (debug) {
          log-format = ''"%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %sslv %sslc %[ssl_fc_cipherlist_str]"'';
        };
      } // optionalAttrs (stats != null)
        (let
          stats_ = {
            enable = true;
            port = 8404;
            uri = "/stats";
            refresh = "10s";
            prometheusUri = null;
            hide-version = false;
          } // stats;
        in
          {
            stats = {
              bind = "localhost:${toString stats_.port}";
              mode = "http";
              stats = {
                enable = stats_.enable;
                hide-version = stats_.hide-version;
                uri = stats_.uri;
                refresh = stats_.refresh;
              };
            } // optionalAttrs (stats_.prometheusUri != null) {
              http-request = [
                "use-service prometheus-exporter if { path ${stats_.prometheusUri} }"
              ];
            };
          });

      backend =
        mapAttrs' (name: config:
          assert assertMsg (hasAttr "backend" config) "no backend defined in config for site ${name}, found attr names: ${toString (attrNames config)}";
          nameValuePair name config.backend)
          sites;
      # inherit backend;
      # backend =
      #   let
      #     b = backend: nameValuePair backend.name {inherit (backend) options;};
      #   in
      #     listToAttrs (flatten (map (s: mapAttrsToList b s.backends) sites));
    };
 
  # mapIfHasAttr = f: attr: set:
  #   if hasAttr attr set
  #   then f (getAttr attr set)
  #   else set;

  # Lua's import system requires the import path to be something like:
  #
  #   /nix/store/123-name/<package>/<file.lua>
  #
  # Then the lua-prepend-path can be:
  #
  #   /nix/store/123-name/?/<file.lua>
  #
  # Then when lua code imports <package>, it will search in the
  # prepend paths and replace the question mark with the <package>
  # name to get a match.
  #
  # But the config.source is actually without the <package> name:
  #
  #   /nix/store/123-name/<file.lua>
  #
  # This requires us to create a new directory structure and we're
  # using a linkFarm for this.
  # pluginLinks = configs:
  #   let
  #     mkLink = config: {
  #       inherit (config) name;
  #       path = config.source;
  #     };

  #     links = pkgs.linkFarm "haproxyplugins" (map mkLink configs);
  #   in
  #     map (config:
  #       "lua-prepend-path ${links}/?/${config.init}"
  #     ) configs;

  # loadPlugins = links: configs:
  #   let
  #     mustLoad = config: hasAttr "load" config && config.load;
  #   in
  #     concatMap
  #       (config: optional (mustLoad config) "lua-load ${links}/${config.name}/${config.init}")
  #       configs;

  # mkPlugins = configs:
  #   { name
  #   , init
  #   , source
  #   , load ? false
  #   }:
  #   let
  #     path = "lua-prepend-path ${links}/?/${init}"

  #   concatStringsSep " " (flatten [
  #   ]);

  render = config:
    concatStringsSep "\n" (augmentedContent "" schema [] config);
}
