{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      sources = pkgs.callPackage ./_sources/generated.nix {};
      inherit (sources) lution;
      src = lution.src;

      pythonEnv = pkgs.python3.withPackages (ps:
        with ps; [
          streamlit
          pygithub
          rich
          pyside6
          toml
        ]);

      patchedSrc = pkgs.stdenv.mkDerivation {
        name = "lution-src-patched";
        inherit src;
        patches = [./patches/fix-logging.patch ./patches/fix-cache.patch];
        phases = ["unpackPhase" "patchPhase" "installPhase"];

        installPhase = ''
          cp -r . $out
        '';
      };

      lutionScript = pkgs.writeShellScriptBin "lution" ''
        cd "${patchedSrc}/src/Lution"
        mkdir -p ~/.local/state/lution
        exec ${pythonEnv}/bin/python3 "${patchedSrc}/src/Lution/launch.py" "$@"
      '';

      lutionDesktopItem = pkgs.makeDesktopItem {
        name = "lution";
        exec = "lution";
        icon = "lution";
        comment = "literally a bloxstrap clone 4 linux";
        desktopName = "Lution";
        categories = ["Game" "Utility"];
        terminal = false;
      };
    in {
      packages.default = pkgs.stdenv.mkDerivation {
        name = "lution";
        nativeBuildInputs = [pkgs.makeWrapper];
        buildInputs = [lutionScript pythonEnv];
        phases = ["installPhase"];
        version = lution.version;

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/share/applications
          mkdir -p $out/share/icons/hicolor/256x256/apps

          cp ${lutionScript}/bin/lution $out/bin/lution
          cp ${lutionDesktopItem}/share/applications/*.desktop $out/share/applications/
          cp ${patchedSrc}/src/Lution/files/lution1.png $out/share/icons/hicolor/256x256/apps/lution.png

          wrapProgram $out/bin/lution \
            --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.git]} \
            --prefix PATH : ${pythonEnv}/bin \
            --set QT_QPA_PLATFORM xcb \
            --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [pkgs.libGL pkgs.libxkbcommon pkgs.libx11]}
        '';
      };

      devShells.default = pkgs.mkShell {
        name = "lution";
        description = "Lution, the Sober bootstrapper";
        packages =
          [
            pkgs.git
            pkgs.python3

            pkgs.libGL
            pkgs.libxkbcommon
            pkgs.libx11

            pkgs.nvfetcher

            pkgs.nixd
            pkgs.alejandra
          ]
          ++ (with pkgs.python3Packages; [
            streamlit
            pygithub
            rich
            pyside6
            toml
          ]);
      };
    });
}
