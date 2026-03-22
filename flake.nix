{
  description = "yolo-ng - Text Board Miniapp for Logos App";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder/4fa6816bc065f974169150448c066ef4047a2e43";
    nixpkgs.follows = "logos-module-builder/nixpkgs";
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

          headless-plugin = pkgs.stdenv.mkDerivation {
            pname = "yolo_ng-plugin";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
            ];

            buildInputs = [
              pkgs.qt6.qtbase
              pkgs.qt6.qtremoteobjects
            ];

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
            ];

            configureFlags = [
              "-DLOGOS_CPP_SDK_ROOT=${logosSdk}"
              "-DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}"
              "-DBUILD_UI_PLUGIN=ON"
            ];

            buildInputs = [
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qtremoteobjects
            ];

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

            dontWrapQtApps = true;
          };

          lgx = pkgs.runCommand "yolo-ng.lgx" {} ''
            mkdir -p $out/yolo_ng

            # Headless module plugin
            cp ${headless-plugin}/lib/yolo_ng_plugin* $out/yolo_ng/ 2>/dev/null || true

            # UI plugin
            cp ${ui-plugin}/lib/libyolo_ng_ui* $out/yolo_ng/ 2>/dev/null || true

            # QML files
            mkdir -p $out/yolo_ng/qml
            cp -r ${./qml}/* $out/yolo_ng/qml/

            # Metadata
            cp ${./metadata.json} $out/yolo_ng/metadata.json
            cp ${./manifest.json} $out/yolo_ng/manifest.json
            cp ${./ui_metadata.json} $out/yolo_ng/ui_metadata.json

            # Create the .lgx archive
            cd $out
            tar czf $out/yolo-ng.lgx -C $out yolo_ng
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
