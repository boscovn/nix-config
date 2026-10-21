# DDC/CI: control external monitors (brightness, input, volume) over the
# DP AUX / HDMI DDC channel with ddcutil. NixOS loads i2c-dev and gives the
# i2c group access to /dev/i2c-*; home-manager installs ddcutil. A host
# imports both nixos.ddc and homeManager.ddc.
{ config, ... }:
{
  nixos.ddc = {
    hardware.i2c.enable = true;
    users.users.${config.my.user}.extraGroups = [ "i2c" ];
  };

  homeManager.ddc =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ddcutil ];
    };
}
