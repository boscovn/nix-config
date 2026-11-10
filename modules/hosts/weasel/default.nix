# NixOS-WSL host. Created from templates/wsl (see modules/flake/new-host.nix);
# the host is named after this directory.
{ inputs, config, ... }:
let
  name = baseNameOf ./.;
  inherit (config.my) user;
in
{
  hosts.${name}.system = "x86_64-linux";

  nixos.${name} =
    { lib, ... }:
    {
      imports = [ inputs.nixos-wsl.nixosModules.default ];
      wsl.enable = true;
      wsl.defaultUser = user;

      # Windows boots WSL and owns its network: base's bootloader, firmware
      # updates and NetworkManager don't apply.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
      services.fwupd.enable = lib.mkForce false;
      networking.networkmanager.enable = lib.mkForce false;

      # The NixOS release this host was installed with; never change it.
      system.stateVersion = "26.11";
    };

  homeManager.${name}.home.stateVersion = "26.11";
}
