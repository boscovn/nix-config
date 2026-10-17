{ config, lib, ... }:
let
  # Checked before any build, local or on nixbuild.
  substituters = [
    "https://nix-community.cachix.org"
    "https://fossar.cachix.org"
    "https://nixpkgs-python.cachix.org"
    "https://ai.cachix.org"
  ];
  trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "fossar.cachix.org-1:Zv6FuqIboeHPWQS7ysLCJ7UT7xExb4OE8c4LyGb5AsE="
    "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
    "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
  ];
  experimental-features = [
    "nix-command"
    "flakes"
  ];
in
{
  nixos.base = {
    # System-wide so `reb` (nix run as root) uses them too, not only the user's
    # ~/.config/nix/nix.conf.
    nix.settings = {
      inherit substituters trusted-public-keys experimental-features;
      trusted-users = [ config.my.user ];
    };

    # Weekly `nh clean all` (system and user generations, then GC), keeping
    # the last 5 and anything from the past week.
    programs.nh = {
      enable = true;
      clean = {
        enable = true;
        # --keep-one: direnv roots stay per project (aged out, an unchanged
        # project would re-evaluate on its next `cd`).
        extraArgs = "--keep-since 7d --keep 5 --keep-one";
      };
    };
  };

  # Nix-on-Droid's /etc/nix/nix.conf (cache.nixos.org is in by default).
  nixOnDroid.base.nix = {
    inherit substituters;
    trustedPublicKeys = trusted-public-keys;
    extraOptions = "experimental-features = ${lib.concatStringsSep " " experimental-features}";
  };

  # nh (`reb` / `hms` in shell.nix): builds with a progress view, shows a
  # diff of what changed, then switches. Portable, so `nh home switch` works on
  # any host; it picks `<user>@<hostname>` and `nh os` the hostname by itself.
  homeManager.base =
    { config, ... }:
    {
      programs.nh = {
        enable = true;
        flake = "${config.home.homeDirectory}/.dotfiles";
      };
    };
}
