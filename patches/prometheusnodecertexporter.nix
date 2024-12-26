index f805920c5b87a..b67f41c4fb12c 100644
--- a/nixos/modules/services/monitoring/prometheus/exporters.nix
+++ b/nixos/modules/services/monitoring/prometheus/exporters.nix
@@ -66,6 +66,7 @@ let
     "nginx"
     "nginxlog"
     "node"
+    "node-cert"
     "nut"
     "nvidia-gpu"
     "pgbouncer"
diff --git a/nixos/modules/services/monitoring/prometheus/exporters/node-cert.nix b/nixos/modules/services/monitoring/prometheus/exporters/node-cert.nix
new file mode 100644
index 0000000000000..d8b2004e8e857
--- /dev/null
+++ b/nixos/modules/services/monitoring/prometheus/exporters/node-cert.nix
@@ -0,0 +1,70 @@
+{
+  config,
+  lib,
+  pkgs,
+  ...
+}:
+
+let
+  cfg = config.services.prometheus.exporters.node-cert;
+  inherit (lib) mkOption types concatStringsSep;
+in
+{
+  port = 9141;
+
+  extraOpts = {
+    paths = mkOption {
+      type = types.listOf types.str;
+      description = ''
+        List of paths to search for SSL certificates.
+      '';
+    };
+
+    excludePaths = mkOption {
+      type = types.listOf types.str;
+      description = ''
+        List of paths to exclute from searching for SSL certificates.
+      '';
+      default = [ ];
+    };
+
+    includeGlobs = mkOption {
+      type = types.listOf types.str;
+      description = ''
+        List files matching a pattern to include. Uses Go blob pattern.
+      '';
+      default = [ ];
+    };
+
+    excludeGlobs = mkOption {
+      type = types.listOf types.str;
+      description = ''
+        List files matching a pattern to include. Uses Go blob pattern.
+      '';
+      default = [ ];
+    };
+
+    user = mkOption {
+      type = types.str;
+      description = ''
+        User owning the certs.
+      '';
+      default = "acme";
+    };
+  };
+
+  serviceOpts = {
+    serviceConfig = {
+      User = cfg.user;
+      ExecStart = ''
+        ${lib.getExe pkgs.prometheus-node-cert-exporter} \
+          --listen ${toString cfg.listenAddress}:${toString cfg.port} \
+          --path ${concatStringsSep "," cfg.paths} \
+          --exclude-path "${concatStringsSep "," cfg.excludePaths}" \
+          --include-glob "${concatStringsSep "," cfg.includeGlobs}" \
+          --exclude-glob "${concatStringsSep "," cfg.excludeGlobs}" \
+          ${concatStringsSep " \\\n  " cfg.extraFlags}
+      '';
+    };
+  };
+}
diff --git a/nixos/tests/prometheus-exporters.nix b/nixos/tests/prometheus-exporters.nix
index c15a3fd20b021..f59d61e69b92e 100644
--- a/nixos/tests/prometheus-exporters.nix
+++ b/nixos/tests/prometheus-exporters.nix
@@ -1002,6 +1002,49 @@ let
       '';
     };
 
+    node-cert = {
+      nodeName = "node_cert";
+      exporterConfig = {
+        enable = true;
+        paths = ["/run/certs"];
+      };
+      exporterTest = ''
+        wait_for_unit("prometheus-node-cert-exporter.service")
+        wait_for_open_port(9141)
+        wait_until_succeeds(
+            "curl -sSf http://localhost:9141/metrics | grep 'ssl_certificate_expiry_seconds{.\\+path=\"/run/certs/node-cert\\.cert\".\\+}'"
+        )
+      '';
+
+      metricProvider = {
+        system.activationScripts.cert.text = ''
+          mkdir -p /run/certs
+          cd /run/certs
+
+          cat >ca.template <<EOF
+          organization = "prometheus-node-cert-exporter"
+          cn = "prometheus-node-cert-exporter"
+          expiration_days = 365
+          ca
+          cert_signing_key
+          crl_signing_key
+          EOF
+
+          ${pkgs.gnutls}/bin/certtool  \
+            --generate-privkey         \
+            --key-type rsa             \
+            --sec-param High           \
+            --outfile node-cert.key
+
+          ${pkgs.gnutls}/bin/certtool     \
+            --generate-self-signed        \
+            --load-privkey node-cert.key  \
+            --template ca.template        \
+            --outfile node-cert.cert
+        '';
+      };
+    };
+
     pgbouncer = {
       exporterConfig = {
         enable = true;
diff --git a/pkgs/by-name/pr/prometheus-node-cert-exporter/gomod.patch b/pkgs/by-name/pr/prometheus-node-cert-exporter/gomod.patch
new file mode 100644
index 0000000000000..84626a7477628
--- /dev/null
+++ b/pkgs/by-name/pr/prometheus-node-cert-exporter/gomod.patch
@@ -0,0 +1,33 @@
+diff --git a/go.mod b/go.mod
+index 982eef4..bdb53ee 100644
+--- a/go.mod
++++ b/go.mod
+@@ -7,4 +7,15 @@ require (
+        github.com/spf13/pflag v1.0.3
+ )
+ 
+-go 1.16
++require (
++       github.com/beorn7/perks v1.0.1 // indirect
++       github.com/cespare/xxhash/v2 v2.1.1 // indirect
++       github.com/golang/protobuf v1.4.3 // indirect
++       github.com/matttproud/golang_protobuf_extensions v1.0.1 // indirect
++       github.com/prometheus/client_model v0.2.0 // indirect
++       github.com/prometheus/procfs v0.6.0 // indirect
++       golang.org/x/sys v0.0.0-20210603081109-ebe580a85c40 // indirect
++       google.golang.org/protobuf v1.26.0-rc.1 // indirect
++)
++
++go 1.18
+diff --git a/go.sum b/go.sum
+index 8bebbb3..75f756a 100644
+--- a/go.sum
++++ b/go.sum
+@@ -39,7 +39,6 @@ github.com/google/go-cmp v0.4.0/go.mod h1:v8dTdLbMG2kIc/vJvl+f65V22dbkXbowE6jgT/
+ github.com/google/go-cmp v0.5.4/go.mod h1:v8dTdLbMG2kIc/vJvl+f65V22dbkXbowE6jgT/gNBxE=
+ github.com/google/go-cmp v0.5.5/go.mod h1:v8dTdLbMG2kIc/vJvl+f65V22dbkXbowE6jgT/gNBxE=
+ github.com/google/go-cmp v0.6.0 h1:ofyhxvXcZhMsU5ulbFiLKl/XBFqE1GSq7atu8tAmTRI=
+-github.com/google/go-cmp v0.6.0/go.mod h1:17dUlkBOakJ0+DkrSSNjCkIjxS6bF9zb3elmeNGIjoY=
+ github.com/google/gofuzz v1.0.0/go.mod h1:dBl0BpW6vV/+mYPU4Po3pmUjxk6FQPldtuIdl/M65Eg=
+ github.com/jpillora/backoff v1.0.0/go.mod h1:J/6gKK9jxlEcS3zixgDgUAsiuZ7yrSoa/FX5e0EB2j4=
+ github.com/json-iterator/go v1.1.6/go.mod h1:+SdeFBvtyEkXs7REEP0seUULqWtbJapLOCVDaaPEHmU=
diff --git a/pkgs/by-name/pr/prometheus-node-cert-exporter/package.nix b/pkgs/by-name/pr/prometheus-node-cert-exporter/package.nix
new file mode 100644
index 0000000000000..cde041771b296
--- /dev/null
+++ b/pkgs/by-name/pr/prometheus-node-cert-exporter/package.nix
@@ -0,0 +1,33 @@
+{
+  lib,
+  buildGo122Module,
+  fetchFromGitHub,
+  nixosTests,
+}:
+
+buildGo122Module {
+  pname = "node-cert-exporter";
+  version = "1.1.7-unstable-2024-12-26";
+
+  src = fetchFromGitHub {
+    owner = "amimof";
+    repo = "node-cert-exporter";
+    rev = "v1.1.7";
+    sha256 = "sha256-VYJPgNVsfEs/zh/SEdOrFn0FK6S+hNFGDhonj2syutQ=";
+  };
+
+  vendorHash = "sha256-31MHX3YntogvoJmbOytl0rXS6qtdBSBJe8ejKyu6gqM=";
+
+  # Required otherwise we get a few:
+  # vendor/github.com/golang/glog/internal/logsink/logsink.go:129:41:
+  # predeclared any requires go1.18 or later (-lang was set to go1.16; check go.mod)
+  patches = [ ./gomod.patch ];
+
+  meta = with lib; {
+    description = "Prometheus exporter for SSL certificate";
+    mainProgram = "node-cert-exporter";
+    homepage = "https://github.com/amimof/node-cert-exporter";
+    license = licenses.asl20;
+    maintainers = with maintainers; [ ibizaman ];
+  };
+}
