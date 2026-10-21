# What the thinkpad runs: importing a feature enables it.
{ config, ... }:
{
  nixos.thinkpad.imports = with config.nixos; [
    base
    gui
    nvidia
    nvidia-prime
    cuda
    intel-graphics
    laptop
    bluetooth
    ddc
    docker
    gaming
    kdeconnect
    ssh
    secrets
    nixbuild
    tailscale
    # howdy  # paused: face match kept returning "no match"
  ];

  homeManager.thinkpad.imports = with config.homeManager; [
    base
    gui
    email
    ddc
    kdeconnect
    laptop
    tailscale
    secrets
  ];
}
