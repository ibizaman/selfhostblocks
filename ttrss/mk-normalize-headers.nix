{ TtrssPHPNormalizeHeaders
}:
{ name
, configDir ? "/etc/php"
, configFile ? "normalize-headers.php"

, debug ? false
}:
rec {
  inherit name configDir configFile;

  pkg = TtrssPHPNormalizeHeaders {
    inherit configDir configFile;
    inherit debug;
  };
  type = "fileset";
}
