# Nix-on-Droid host (Android, the Nix-on-Droid app). Created from
# templates/droid (see modules/flake/new-host.nix); the host is named after
# this directory. Switch on the device with `reb` (nix-on-droid switch).
let
  name = baseNameOf ./.;
in
{
  hosts.${name} = {
    system = "aarch64-linux";
    nixos = false;
    nixOnDroid = true;
  };

  nixOnDroid.${name} = {
    # Nix-on-Droid's own release (its latest is 24.05); never change it.
    system.stateVersion = "24.05";
  };

  # The release this host was set up with; never change it.
  homeManager.${name}.home.stateVersion = "@stateVersion@";
}
