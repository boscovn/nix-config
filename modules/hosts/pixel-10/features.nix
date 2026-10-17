# What this host runs: importing a feature enables it.
{ config, ... }:
let
  name = baseNameOf ./.;
  slots = config;
in
{
  nixOnDroid.${name}.imports = with slots.nixOnDroid; [
    base
  ];

  homeManager.${name}.imports = with slots.homeManager; [
    base
  ];
}
