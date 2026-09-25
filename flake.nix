{
  description = "disktree development shell and package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;
      runtimeLibraries = with pkgs; [
        fontconfig
        freetype
        wayland
        libxkbcommon
        libxcb
        vulkan-loader
      ];
      disktree = pkgs.rustPlatform.buildRustPackage {
        pname = "disktree";
        inherit version;
        src = ./.;
        cargoLock.lockFile = ./Cargo.lock;
        cargoBuildFlags = [
          "-p"
          "disktree-app"
        ];

        nativeBuildInputs = with pkgs; [
          pkg-config
          makeWrapper
          desktop-file-utils
        ];
        buildInputs = runtimeLibraries;

        # The Rust CI job runs the workspace tests, including the window harness.
        doCheck = false;

        postInstall = ''
          install -Dm644 assets/disktree.svg \
            "$out/share/icons/hicolor/scalable/apps/disktree.svg"
          install -Dm644 packaging/disktree.desktop.in \
            "$out/share/applications/disktree.desktop"
          substituteInPlace "$out/share/applications/disktree.desktop" \
            --replace-fail '@BINDIR@' "$out/bin" \
            --replace-fail '@VERSION@' "$version"
          desktop-file-validate "$out/share/applications/disktree.desktop"
          wrapProgram "$out/bin/disktree" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibraries}"
        '';

        meta = with pkgs.lib; {
          description = "Treemap explorer for disk usage";
          homepage = "https://github.com/tobi/disktree";
          license = licenses.mit;
          mainProgram = "disktree";
          platforms = platforms.linux;
        };
      };
    in
    {
      packages.${system} = {
        inherit disktree;
        default = disktree;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages =
          with pkgs;
          [
            cargo
            clippy
            rustc
            rustfmt
            gnumake
            pkg-config
          ]
          ++ runtimeLibraries;

        shellHook = ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibraries}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        '';
      };
    };
}
