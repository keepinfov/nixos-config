# pkgs/materialgram/default.nix - Prebuilt materialgram (Telegram Desktop fork)
#
# Uses the official GitHub release tarball instead of building tdesktop from
# source (nixpkgs' materialgram rebuilds the whole telegram-desktop on every
# bump). Updating: bump `version` and `hash` below, that's it - no compile.
{
  lib,
  stdenv,
  fetchurl,
  zstd,
  makeWrapper,
  desktop-file-utils,
  librsvg,
  wrapGAppsHook3,
  cairo,
  pango,
  glib,
  freetype,
  fontconfig,
  gtk3,
  webkitgtk_4_1,
  geoclue2,
  glib-networking,
  pulseaudio,
  pipewire,
  alsa-lib,
  libva,
  libvdpau,
  wayland,
  dbus,
  libGL,
  libdrm,
  libgbm,
  udev,
  libX11,
  libxkbcommon,
  libxcb,
  xcbutilcursor,
  xcbutilkeysyms,
  xcbutilimage,
  xcbutilrenderutil,
  xkeyboard_config,
}:

stdenv.mkDerivation rec {
  pname = "materialgram";
  version = "7.3.1.1";

  src = fetchurl {
    url = "https://github.com/kukuruzka165/materialgram/releases/download/v${version}/materialgram-v${version}.tar.zst";
    hash = "sha256-UOC9bI5CPY1PK7mftFQWLKW21azrD6EkAEn03DPdNAU=";
  };

  # Upstream binary ships unstripped with its own crash handler sections;
  # keep it byte-identical to the release artifact.
  dontStrip = true;

  # IMPORTANT: do NOT autoPatchelf/patchelf this binary. Rewriting
  # PT_INTERP/RUNPATH inside the ~420MB upstream executable corrupts it
  # and causes a SIGSEGV at entry. NixOS provides /lib64/ld-linux-x86-64.so.2,
  # so the pristine binary runs and all runtime libs (hard DT_NEEDED as well
  # as the dlopen()ed ones that upstream's implib-gen stubs hard-assert on)
  # are supplied through the wrapper's LD_LIBRARY_PATH below.
  nativeBuildInputs = [
    zstd
    makeWrapper
    librsvg
    wrapGAppsHook3
  ];

  buildInputs = [ gtk3 ];

  # GTK is dlopen()ed, so apply gappsWrapperArgs ourselves inside makeWrapper.
  dontWrapGApps = true;

  # Tarball has FHS layout (usr/bin, usr/share); keep unpack dir as-is.
  sourceRoot = ".";

  unpackCmd = "tar --zstd -xf $src";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/. $out/

    # Keep the upstream icon name/desktop ID so existing launchers and dock
    # favorites pick up our icon. Ship SVG plus PNGs for raster-only consumers.
    install -Dm644 ${./icon.svg} \
      $out/share/icons/hicolor/scalable/apps/io.github.kukuruzka165.materialgram.svg
    for size in 16 32 48 64 128 256 512; do
      iconDir="$out/share/icons/hicolor/''${size}x''${size}/apps"
      mkdir -p "$iconDir"
      rsvg-convert --width "$size" --height "$size" \
        --output "$iconDir/io.github.kukuruzka165.materialgram.png" ${./icon.svg}
    done

    # Keep the executable's basename for Qt's materialgram data directory.
    # The upstream external-updater marker disables self-updates AND the
    # per-binary hash in the desktop ID, so GNOME matches our installed icon.
    mkdir -p $out/libexec/externalupdater.d
    mv $out/bin/materialgram $out/libexec/materialgram
    echo "$out/libexec/materialgram" > $out/libexec/externalupdater.d/nix

    substituteInPlace $out/share/applications/io.github.kukuruzka165.materialgram.desktop \
      --replace-fail 'Exec=materialgram' "Exec=$out/bin/materialgram"
    # Upstream D-Bus activation unit hardcodes /usr/bin/materialgram.
    substituteInPlace $out/share/dbus-1/services/io.github.kukuruzka165.materialgram.service \
      --replace-fail /usr/bin/materialgram $out/bin/materialgram
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/libexec/materialgram $out/bin/materialgram \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ desktop-file-utils ]} \
      --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules \
      --set XKB_CONFIG_ROOT ${xkeyboard_config}/share/X11/xkb \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          cairo
          pango
          glib
          freetype
          fontconfig
          gtk3
          libGL
          libdrm
          libgbm
          udev
          libX11
          libxkbcommon
          webkitgtk_4_1
          geoclue2
          pulseaudio
          pipewire
          alsa-lib
          libva
          libvdpau
          wayland
          dbus.lib
          libxcb
          xcbutilcursor
          xcbutilkeysyms
          xcbutilimage
          xcbutilrenderutil
        ]
      }
  '';

  meta = {
    description = "Telegram Desktop fork with Material Design and some improvements";
    longDescription = ''
      Telegram Desktop fork with Material Design and other improvements,
      based on the Telegram API and the MTProto secure protocol.
      Installed from upstream prebuilt binaries to avoid rebuilding
      telegram-desktop from source on every update.
    '';
    homepage = "https://github.com/kukuruzka165/materialgram";
    changelog = "https://github.com/kukuruzka165/materialgram/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "materialgram";
  };
}
