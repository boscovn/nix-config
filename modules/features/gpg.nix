{
  homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.gpg.enable = true;
      # HM's gpg-agent module is a systemd user service, so Linux only (and
      # not Nix-on-Droid, which has no systemd; gpg starts the agent itself).
      services.gpg-agent = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && !config.dotfiles.nixOnDroid) {
        enable = true;
        # A graphical prompt only with a desktop session; curses on WSL/servers.
        pinentry.package = if config.dotfiles.gui then pkgs.pinentry-gnome3 else pkgs.pinentry-curses;
      };
    };
}
