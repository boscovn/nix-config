# nix-ld: a stub /lib64/ld-linux-x86-64.so.2 so prebuilt, non-Nix binaries
# run unpatched: what uv (python-build-standalone, wheels with native code),
# mise (node, go, ...) and VS Code Server download. They all see the same
# libraries, listed below; add one when a binary reports a missing .so.
# Nix-built programs use their own loader and ignore this.
{
  nixos.nix-ld =
    { pkgs, ... }:
    {
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib # libstdc++, libgcc_s
          zlib
          openssl
          libffi
          glib
        ];
      };
    };
}
