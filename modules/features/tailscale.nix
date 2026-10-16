# Tailscale: the daemon runs on NixOS (which also puts the `tailscale` CLI on
# PATH); home-manager adds Trayscale, a tray GUI over that CLI, on gui hosts
# only (dotfiles.gui). A host imports both nixos.tailscale and
# homeManager.tailscale.
{ config, ... }:
{
  nixos.tailscale = {
    services.tailscale = {
      enable = true;
      # Configures your user as the Tailscale operator so you don't need sudo
      # (Trayscale drives the CLI as that user)
      extraSetFlags = [
        "--operator=${config.my.user}"
      ];
    };
  };

  homeManager.tailscale =
    { config, ... }:
    {
      services.trayscale.enable = config.dotfiles.gui;
    };
}
