{ stdenv
, pkgs
, lib
}:

with lib;
with lib.lists;
with lib.attrsets;
rec {
  tmpFilesFromDirectories = user: group: d:
    let
      wrapTmpfiles = dir: mode: "d '${dir}' ${mode} ${user} ${group} - -";
    in
      mapAttrsToList wrapTmpfiles d;

  systemd = {
    mkService = {name, content, timer ? null}: stdenv.mkDerivation {
      inherit name;

      src = pkgs.writeTextDir "${name}.service" content;
      timerSrc = pkgs.writeTextDir "${name}.timer" timer;

      installPhase = ''
        mkdir -p $out/etc/systemd/system
        cp $src/*.service $out/etc/systemd/system
      '' + (if timer == null then "" else ''
        cp $timerSrc/*.timer $out/etc/systemd/system
      '');
    };

  };

  mkConfigFile = {dir, name, content}: stdenv.mkDerivation rec {
    inherit name;

    src = pkgs.writeTextDir name content;

    buildCommand = ''
      mkdir -p $out
      cp ${src}/${name} $out/${name}

      echo "${dir}" > $out/.dysnomia-targetdir

      cat > $out/.dysnomia-fileset <<FILESET
        symlink $out/${name}
        target .
      FILESET
    '';

  };

  dnsmasqConfig = domain: subdomains:
    ''
    ${concatMapStringsSep "\n" (x: "address=/${x}.${domain}/127.0.0.1") subdomains}
    domain=${domain}
    '';

  keyEnvironmentFile = path: "EnvironmentFile=/run/keys/${path}";
  keyEnvironmentFiles = names: concatMapStrings (path: "${keyEnvironmentFile path}\n") (attrValues names);
  keyServiceDependencies = names: concatMapStringsSep " " (path: "${path}-key.service") (attrValues names);

  recursiveMerge = attrList:
    let f = attrPath:
          zipAttrsWith (n: values:
            if all isList values then
              concatLists values
            else if all isAttrs values then
              f (attrPath ++ [n]) values
            else
              last values
          );
    in f [] attrList;

  getTarget = distribution: name: builtins.elemAt (builtins.getAttr name distribution) 0;

  getDomain = distribution: name: (getTarget distribution name).containers.system.domain;

  unitDepends = verb: dependsOn:
    let
      withSystemdUnitFile = filter (hasAttr "systemdUnitFile") (attrValues dependsOn);

      systemdUnitFiles = map (x: x.systemdUnitFile) withSystemdUnitFile;
    in
      if length systemdUnitFiles == 0 then
        ""
      else
        "${verb}=${concatStringsSep " " systemdUnitFiles}";
}
