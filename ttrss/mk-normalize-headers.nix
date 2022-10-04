{ TtrssPHPNormalizeHeaders
}:
{ name
, configDir ? "/etc/php"
, configFile ? "normalize-headers.php"
}:
rec {
  inherit name configDir configFile;

  pkg = TtrssPHPNormalizeHeaders {
    inherit configDir configFile;
  };
  type = "fileset";
}
