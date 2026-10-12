{
  description = "Linux desktop build shell for the bellenissimos Flutter app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/8edc0c72e3a38faf5434e40d1f19431125fe4b30";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.linux-desktop = pkgs.mkShell {
      # pkg-config's setup hook exposes the dev outputs (gtk+-3.0.pc et al.)
      # to the build, which a plain devbox profile cannot do.
      packages = with pkgs; [
        flutter
        gtk3
        cmake
        ninja
        clang
        pkg-config
      ];
    };
  };
}
