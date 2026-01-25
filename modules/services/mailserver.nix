{
  config,
  lib,
  shb,
  pkgs,
  ...
}:
let
  cfg = config.shb.mailserver;
in
{
  imports = [
    (
      builtins.fetchGit {
        url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git";
        ref = "master";
        rev = "5965fae920b6b97f39f94bdb6195631e274c93a5";
      }
      + "/default.nix"
    )
    ../blocks/lldap.nix
  ];

  options.shb.mailserver = {
    enable = lib.mkEnableOption "SHB's nixos-mailserver module";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which imap and smtp functions will be served.";
      default = "imap";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which imap and smtp functions will be served.";
      example = "mydomain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr shb.contracts.ssl.certs;
      default = null;
    };

    adminUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Admin username.

        postmaster will be made an alias of this user.
      '';
      example = "admin";
    };

    adminPassword = lib.mkOption {
      description = "Admin user password.";
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = shb.contracts.secret.mkRequester {
            mode = "0400";
            owner = config.services.postfix.user;
            ownerText = "services.postfix.user";
            restartUnits = [ "dovecot.service" ];
          };
        }
      );
    };

    imapSync = lib.mkOption {
      description = ''
        Synchronize one or more email providers through IMAP
        to your dovecot2 instance.

        This allows you to backup that email provider
        and centralize your accounts in this dovecot2 instance.
      '';
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            syncTimer = lib.mkOption {
              type = lib.types.str;
              default = "5m";
              description = ''
                Systemd timer for when imap sync job should happen.

                This timer is not scheduling the job at regular intervals.
                After a job finishes, the given amount of time is waited then the next job is started.

                The default is set deliberatily slow to not spam you when setting up your mailserver.
                When everything works, you will want to reduce it to 10s or something like that.
              '';
              example = "10s";
            };

            debug = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable verbose mbsync logging.";
            };

            accounts = lib.mkOption {
              description = ''
                Accounts to sync emails from using IMAP.

                Emails will be stored under `''${config.mailserver.mailDirectory}/''${name}/''${username}`
              '';
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    host = lib.mkOption {
                      type = lib.types.str;
                      description = "Hostname of the email's provider IMAP server.";
                      example = "imap.fastmail.com";
                    };

                    port = lib.mkOption {
                      type = lib.types.port;
                      description = "Port of the email's provider IMAP server.";
                      default = 993;
                    };

                    username = lib.mkOption {
                      type = lib.types.str;
                      description = "Username used to login to the email's provider IMAP server.";
                      example = "userA@fastmail.com";
                    };

                    password = lib.mkOption {
                      description = ''
                        Password used to login to the email's provider IMAP server.

                        The password could be an "app password" like for [Fastmail](https://www.fastmail.help/hc/en-us/articles/360058752854-App-passwords)
                      '';
                      type = lib.types.submodule {
                        options = shb.contracts.secret.mkRequester {
                          mode = "0400";
                          owner = config.mailserver.vmailUserName;
                          restartUnits = [ "mbsync.service" ];
                        };
                      };
                    };

                    sslType = lib.mkOption {
                      description = "Connection security method.";
                      type = lib.types.enum [
                        "IMAPS"
                        "STARTTLS"
                      ];
                      default = "IMAPS";
                    };

                    timeout = lib.mkOption {
                      description = "Connect and data timeout.";
                      type = lib.types.int;
                      default = 120;
                    };

                    mapSpecialDrafts = lib.mkOption {
                      type = lib.types.str;
                      default = "Drafts";
                      description = ''
                        Drafts special folder name on far side.

                        You only need to change this if mbsync logs the following error:

                            Error: ... far side box Drafts cannot be opened
                      '';
                    };
                    mapSpecialSent = lib.mkOption {
                      type = lib.types.str;
                      default = "Sent";
                      description = ''
                        Sent special folder name on far side.

                        You only need to change this if mbsync logs the following error:

                            Error: ... far side box Sent cannot be opened
                      '';
                    };
                    mapSpecialTrash = lib.mkOption {
                      type = lib.types.str;
                      default = "Trash";
                      description = ''
                        Trash special folder name on far side.

                        You only need to change this if mbsync logs the following error:

                            Error: ... far side box Trash cannot be opened
                      '';
                    };
                    mapSpecialJunk = lib.mkOption {
                      type = lib.types.str;
                      default = "Junk";
                      description = ''
                        Junk special folder name on far side.

                        You only need to change this if mbsync logs the following error:

                            Error: ... far side box Junk cannot be opened
                      '';
                      example = "Spam";
                    };
                  };
                }
              );
            };
          };
        }
      );
    };

    smtpRelay = lib.mkOption {
      description = ''
        Proxy outgoing emails through an email provider.

        In short, this can help you avoid having your outgoing emails marked as spam.
        See the manual for a lengthier explanation.
      '';
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "Hostname of the email's provider SMTP server.";
              example = "smtp.fastmail.com";
            };

            port = lib.mkOption {
              type = lib.types.port;
              description = "Port of the email's provider SMTP server.";
              default = 587;
            };

            username = lib.mkOption {
              description = "Username used to login to the email's provider SMTP server.";
              type = lib.types.str;
            };

            password = lib.mkOption {
              description = ''
                Password used to login to the email's provider IMAP server.

                The password could be an "app password" like for [Fastmail](https://www.fastmail.help/hc/en-us/articles/360058752854-App-passwords)
              '';
              type = lib.types.submodule {
                options = shb.contracts.secret.mkRequester {
                  mode = "0400";
                  owner = config.services.postfix.user;
                  ownerText = "services.postfix.user";
                  restartUnits = [ "postfix.service" ];
                };
              };
            };
          };
        }
      );
    };

    ldap = lib.mkOption {
      description = ''
        LDAP Integration.

        Enabling this app will create a new LDAP configuration or update one that exists with
        the given host.
      '';
      default = { };
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            enable = lib.mkEnableOption "LDAP app.";

            host = lib.mkOption {
              type = lib.types.str;
              description = ''
                Host serving the LDAP server.
              '';
              default = "127.0.0.1";
            };

            port = lib.mkOption {
              type = lib.types.port;
              description = ''
                Port of the service serving the LDAP server.
              '';
              default = 389;
            };

            dcdomain = lib.mkOption {
              type = lib.types.str;
              description = "dc domain for ldap.";
              example = "dc=mydomain,dc=com";
            };

            account = lib.mkOption {
              type = lib.types.str;
              description = ''
                Select one account from those defined in `shb.mailserver.imapSync.accounts`
                to login with.

                Using LDAP, you can only connect to one account.
                This limitation could maybe be lifted, feel free to post an issue if you need this.
              '';
            };

            adminName = lib.mkOption {
              type = lib.types.str;
              description = "Admin user of the LDAP server.";
              default = "admin";
            };

            adminPassword = lib.mkOption {
              description = "LDAP server admin password.";
              type = lib.types.submodule {
                options = shb.contracts.secret.mkRequester {
                  mode = "0400";
                  owner = "nextcloud";
                  restartUnits = [ "dovecot.service" ];
                };
              };
            };

            userGroup = lib.mkOption {
              type = lib.types.str;
              description = "Group users must belong to to be able to use mails.";
              default = "mail_user";
            };
          };
        }
      );
    };

    backup = lib.mkOption {
      description = ''
        Backup emails, index and sieve.
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.backup.mkRequester {
          user = config.mailserver.vmailUserName;
          sourceDirectories = builtins.filter (x: x != null) [
            config.mailserver.indexDir
            config.mailserver.mailDirectory
            config.mailserver.sieveDirectory
          ];
          sourceDirectoriesText = ''
            [
              config.mailserver.indexDir
              config.mailserver.mailDirectory
              config.mailserver.sieveDirectory
            ]
          '';
        };
      };
    };

    backupDKIM = lib.mkOption {
      description = ''
        Backup dkim directory.
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.backup.mkRequester {
          user = config.services.rspamd.user;
          userText = "services.rspamd.user";
          sourceDirectories = builtins.filter (x: x != null) [
            config.mailserver.dkimKeyDirectory
          ];
          sourceDirectoriesText = ''
            [
              config.mailserver.dkimKeyDirectory
            ]
          '';
        };
      };
    };

    impermanence = lib.mkOption {
      description = ''
        Path to save when using impermanence setup.
      '';
      type = lib.types.attrsOf lib.types.str;
      default = {
        index = config.mailserver.indexDir;
        mail = config.mailserver.mailDirectory;
        sieve = config.mailserver.sieveDirectory;
        dkim = config.mailserver.dkimKeyDirectory;
      };
      defaultText = lib.literalExpression ''
        {
          index = config.mailserver.indexDir;
          mail = config.mailserver.mailDirectory;
          sieve = config.mailserver.sieveDirectory;
          dkim = config.mailserver.dkimKeyDirectory;
        }
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      mailserver = {
        enable = true;
        stateVersion = 3;
        fqdn = "${cfg.subdomain}.${cfg.domain}";
        domains = [ cfg.domain ];

        localDnsResolver = false;

        certificateScheme = "acme-nginx";
        enableImapSsl = true;
        enableSubmissionSsl = true;

        # Using / is needed for iOS mail.
        # Both following options are used to organize subfolders in subdirectories.
        hierarchySeparator = "/";
        useFsLayout = true;
      };

      services.postfix.config = {
        smtpd_tls_security_level = lib.mkForce "encrypt";
      };

      # Is probably needed for iOS mail.
      services.dovecot2.extraConfig = ''
        ssl_min_protocol = TLSv1.2
        ssl_cipher_list = HIGH:!aNULL:!MD5
      '';

      services.nginx = {
        enable = true;

        virtualHosts."${cfg.domain}" =
          let
            announce = pkgs.writeTextDir "config-v1.1.xml" ''
              <?xml version="1.0" encoding="UTF-8"?>
              <clientConfig version="1.1">
                <emailProvider id="${cfg.domain}">
                  <domain>${cfg.domain}</domain>
                  <displayName>${cfg.domain} Mailserver</displayName>

                  <!-- Incoming IMAP server -->
                  <incomingServer type="imap">
                    <hostname>${cfg.subdomain}.${cfg.domain}</hostname>
                    <port>993</port>
                    <socketType>SSL</socketType>
                    <authentication>password-cleartext</authentication>
                    <username>%EMAILADDRESS%</username>
                  </incomingServer>

                  <!-- Outgoing SMTP server -->
                  <outgoingServer type="smtp">
                    <hostname>${cfg.subdomain}.${cfg.domain}</hostname>
                    <port>465</port>
                    <socketType>STARTTLS</socketType>
                    <authentication>password-cleartext</authentication>
                    <username>%EMAILADDRESS%</username>
                  </outgoingServer>

                </emailProvider>
              </clientConfig>
            '';
          in
          {
            forceSSL = true; # Redirect HTTP → HTTPS
            root = "/var/www"; # Dummy root
            locations."/.well-known/autoconfig/mail/" = {
              alias = "${announce}/";
              extraConfig = ''
                default_type application/xml;
              '';
            };
          };
      };
    })
    (lib.mkIf (cfg.enable && cfg.adminUsername != null) {
      assertions = [
        {
          assertion = cfg.adminPassword != null;
          message = "`shb.mailserver.adminPassword` must be not null if `shb.mailserver.adminUsername` is not null.";
        }
      ];

      mailserver = {
        # To create the password hashes, use:
        # nix run nixpkgs#mkpasswd -- --run 'mkpasswd -s'
        loginAccounts = {
          "${cfg.adminUsername}@${cfg.domain}" = {
            hashedPasswordFile = cfg.adminPassword.result.path;
            aliases = [ "postmaster@${cfg.domain}" ];
          };
        };
      };
    })
    (lib.mkIf (cfg.enable && cfg.ldap != null) {
      assertions = [
        {
          assertion = cfg.adminUsername == null;
          message = "`shb.mailserver.adminUsername` must be null `shb.mailserver.ldap` integration is set.";
        }
      ];

      shb.lldap.ensureGroups = {
        ${cfg.ldap.userGroup} = { };
      };

      mailserver = {
        ldap = {
          enable = true;
          uris = [
            "ldap://${cfg.ldap.host}:${toString cfg.ldap.port}"
          ];
          searchBase = "ou=people,${cfg.ldap.dcdomain}";
          searchScope = "sub";
          bind = {
            dn = "uid=${cfg.ldap.adminName},ou=people,${cfg.ldap.dcdomain}";
            passwordFile = cfg.ldap.adminPassword.result.path;
          };
          # Note that nixos simple mailserver sets auth_bind=yes
          # which means authentication binds are used.
          # https://doc.dovecot.org/2.3/configuration_manual/authentication/ldap_bind/#authentication-ldap-bind
          dovecot =
            let
              filter = "(&(objectClass=inetOrgPerson)(mail=%{user})(memberOf=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain}))";
            in
            {
              passAttrs = "user=user";
              passFilter = filter;
              userAttrs = lib.concatStringsSep "," [
                "=home=${config.mailserver.mailDirectory}/${cfg.ldap.account}/%u"
                # "mail=maildir:${config.mailserver.mailDirectory}/${cfg.ldap.account}/%u/mail"
                "uid=${config.mailserver.vmailUserName}"
                "gid=${config.mailserver.vmailGroupName}"
              ];
              userFilter = filter;
            };
          postfix = {
            filter = "(&(objectClass=inetOrgPerson)(mail=%s)(memberOf=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain}))";
            mailAttribute = "mail";
            uidAttribute = "mail";
          };
        };
      };
    })
    (lib.mkIf (cfg.enable && cfg.imapSync != null) {
      systemd.services.mbsync =
        let
          configFile =
            let
              mkAccount = name: acct: ''
                # ${name} account

                IMAPAccount ${name}
                Host ${acct.host}
                Port ${toString acct.port}
                User ${acct.username}
                PassCmd "cat ${acct.password.result.path}"
                TLSType ${acct.sslType}
                AuthMechs LOGIN
                Timeout ${toString acct.timeout}

                IMAPStore ${name}-remote
                Account ${name}

                MaildirStore ${name}-local
                INBOX ${config.mailserver.mailDirectory}/${name}/${acct.username}/mail/
                # Maps subfolders on far side to actual subfolders on disk.
                # The other option is Maildir++ but then the mailserver.hierarchySeparator must be set to a dot '.'
                SubFolders Verbatim
                Path ${config.mailserver.mailDirectory}/${name}/${acct.username}/mail/

                Channel ${name}-main
                Far :${name}-remote:
                Near :${name}-local:
                Patterns * !Drafts !Sent !Trash !Junk !${acct.mapSpecialDrafts} !${acct.mapSpecialSent} !${acct.mapSpecialTrash} !${acct.mapSpecialJunk}
                Create Both
                Expunge Both
                SyncState *
                Sync All
                CopyArrivalDate yes  # Preserve date from incoming message.

                Channel ${name}-drafts
                Far :${name}-remote:"${acct.mapSpecialDrafts}"
                Near :${name}-local:"Drafts"
                Create Both
                Expunge Both
                SyncState *
                Sync All
                CopyArrivalDate yes  # Preserve date from incoming message.

                Channel ${name}-sent
                Far :${name}-remote:"${acct.mapSpecialSent}"
                Near :${name}-local:"Sent"
                Create Both
                Expunge Both
                SyncState *
                Sync All
                CopyArrivalDate yes  # Preserve date from incoming message.

                Channel ${name}-trash
                Far :${name}-remote:"${acct.mapSpecialTrash}"
                Near :${name}-local:"Trash"
                Create Both
                Expunge Both
                SyncState *
                Sync All
                CopyArrivalDate yes  # Preserve date from incoming message.

                Channel ${name}-junk
                Far :${name}-remote:"${acct.mapSpecialJunk}"
                Near :${name}-local:"Junk"
                Create Both
                Expunge Both
                SyncState *
                Sync All
                CopyArrivalDate yes  # Preserve date from incoming message.

                Group ${name}
                Channel ${name}-main
                Channel ${name}-drafts
                Channel ${name}-sent
                Channel ${name}-trash
                Channel ${name}-junk

                # END ${name} account
              '';

            in
            pkgs.writeText "mbsync.conf" (
              lib.concatStringsSep "\n" (lib.mapAttrsToList mkAccount cfg.imapSync.accounts)
            );
        in
        {
          description = "Sync mailbox";
          serviceConfig = {
            Type = "oneshot";
            User = config.mailserver.vmailUserName;
          };
          script =
            let
              debug = if cfg.imapSync.debug then "-V" else "";
            in
            ''
              ${pkgs.isync}/bin/mbsync --all ${debug} --config ${configFile}
            '';
        };

      systemd.tmpfiles.rules =
        let
          mkAccount =
            name: acct:
            # The equal sign makes sure parent directories have the corret user and group too.
            [
              "d '${config.mailserver.mailDirectory}/${name}' 0750 ${config.mailserver.vmailUserName} ${config.mailserver.vmailGroupName} - -"
              "d '${config.mailserver.mailDirectory}/${name}/${acct.username}' 0750 ${config.mailserver.vmailUserName} ${config.mailserver.vmailGroupName} - -"
            ];
        in
        lib.flatten (lib.mapAttrsToList mkAccount cfg.imapSync.accounts);

      systemd.timers.mbsync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = cfg.imapSync.syncTimer;
          OnUnitActiveSec = cfg.imapSync.syncTimer;
        };
      };
    })
    (lib.mkIf (cfg.enable && cfg.smtpRelay != null) (
      let
        url = "[${cfg.smtpRelay.host}]:${toString cfg.smtpRelay.port}";
      in
      {
        assertions = [
          {
            assertion = lib.hasAttr cfg.adminPassword != null;
            message = "`shb.mailserver.adminPassword` must be not null if `shb.mailserver.adminUsername` is not null.";
          }
        ];

        # Inspiration from https://www.brull.me/postfix/debian/fastmail/2016/08/16/fastmail-smtp.html
        services.postfix = {
          settings.main = {
            relayhost = [ url ];
            smtp_sasl_auth_enable = "yes";
            smtp_sasl_password_maps = "texthash:/run/secrets/postfix/postfix-smtp-relay-password";
            smtp_sasl_security_options = "noanonymous";
            smtp_use_tls = "yes";
          };
        };

        systemd.services.postfix-pre = {
          script = shb.replaceSecrets {
            userConfig = {
              inherit url;
              inherit (cfg.smtpRelay) username;
              password.source = cfg.smtpRelay.password.result.path;
            };
            generator =
              name:
              {
                url,
                username,
                password,
              }:
              pkgs.writeText "postfix-smtp-relay-password" ''
                ${url} ${username}:${password}
              '';
            resultPath = "/run/secrets/postfix/postfix-smtp-relay-password";
            user = config.services.postfix.user;
          };
          serviceConfig.Type = "oneshot";
          wantedBy = [ "multi-user.target" ];
          before = [ "postfix.service" ];
          requiredBy = [ "postfix.service" ];
        };
      }
    ))
  ];
}
