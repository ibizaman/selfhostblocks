# to run these tests:
# nix-instantiate --eval --strict . -A tests.haproxy

{ lib
, stdenv
, pkgs
, utils
}:

let
  configcreator = pkgs.callPackage ./../haproxy/configcreator.nix { inherit utils; };
  mksiteconfig = pkgs.callPackage ./../haproxy/siteconfig.nix {};

  diff = testResult:
    with builtins;
    with lib.strings;
    if isString testResult.expected && isString testResult.result then
      let
        p = commonPrefixLength testResult.expected testResult.result;
        s = commonSuffixLength testResult.expected testResult.result;
        expectedSuffixLen = stringLength testResult.expected - s - p;
        resultSuffixLen = stringLength testResult.result - s - p;
        expectedDiff = substring p expectedSuffixLen testResult.expected;
        resultDiff = substring p resultSuffixLen testResult.result;
        omitted = len: if len == 0 then "" else "[... ${toString len} omitted]";
      in
        {inherit (testResult) name;
         commonPrefix = substring 0 p testResult.expected;
         commonSuffix = substring (stringLength testResult.expected - s) s testResult.expected;
         expected = "${omitted p}${expectedDiff}${omitted s}";
         result = "${omitted p}${resultDiff}${omitted s}";
         allExpected = testResult.expected;
         allResult = testResult.result;
        }
    else testResult;

  runTests = x: map diff (lib.runTests x);
in

with lib.attrsets;
runTests {
  testDiffSame = {
    expr = "abdef";
    expected = "abdef";
  };
  testUpdateByPath1 = {
    expr = configcreator.updateByPath ["a"] (x: x+1) {
      a = 1;
      b = 1;
    };
    expected = {
      a = 2;
      b = 1;
    };
  };
  testUpdateByPath2 = {
    expr = configcreator.updateByPath ["a" "a"] (x: x+1) {
      a = {
        a = 1;
        b = 1;
      };
      b = 1;
    };
    expected = {
      a = {
        a = 2;
        b = 1;
      };
      b = 1;
    };
  };
  testUpdateByPath3 = {
    expr = configcreator.updateByPath ["a" "a" "a"] (x: x+1) {
      a = {
        a = {
          a = 1;
          b = 1;
        };
        b = 1;
      };
      b = 1;
    };
    expected = {
      a = {
        a = {
          a = 2;
          b = 1;
        };
        b = 1;
      };
      b = 1;
    };
  };

  testRecursiveMerge1 = {
    expr = configcreator.recursiveMerge [
      {a = 1;}
      {b = 2;}
    ];
    expected = {
      a = 1;
      b = 2;
    };
  };

  testRecursiveMerge2 = {
    expr = configcreator.recursiveMerge [
      {a = {a = 1; b = 2;};}
      {a = {a = 2;};}
    ];
    expected = {
      a = {a = 2; b = 2;};
    };
  };

  tesFlattenArgs1 = {
    expr = configcreator.flattenAttrs {
      a = 1;
      b = 2;
    };
    expected = {
      a = 1;
      b = 2;
    };
  };
  tesFlattenArgs2 = {
    expr = configcreator.flattenAttrs {
      a = {
        a = 1;
        b = {
          c = 3;
          d = 4;
        };
      };
      b = 2;
    };
    expected = {
      "a.a" = 1;
      "a.b.c" = 3;
      "a.b.d" = 4;
      b = 2;
    };
  };

  testHaproxyConfigDefaultRender = {
    expr = configcreator.render (configcreator.default {
      user = "me";
      group = "mygroup";
      certPath = "/cert/path";
      plugins = {
        zone = {
          luapaths = "lib";
          source = pkgs.writeText "one.lua" "a binary";
        };
        two = {
          load = "right/two.lua";
          luapaths = ".";
          cpaths = "right";
          source = pkgs.writeText "two.lua" "a binary";
        };
      };
      globalEnvs = {
        ABC = "hello";
      };
      stats = null;
      debug = false;
    });
    expected = ''
    global
        group mygroup
        log /dev/log local0 info
        maxconn 20000
        lua-prepend-path /nix/store/ybcka9g095hp8s1hnm2ncfh1hp56v9yq-haproxyplugins/two/?.lua path
        lua-prepend-path /nix/store/ybcka9g095hp8s1hnm2ncfh1hp56v9yq-haproxyplugins/two/right/?.so cpath
        lua-prepend-path /nix/store/ybcka9g095hp8s1hnm2ncfh1hp56v9yq-haproxyplugins/zone/lib/?.lua path
        lua-load /nix/store/ybcka9g095hp8s1hnm2ncfh1hp56v9yq-haproxyplugins/two/right/two.lua
        setenv ABC hello
        tune.ssl.default-dh-param 2048
        user me

    defaults
        log global
        option httplog
        timeout client 15s
        timeout connect 10s
        timeout queue 100s
        timeout server 30s

    frontend http-to-https
        bind *:80
        mode http
        redirect scheme https code 301 if !{ ssl_fc }

    frontend https
        bind *:443 ssl crt /cert/path
        http-request add-header X-Forwarded-Proto https
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request set-header X-Forwarded-For %[src]
        http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"
        mode http
    '';
  };

  testHaproxyConfigDefaultRenderWithStatsAndDebug = {
    expr = configcreator.render (configcreator.default {
      user = "me";
      group = "mygroup";
      certPath = "/cert/path";
      stats = {
        port = 8405;
        uri = "/stats";
        refresh = "10s";
        prometheusUri = "/prom/etheus";
        hide-version = true;
      };
      debug = true;
    });
    expected = ''
    global
        group mygroup
        log /dev/log local0 info
        maxconn 20000
        tune.ssl.default-dh-param 2048
        user me

    defaults
        log global
        option httplog
        timeout client 15s
        timeout connect 10s
        timeout queue 100s
        timeout server 30s

    frontend http-to-https
        bind *:80
        mode http
        redirect scheme https code 301 if !{ ssl_fc }

    frontend https
        bind *:443 ssl crt /cert/path
        http-request add-header X-Forwarded-Proto https
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request set-header X-Forwarded-For %[src]
        http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"
        log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %sslv %sslc %[ssl_fc_cipherlist_str]"
        mode http

    frontend stats
        bind localhost:8405
        http-request use-service prometheus-exporter if { path /prom/etheus }
        mode http
        stats enable
        stats hide-version
        stats refresh 10s
        stats uri /stats
    '';
  };

  testRenderHaproxyConfigWithSite = {
    expr = configcreator.render (configcreator.default {
      user = "me";
      group = "mygroup";
      certPath = "/cert/path";
      stats = null;
      debug = false;
      sites = {
        siteName = {
          frontend = {
            capture = [
              "request header origin len 128"
            ];
            acl = {
              acl_siteName = "hdr_beg(host) siteName.";
              acl_siteName_path = "path_beg /siteName";
            };
            http-response = {
              add-header = [
                "Access-Control-Allow-Origin1 $[capture]"
                "Access-Control-Allow-Origin2 $[capture]"
              ];
            };
            use_backend = "if acl_siteName OR acl_siteName_path";
          };
          backend = {
            servers = [
              {
                name = "serviceName1";
                address = "serviceSocket";
              }
            ];
            options = [
              "cookie JSESSIONID prefix"
            ];
          };
        };
      };
    });
    expected = ''
    global
        group mygroup
        log /dev/log local0 info
        maxconn 20000
        tune.ssl.default-dh-param 2048
        user me

    defaults
        log global
        option httplog
        timeout client 15s
        timeout connect 10s
        timeout queue 100s
        timeout server 30s

    frontend http-to-https
        bind *:80
        mode http
        redirect scheme https code 301 if !{ ssl_fc }

    frontend https
        acl acl_siteName hdr_beg(host) siteName.
        acl acl_siteName_path path_beg /siteName
        bind *:443 ssl crt /cert/path
        capture request header origin len 128
        http-request add-header X-Forwarded-Proto https
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request set-header X-Forwarded-For %[src]
        http-response add-header Access-Control-Allow-Origin1 $[capture]
        http-response add-header Access-Control-Allow-Origin2 $[capture]
        http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"
        mode http
        use_backend siteName if acl_siteName OR acl_siteName_path

    backend siteName
        cookie JSESSIONID prefix
        mode http
        option forwardfor
        server serviceName1 serviceSocket
    '';
  };

  testRenderHaproxyConfigWith2Sites = {
    expr = configcreator.render (configcreator.default {
      user = "me";
      group = "mygroup";
      certPath = "/cert/path";
      stats = null;
      debug = false;
      sites = {
        siteName = {
          frontend = {
            capture = [
              "request header origin len 128"
            ];
            acl = {
              acl_siteName = "hdr_beg(host) siteName.";
              acl_siteName_path = "path_beg /siteName";
            };
            http-response = {
              add-header = [
                "Access-Control-Allow-Origin1 $[capture]"
                "Access-Control-Allow-Origin2 $[capture]"
              ];
            };
            use_backend = "if acl_siteName OR acl_siteName_path";
          };
          backend = {
            servers = [
              {
                name = "serviceName1";
                address = "serviceSocket";
              }
            ];
            options = [
              "cookie JSESSIONID prefix"
            ];
          };
        };
        siteName2 = {
          frontend = {
            capture = [
              "request header origin len 128"
            ];
            acl = {
              acl_siteName2 = "hdr_beg(host) siteName2.";
              acl_siteName2_path = "path_beg /siteName2";
            };
            http-response = {
              add-header = [
                "Access-Control-Allow-Origin3 $[capture]"
                "Access-Control-Allow-Origin4 $[capture]"
              ];
            };
            use_backend = "if acl_siteName2 OR acl_siteName2_path";
          };
          backend = {
            servers = [
              {
                name = "serviceName2";
                address = "serviceSocket";
              }
            ];
            options = [
              "cookie JSESSIONID prefix"
            ];
          };
        };
      };
    });
    expected = ''
    global
        group mygroup
        log /dev/log local0 info
        maxconn 20000
        tune.ssl.default-dh-param 2048
        user me

    defaults
        log global
        option httplog
        timeout client 15s
        timeout connect 10s
        timeout queue 100s
        timeout server 30s

    frontend http-to-https
        bind *:80
        mode http
        redirect scheme https code 301 if !{ ssl_fc }

    frontend https
        acl acl_siteName hdr_beg(host) siteName.
        acl acl_siteName2 hdr_beg(host) siteName2.
        acl acl_siteName2_path path_beg /siteName2
        acl acl_siteName_path path_beg /siteName
        bind *:443 ssl crt /cert/path
        capture request header origin len 128
        capture request header origin len 128
        http-request add-header X-Forwarded-Proto https
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request set-header X-Forwarded-For %[src]
        http-response add-header Access-Control-Allow-Origin1 $[capture]
        http-response add-header Access-Control-Allow-Origin2 $[capture]
        http-response add-header Access-Control-Allow-Origin3 $[capture]
        http-response add-header Access-Control-Allow-Origin4 $[capture]
        http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"
        mode http
        use_backend siteName if acl_siteName OR acl_siteName_path
        use_backend siteName2 if acl_siteName2 OR acl_siteName2_path

    backend siteName
        cookie JSESSIONID prefix
        mode http
        option forwardfor
        server serviceName1 serviceSocket

    backend siteName2
        cookie JSESSIONID prefix
        mode http
        option forwardfor
        server serviceName2 serviceSocket
    '';
  };

  testRenderHaproxyConfigWithSiteDebugHeaders = {
    expr = configcreator.render (configcreator.default {
      user = "me";
      group = "mygroup";
      certPath = "/cert/path";
      stats = null;
      debug = false;
      sites = {
        siteName = {
          frontend = {
            capture = [
              "request header origin len 128"
            ];
            acl = {
              acl_siteName = "hdr_beg(host) siteName.";
              acl_siteName_path = "path_beg /siteName";
            };
            http-response = {
              add-header = [
                "Access-Control-Allow-Origin1 $[capture]"
                "Access-Control-Allow-Origin2 $[capture]"
              ];
            };
            use_backend = "if acl_siteName OR acl_siteName_path";
          };
          backend = {
            servers = [
              {
                name = "serviceName1";
                address = "serviceSocket";
              }
            ];
            options = [
              "cookie JSESSIONID prefix"
            ];
          };
          debugHeaders = "acl_siteName";
        };
      };
    });
    expected = ''
    global
        group mygroup
        log /dev/log local0 info
        maxconn 20000
        tune.ssl.default-dh-param 2048
        user me

    defaults
        log global
        option httplog
        timeout client 15s
        timeout connect 10s
        timeout queue 100s
        timeout server 30s

    frontend http-to-https
        bind *:80
        mode http
        redirect scheme https code 301 if !{ ssl_fc }

    frontend https
        acl acl_siteName hdr_beg(host) siteName.
        acl acl_siteName_path path_beg /siteName
        bind *:443 ssl crt /cert/path
        capture request header origin len 128
        http-request add-header X-Forwarded-Proto https
        http-request capture req.hdrs len 512 if acl_siteName
        http-request set-header X-Forwarded-Port %[dst_port]
        http-request set-header X-Forwarded-For %[src]
        http-response add-header Access-Control-Allow-Origin1 $[capture]
        http-response add-header Access-Control-Allow-Origin2 $[capture]
        http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload;"
        log-format "%ci:%cp [%tr] %ft [[%hr]] %hs %{+Q}r"
        mode http
        option httplog
        use_backend siteName if acl_siteName OR acl_siteName_path

    backend siteName
        cookie JSESSIONID prefix
        mode http
        option forwardfor
        server serviceName1 serviceSocket
    '';
  };
}
