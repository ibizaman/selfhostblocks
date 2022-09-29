{ stdenv
, pkgs
, utils
}:
{ configDir ? "/etc/php"
, configFile ? "normalize-headers.php"
}:

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = ''
  <?php
  
  $trustedProxies = array(
    '127.0.0.1',
    '@'
  );
  
  # phpinfo(INFO_VARIABLES);

  if (isSet($_SERVER['REMOTE_ADDR'])) {
  
    $remote = $_SERVER['REMOTE_ADDR'];
  
    $allowedHeaders = array(
      'HTTP_X_FORWARDED_FOR' => 'REMOTE_ADDR',
      'HTTP_X_REAL_IP' => 'REMOTE_HOST',
      'HTTP_X_FORWARDED_PORT' => 'REMOTE_PORT',
      'HTTP_X_FORWARDED_HTTPS' => 'HTTPS',
      'HTTP_X_FORWARDED_SERVER_ADDR' => 'SERVER_ADDR',
      'HTTP_X_FORWARDED_SERVER_NAME' => 'SERVER_NAME',
      'HTTP_X_FORWARDED_SERVER_PORT' => 'SERVER_PORT',
      'HTTP_X_FORWARDED_PREFERRED_USERNAME' => 'REMOTE_USER',
    );
  
    if(in_array($remote, $trustedProxies)) {
      foreach($allowedHeaders as $header => $serverVar) {
        if(isSet($_SERVER[$header])) {
          if(isSet($_SERVER[$serverVar])) {
            $_SERVER["ORIGINAL_$serverVar"] = $_SERVER[$serverVar];
          }
  
          $_SERVER[$serverVar] = explode(',', $_SERVER[$header], 2)[0];
        }
      }
    }
  
  }

  # trigger_error(print_r($_SERVER, true), E_USER_WARNING);
  
  '';
}
