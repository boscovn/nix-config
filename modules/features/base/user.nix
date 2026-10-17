{ config, ... }:
{
  nixos.base =
    { pkgs, ... }:
    {
      programs.zsh.enable = true;
      users.users.${config.my.user} = {
        isNormalUser = true;
        description = "Bosco";
        extraGroups = [
          "adbusers"
          "networkmanager"
          "video"
          "wheel"
        ];
        shell = pkgs.zsh;
      };
    };

  # Nix-on-Droid has one user, named after the host's (hosts.nix).
  nixOnDroid.base =
    { pkgs, ... }:
    {
      user.shell = "${pkgs.zsh}/bin/zsh";
    };
}
