{
  writeShellApplication,
  playwright-test,
  playwright-driver,
  python3,
  makeFontsConf,
  dejavu_fonts,
  emptyDirectory,
  manual,
}:
writeShellApplication {
  name = "manual-visual-tests";
  runtimeInputs = [
    playwright-test
    python3
  ];
  runtimeEnv = {
    SHB_MANUAL_HTML = "${manual}/share/doc/selfhostblocks";
    PLAYWRIGHT_BROWSERS_PATH = playwright-driver.browsers-chromium;
    FONTCONFIG_FILE = makeFontsConf {
      fontDirectories = [ dejavu_fonts ];
      impureFontDirectories = [ ];
      includes = [ ];
    };
    # makeFontsConf also searches XDG_DATA_HOME/fonts; exclude user-installed fonts.
    XDG_DATA_HOME = emptyDirectory;
  };
  text = ''
    cd test/manual
    exec playwright "$@"
  '';
  meta.platforms = [ "x86_64-linux" ];
}
