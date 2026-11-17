{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
  makeWrapper,
  makeDesktopItem,
  jdk25,
}:

let
  version = "0.2.19";

  # Keep the upstream executable intact; the FHS environment also runs the
  # unpatched game/preparer binaries downloaded later by the launcher.
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "horizon-launcher-unwrapped";
    inherit version;
    src = fetchurl {
      url = "https://github.com/horizon-rust/horizon/releases/download/launcher%40${version}/horizon-launcher-linux-x86_64.tar.gz";
      hash = "sha256-hRV0zxKPu/5seNFd3kdLu6lJzHfbUo94yZKmnvVXBW8=";
    };
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 horizon-launcher $out/libexec/horizon-launcher
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "horizon-launcher";
    desktopName = "Horizon";
    genericName = "Game launcher";
    comment = "Install, prepare and play Horizon, Minecraft rewritten in Rust";
    exec = "horizon-launcher";
    icon = "horizon";
    categories = [ "Game" ];
    startupWMClass = "horizon-launcher";
  };
in
buildFHSEnv {
  pname = "horizon-launcher";
  inherit version;

  targetPkgs = pkgs: with pkgs; [
    jdk25
    python3
    xdg-utils
    glib
    fontconfig
    freetype
    libxkbcommon
    wayland
    libx11
    libxcb
    libxcursor
    libxrandr
    libxi
    libxinerama
    libxext
    libxrender
    vulkan-loader
    libGL
    alsa-lib
    alsa-plugins
    libpulseaudio
    udev
    openssl
    zlib
    stdenv.cc.cc.lib
  ];
  multiPkgs = null;

  runScript = "${unwrapped}/libexec/horizon-launcher";
  profile = ''
    export JAVA_HOME=${jdk25}
    export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
  '';

  nativeBuildInputs = [ makeWrapper ];
  extraInstallCommands = ''
    # User-created shortcuts must start this environment too.
    wrapProgram $out/bin/horizon-launcher \
      --set HORIZON_LAUNCHER_DESKTOP_EXEC $out/bin/horizon-launcher
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/* $out/share/applications/
    install -Dm644 ${./icon.svg} $out/share/icons/hicolor/scalable/apps/horizon.svg
  '';

  passthru = { inherit unwrapped; };
  meta = {
    description = "Launcher for Horizon, a native Rust implementation of Minecraft";
    homepage = "https://github.com/horizon-rust/horizon";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "horizon-launcher";
  };
}
