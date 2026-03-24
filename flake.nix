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
    logos-package = {
      url = "github:logos-co/logos-package";
    };
  };

  outputs = { self, logos-module-builder, nixpkgs, logos-cpp-sdk, logos-liblogos, logos-package, ... }:
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
        lgxTool = logos-package.packages.${system}.lgx;
      });
    in
    moduleOutputs // {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos, lgxTool }:
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
                patchelf --set-rpath "${logosLiblogos}/lib:${pkgs.lib.makeLibraryPath headlessBuildInputs}" "$f"
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
                patchelf --set-rpath "${logosLiblogos}/lib:${pkgs.lib.makeLibraryPath uiBuildInputs}" "$f"
              done
            '';

            dontWrapQtApps = true;
          };

          patchManifest = name: metadataFile: ''
            python3 - ${name}.lgx ${metadataFile} <<'PY'
            import json, sys, tarfile, io

            lgx_path = sys.argv[1]
            with open(sys.argv[2]) as f:
                metadata = json.load(f)

            built_variants = {'linux-x86_64-dev', 'linux-amd64-dev'}

            with tarfile.open(lgx_path, 'r:gz') as tar:
                members = [(m, tar.extractfile(m).read() if m.isfile() else None) for m in tar.getmembers()]

            patched = []
            for member, data in members:
                if member.name == 'manifest.json':
                    manifest = json.loads(data)
                    for key in ('name', 'version', 'description', 'author', 'type', 'category', 'dependencies', 'capabilities', 'manifestVersion'):
                        if key in metadata:
                            manifest[key] = metadata[key]
                    if 'main' in manifest and isinstance(manifest['main'], dict):
                        manifest["main"] = {k.replace("-dev", ""): v for k, v in manifest["main"].items() if k in built_variants}
                    data = json.dumps(manifest, indent=2).encode()
                    member.size = len(data)
                patched.append((member, data))

            with tarfile.open(lgx_path, 'w:gz', format=tarfile.GNU_FORMAT) as tar:
                for member, data in patched:
                    if data is not None:
                        tar.addfile(member, io.BytesIO(data))
                    else:
                        tar.addfile(member)
            PY
          '';

          lgx-core = pkgs.runCommand "yolo-ng-core.lgx" {
            nativeBuildInputs = [ lgxTool pkgs.python3 ];
          } ''
            lgx create yolo-ng-core

            mkdir -p variant-files
            cp ${headless-plugin}/lib/yolo_ng_plugin.so variant-files/

            lgx add yolo-ng-core.lgx --variant linux-x86_64-dev --files ./variant-files --main yolo_ng_plugin.so -y
            lgx add yolo-ng-core.lgx --variant linux-amd64-dev --files ./variant-files --main yolo_ng_plugin.so -y

            lgx verify yolo-ng-core.lgx

            ${patchManifest "yolo-ng-core" ./manifest.json}

            mkdir -p $out
            cp yolo-ng-core.lgx $out/yolo-ng-core.lgx
          '';

          lgx-ui = pkgs.runCommand "yolo-ng-ui.lgx" {
            nativeBuildInputs = [ lgxTool pkgs.python3 ];
          } ''
            lgx create yolo-ng-ui

            mkdir -p variant-files
            cp ${ui-plugin}/lib/libyolo_ng_ui.so variant-files/yolo_ng_ui.so

            lgx add yolo-ng-ui.lgx --variant linux-x86_64-dev --files ./variant-files --main yolo_ng_ui.so -y
            lgx add yolo-ng-ui.lgx --variant linux-amd64-dev --files ./variant-files --main yolo_ng_ui.so -y

            lgx verify yolo-ng-ui.lgx

            ${patchManifest "yolo-ng-ui" ./ui_metadata.json}

            mkdir -p $out
            cp yolo-ng-ui.lgx $out/yolo-ng-ui.lgx
          '';

          lgx = pkgs.symlinkJoin {
            name = "yolo-ng-lgx";
            paths = [ lgx-core lgx-ui ];
          };

        in
        base // {
          ui = pkgs.runCommand "yolo_ng-ui" {} ''
            mkdir -p $out/qml
            cp -r ${./qml}/* $out/qml/
          '';
          inherit headless-plugin ui-plugin lgx lgx-core lgx-ui;
        }
      );
    };
}
