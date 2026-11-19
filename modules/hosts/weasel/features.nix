# What this host runs: importing a feature enables it.
{ config, ... }:
let
  name = baseNameOf ./.;
  slots = config;
in
{
  nixos.${name}.imports = with slots.nixos; [
    base
    docker
    nix-ld
  ];

  homeManager.${name}.imports = with slots.homeManager; [
    base
    werk
  ];
}
