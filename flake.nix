{
  description = "yolo-ng - Text Board Miniapp for Logos App";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder/4fa6816bc065f974169150448c066ef4047a2e43";
    nixpkgs.url = "github:NixOS/nixpkgs/bfc1b8a4574108ceef22f02bafcf6611380c100d";
    logos-cpp-sdk = {
      url = "github:logos-co/logos-cpp-sdk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    logos-liblogos = {
      url = "github:logos-co/logos-liblogos";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-cpp-sdk.follows = "logos-cpp-sdk";
    };
  };

  outputs = { self, logos-module-builder, nixpkgs, logos-cpp-sdk, logos-liblogos, ... }:
    let
      moduleOutputs = logos-module-builder.lib.mkLogosModule {
        src = ./.;
        configFile = ./module.yaml;
      };
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        logosSdk = logos-cpp-sdk.packages.${system}.default;
        logosLiblogos = logos-liblogos.packages.${system}.default;
      });
    in
    moduleOutputs // {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos }:
        let
          base = moduleOutputs.packages.${pkgs.system} or {};

          commonCmakeFlags = [
            "-DLOGOS_CPP_SDK_ROOT=${logosSdk}"
            "-DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}"
          ];

          headlessBuildInputs = [
            pkgs.qt6.qtdeclarative
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
          ];

          uiBuildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtdeclarative
            pkgs.qt6.qtremoteobjects
          ];

          headless-plugin = pkgs.stdenv.mkDerivation {
            pname = "yolo_ng-plugin";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
              pkgs.patchelf
            ];

            buildInputs = headlessBuildInputs;

            cmakeFlags = commonCmakeFlags ++ [
              "-DBUILD_MODULE=ON"
              "-DBUILD_UI_PLUGIN=OFF"
              "-GNinja"
            ];

            buildPhase = ''
              runHook preBuild
              ninja yolo_ng_plugin -j''${NIX_BUILD_CORES:-1}
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib
              cp yolo_ng_plugin${pkgs.stdenv.hostPlatform.extensions.sharedLibrary} $out/lib/ 2>/dev/null || true
              runHook postInstall
            '';

            postFixup = ''
              for f in $out/lib/*.so; do
                patchelf --set-rpath "/tmp/logos-liblogos-merged/lib:${pkgs.lib.makeLibraryPath headlessBuildInputs}:\$ORIGIN" "$f"
              done
            '';

            dontWrapQtApps = true;
          };

          ui-plugin = pkgs.stdenv.mkDerivation {
            pname = "yolo_ng-ui-plugin";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
              pkgs.qt6.wrapQtAppsHook
              pkgs.patchelf
            ];

            configureFlags = [
              "-DLOGOS_CPP_SDK_ROOT=${logosSdk}"
              "-DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}"
              "-DBUILD_UI_PLUGIN=ON"
            ];

            buildInputs = uiBuildInputs;

            cmakeFlags = commonCmakeFlags ++ [
              "-DBUILD_UI_PLUGIN=ON"
            ];

            buildPhase = ''
              runHook preBuild
              cmake --build . --target yolo_ng_ui -j''${NIX_BUILD_CORES:-1} -- VERBOSE=1
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib
              cp libyolo_ng_ui${pkgs.stdenv.hostPlatform.extensions.sharedLibrary} $out/lib/
              runHook postInstall
            '';

            postFixup = ''
              for f in $out/lib/*.so; do
                patchelf --set-rpath "/tmp/logos-liblogos-merged/lib:${pkgs.lib.makeLibraryPath uiBuildInputs}:\$ORIGIN" "$f"
              done
            '';

            dontWrapQtApps = true;
          };

          lgx = pkgs.runCommand "yolo-ng.lgx" {
            nativeBuildInputs = [ pkgs.gnutar ];
          } ''
            staging=$(mktemp -d)

            # Headless module
            mkdir -p $staging/modules/yolo_ng
            cp ${headless-plugin}/lib/yolo_ng_plugin.so $staging/modules/yolo_ng/yolo_ng_plugin.so
            cp ${./manifest.json} $staging/modules/yolo_ng/manifest.json

            # UI plugin (rename lib prefix off)
            mkdir -p $staging/plugins/yolo_ng_ui
            cp ${ui-plugin}/lib/libyolo_ng_ui.so $staging/plugins/yolo_ng_ui/yolo_ng_ui.so
            cp ${./ui_metadata.json} $staging/plugins/yolo_ng_ui/manifest.json
            cp -r ${./qml} $staging/plugins/yolo_ng_ui/qml

            # Install script
            cat > $staging/install.sh <<'INSTALL'
            #!/usr/bin/env bash
            set -e
            SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
            LOGOS_DIR="''${LOGOS_DIR:-$HOME/.local/share/Logos/LogosAppNix}"
            echo "Installing yolo-ng to $LOGOS_DIR..."
            install -Dm755 "$SCRIPT_DIR/modules/yolo_ng/yolo_ng_plugin.so" "$LOGOS_DIR/modules/yolo_ng/yolo_ng_plugin.so"
            install -Dm644 "$SCRIPT_DIR/modules/yolo_ng/manifest.json" "$LOGOS_DIR/modules/yolo_ng/manifest.json"
            install -Dm755 "$SCRIPT_DIR/plugins/yolo_ng_ui/yolo_ng_ui.so" "$LOGOS_DIR/plugins/yolo_ng_ui/yolo_ng_ui.so"
            install -Dm644 "$SCRIPT_DIR/plugins/yolo_ng_ui/manifest.json" "$LOGOS_DIR/plugins/yolo_ng_ui/manifest.json"
            cp -rf "$SCRIPT_DIR/plugins/yolo_ng_ui/qml" "$LOGOS_DIR/plugins/yolo_ng_ui/"
            echo "Done. Restart LogosApp to load yolo-ng."
            INSTALL
            chmod +x $staging/install.sh

            # Package as gzipped tarball
            mkdir -p $out
            tar czf $out/yolo-ng.lgx -C $staging .
          '';

        in
        base // {
          ui = pkgs.runCommand "yolo_ng-ui" {} ''
            mkdir -p $out/qml
            cp -r ${./qml}/* $out/qml/
          '';
          inherit headless-plugin ui-plugin lgx;
        }
      );
    };
}
