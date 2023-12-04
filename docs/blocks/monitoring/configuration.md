# Configuration {#blocks-monitoring-configuration}

```nix
shb.monitoring = {
  enable = true;
  subdomain = "grafana";
  inherit domain;
  contactPoints = [ "me@example.com" ];
  adminPasswordFile = config.sops.secrets."monitoring/admin_password".path;
  secretKeyFile = config.sops.secrets."monitoring/secret_key".path;
};

sops.secrets."monitoring/admin_password" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "grafana";
  group = "grafana";
  restartUnits = [ "grafana.service" ];
};
sops.secrets."monitoring/secret_key" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "grafana";
  group = "grafana";
  restartUnits = [ "grafana.service" ];
};
```

With that, Grafana, Prometheus, Loki and Promtail are setup! You can access `Grafana` at
`grafana.example.com` with user `admin` and password ``.

I recommend adding a STMP server configuration so you receive alerts by email:

```nix
shb.monitoring.smtp = {
  from_address = "grafana@$example.com";
  from_name = "Grafana";
  host = "smtp.mailgun.org";
  port = 587;
  username = "postmaster@mg.example.com";
  passwordFile = config.sops.secrets."monitoring/smtp".path;
};

sops.secrets."monitoring/secret_key" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "grafana";
  group = "grafana";
  restartUnits = [ "grafana.service" ];
};
```

Since all logs are now stored in Loki, you can probably reduce the systemd journal retention
time with:

```nix
# See https://www.freedesktop.org/software/systemd/man/journald.conf.html#SystemMaxUse=
services.journald.extraConfig = ''
SystemMaxUse=2G
SystemKeepFree=4G
SystemMaxFileSize=100M
MaxFileSec=day
'';
```
