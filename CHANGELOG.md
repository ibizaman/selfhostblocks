# Upcoming Release

## Breaking Changes

- Rename `shb.nginx.autheliaProtect` to `shb.nginx.vhosts`. Indeed, the option allows to define a vhost with _optional_ Authelia protection but the former name made it look like Authelia protection was enforced.
- Rename all `shb.arr.*.APIKey` to `shb.arr.*.ApiKey`.
- Remove `shb.vaultwarden.ldapEndpoint` option because it was not used in the implementation anyway.
- Bump Nextcloud default version from 27 to 28. Add support for version 29.
- Deluge config breaks the authFile into an attrset of user to password file. Also deluge has tests now.

## User Facing Backwards Compatible Changes

- Fix home-assistant onboarding file generation. Added new VM test.
- OIDC and SMTP config are now optional in Vaultwarden. Added new VM test.
- Add default OIDC config for Authelia. This way, Authelia can start even with no config or only forward auth configs.
- Fix replaceSecrets function. It wasn't working correctly with functions from `lib.generators` and `pkgs.pkgs-lib.formats`. Also more test coverage.
- Add udev extra rules to allow smartctl Prometheus exporter to find NVMe drives.
- Revert Loki to major version 2 because upgrading to version 3 required manual intervention as Loki
  refuses to start. So until this issue is tackled, reverting is the best immediate fix.
  See https://github.com/NixOS/nixpkgs/commit/8f95320f39d7e4e4a29ee70b8718974295a619f4
- Add prometheus deluge exporter support. It just needs the `shb.deluge.prometheusScraperPasswordFile` option to be set.

## Other Changes

- Add pretty printing of test errors. Instead of:
  ```
  error: testRadarr failed: expected {"services":{"bazarr":{},"jackett":{},"lidarr":{},"nginx":{"enable":true},"radarr":{"dataDir":"/var/lib/radarr","enable":true,"group":"radarr","user":"radarr"},"readarr":{},"sonarr":{}},"shb":{"backup":{"instances":{"radarr":{"excludePatterns":[".db-shm",".db-wal",".mono"],"sourceDirectories":["/var/lib/radarr"]}}},"nginx":{"autheliaProtect":[{"authEndpoint":"https://oidc.example.com","autheliaRules":[{"domain":"radarr.example.com","policy":"bypass","resources":["^/api.*"]},{"domain":"radarr.example.com","policy":"two_factor","subject":["group:arr_user"]}],"domain":"example.com","ssl":null,"subdomain":"radarr","upstream":"http://127.0.0.1:7878"}]}},"systemd":{"services":{"radarr":{"serviceConfig":{"StateDirectoryMode":"0750","UMask":"0027"}}},"tmpfiles":{"rules":["d '/var/lib/radarr' 0750 radarr radarr - -"]}},"users":{"groups":{"radarr":{"members":["backup"]}}}}, but got {"services":{"bazarr":{},"jackett":{},"lidarr":{},"nginx":{"enable":true},"radarr":{"dataDir":"/var/lib/radarr","enable":true,"group":"radarr","user":"radarr"},"readarr":{},"sonarr":{}},"shb":{"backup":{"instances":{"radarr":{"excludePatterns":[".db-shm",".db-wal",".mono"],"sourceDirectories":["/var/lib/radarr"]}}},"nginx":{"vhosts":[{"authEndpoint":"https://oidc.example.com","autheliaRules":[{"domain":"radarr.example.com","policy":"bypass","resources":["^/api.*"]},{"domain":"radarr.example.com","policy":"two_factor","subject":["group:arr_user"]}],"domain":"example.com","ssl":null,"subdomain":"radarr","upstream":"http://127.0.0.1:7878"}]}},"systemd":{"services":{"radarr":{"serviceConfig":{"StateDirectoryMode":"0750","UMask":"0027"}}},"tmpfiles":{"rules":["d '/var/lib/radarr' 0750 radarr radarr - -"]}},"users":{"groups":{"radarr":{"members":["backup"]}}}}
  ```
  You now see:
  ```
  error: testRadarr failed (- expected, + result)
   {
     "dictionary_item_added": [
       "root['shb']['nginx']['vhosts']"
     ],
     "dictionary_item_removed": [
       "root['shb']['nginx']['authEndpoint']"
     ]
   }
  ```

# 0.1.0

Creation of CHANGELOG.md
