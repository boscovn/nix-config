# Catppuccin theme via stylix, for the system and home-manager.
{ inputs, ... }:
let
  theme =
    { pkgs, ... }:
    {
      stylix.enable = true;
      stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      stylix.opacity.terminal = 0.8;
      stylix.fonts.monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCodeNerdFont";
      };
      stylix.image = ../../assets/wallpapers/gnus.JPG;
    };
in
{
  # On NixOS, stylix injects its home-manager module into embedded
  # home-manager itself (homeManagerIntegration.autoImport), copying these
  # settings and disabling overlays there, since embedded home-manager uses the
  # system's pkgs.
  nixos.base.imports = [
    inputs.stylix.nixosModules.stylix
    theme
  ];

  # Nix-on-Droid: the terminal's colours and font, and (like NixOS) injected
  # into its embedded home-manager.
  nixOnDroid.base = {
    imports = [
      inputs.stylix.nixOnDroidModules.stylix
      theme
    ];
    # Its overlays go through nixpkgs.overlays, which Nix-on-Droid refuses in
    # a flake (pkgs comes from hosts.nix); they only theme GUI packages anyway.
    stylix.overlays.enable = false;
  };

  # Standalone home-manager (`hms`) has no NixOS side to do that injection.
  standaloneHomeModules = [
    inputs.stylix.homeModules.stylix
    theme
  ];

  # stylix themes every app it knows about by default, which on a terminal-only
  # host (WSL/darwin/server) generates config for GUI apps that are not even
  # installed (gtk, blender, vencord, ...). Only auto-enable with the gui
  # bundle; otherwise theme just the terminal tools.
  homeManager.base =
    { config, lib, ... }:
    {
      # Stylix's NixOS module passes its own autoEnable (true) down to
      # home-manager at mkDefault too; one step above it wins without a host
      # needing mkForce (a NixOS host without gui otherwise fails to evaluate).
      stylix.autoEnable = lib.mkOverride 999 config.dotfiles.gui;
      stylix.targets = {
        rofi.enable = false;
        bat.enable = true;
        yazi.enable = true;
        starship.enable = true;
      };
    };
}
