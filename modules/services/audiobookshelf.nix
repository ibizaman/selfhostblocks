{ config, pkgs, lib, ... }:

let
  cfg = config.shb.audiobookshelf;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.audiobookshelf = {
    enable = lib.mkEnableOption "selfhostblocks.audiobookshelf";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which audiobookshelf will be served.";
      example = "abs";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which audiobookshelf will be served.";
      example = "mydomain.com";
    };

    webPort = lib.mkOption {
      type = lib.types.int;
      description = "Audiobookshelf web port";
      default = 8113;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    extraServiceConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Extra configuration given to the systemd service file.";
      default = {};
      example = lib.literalExpression ''
      {
        MemoryHigh = "512M";
        MemoryMax = "900M";
      }
      '';
    };

    oidcProvider = lib.mkOption {
      type = lib.types.str;
      description = "OIDC provider name";
      default = "Authelia";
    };

    authEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "OIDC endpoint for SSO";
      example = "https://authelia.example.com";
    };

    oidcClientID = lib.mkOption {
      type = lib.types.str;
      description = "Client ID for the OIDC endpoint";
      default = "audiobookshelf";
    };

    oidcAdminUserGroup = lib.mkOption {
      type = lib.types.str;
      description = "OIDC admin group";
      default = "audiobookshelf_admin";
    };

    oidcUserGroup = lib.mkOption {
      type = lib.types.str;
      description = "OIDC user group";
      default = "audiobookshelf_user";
    };

    ssoSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the SSO shared secret.";
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["critical" "error" "warning" "info" "debug"]);
      description = "Enable logging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [{

    services.audiobookshelf = {
      enable = true;
      openFirewall = true;
      dataDir = "audiobookshelf";
      host = "127.0.0.1";
      port = cfg.webPort;
    };

    services.nginx.virtualHosts."${fqdn}" = {
      http2 = true;
      forceSSL = !(isNull cfg.ssl);
      sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
      sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

      # https://github.com/advplyr/audiobookshelf#nginx-reverse-proxy
      extraConfig = ''
        set $audiobookshelf 127.0.0.1;
        location / {
             proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
             proxy_set_header  X-Forwarded-Proto $scheme;
             proxy_set_header  Host              $host;
             proxy_set_header Upgrade            $http_upgrade;
             proxy_set_header Connection         "upgrade";

             proxy_http_version                  1.1;

             proxy_pass                          http://$audiobookshelf:${builtins.toString cfg.webPort};
             proxy_redirect                      http:// https://;
           }
      '';
    };

    shb.authelia.oidcClients = [
      {
        id = cfg.oidcClientID;
        description = "Audiobookshelf";
        secretFile = cfg.ssoSecretFile;
        public = "false";
        authorization_policy = "one_factor";
        redirect_uris = [ 
        "https://${cfg.subdomain}.${cfg.domain}/auth/openid/callback" 
        "https://${cfg.subdomain}.${cfg.domain}/auth/openid/mobile-redirect" 
        ];
      }
    ];
    
    # We want audiobookshelf to create files in the media group and to make those files group readable.
    users.users.audiobookshelf = {
      extraGroups = [ "media" ];
    };
    systemd.services.audiobookshelfd.serviceConfig.Group = lib.mkForce "media";
    systemd.services.audiobookshelfd.serviceConfig.UMask = lib.mkForce "0027";

    # We backup the whole audiobookshelf directory and set permissions for the backup user accordingly.
    users.groups.audiobookshelf.members = [ "backup" ];
    users.groups.media.members = [ "backup" ];
    shb.backup.instances.audiobookshelf = {
      sourceDirectories = [
        /var/lib/${config.services.audiobookshelf.dataDir}
      ];
    };
  } {
    systemd.services.audiobookshelfd.serviceConfig = cfg.extraServiceConfig;
  }]);
}
