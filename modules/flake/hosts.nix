# Turns each `hosts.<name>` into nixosConfigurations.<name> (home-manager
# embedded, `reb`) and homeConfigurations."<user>@<name>" (standalone, `hms`),
# <user> being hosts.<name>.user (default: my.user); a nixOnDroid host into
# nixOnDroidConfigurations.<name> only (home-manager embedded, `reb`).
# All use the same `homeManager.<name>` module, so they cannot drift.
{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (inputs) nixpkgs home-manager nix-on-droid;

  # allowUnfree everywhere; a host adds or overrides via hosts.<name>.nixpkgsConfig.
  nixpkgsConfig = host: { allowUnfree = true; } // host.nixpkgsConfig;

  # Facts about the host that home-manager modules may need, as read-only
  # options, set for both the embedded and the standalone build.
  hostModule = name: host: { lib, ... }: {
    options.dotfiles = {
      hostname = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
      };
      user = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "The host's user (hosts.<name>.user).";
      };
      nixos = lib.mkOption {
        type = lib.types.bool;
        readOnly = true;
        description = "Whether this host is a NixOS system (has `reb`).";
      };
      nixOnDroid = lib.mkOption {
        type = lib.types.bool;
        readOnly = true;
        description = "Whether this host is Nix-on-Droid (Android: no systemd, `reb` is nix-on-droid switch).";
      };
    };
    config.dotfiles = {
      hostname = name;
      inherit (host) nixos nixOnDroid user;
    };
  };

  mkSystem =
    name: host:
    nixpkgs.lib.nixosSystem {
      inherit (host) system;
      modules = [
        {
          nixpkgs.config = nixpkgsConfig host;
          networking.hostName = name;
        }
        config.nixos.${name}
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${host.user}.imports = [
            (hostModule name host)
            config.homeManager.${name}
          ];
        }
      ];
    };

  # Nix-on-Droid's home is fixed (/data/data/com.termux.nix/files/home) and
  # passed to home-manager's home.homeDirectory; the user name is only a label
  # (/etc/passwd), set to the host's user like everywhere else.
  mkDroid =
    name: host:
    assert lib.assertMsg (!host.nixos) "hosts.${name}: nixOnDroid needs nixos = false";
    nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs {
        inherit (host) system;
        config = nixpkgsConfig host;
        overlays = [ nix-on-droid.overlays.default ];
      };
      modules = [
        config.nixOnDroid.${name}
        (droid: {
          user.userName = host.user;
          home-manager.useGlobalPkgs = true;
          # As on NixOS; stylix's injected home-manager module reads it.
          home-manager.extraSpecialArgs.osConfig = droid.config;
          home-manager.config.imports = [
            (hostModule name host)
            config.homeManager.${name}
          ];
        })
      ];
    };

  mkHome =
    name: host:
    home-manager.lib.homeManagerConfiguration {
      # Same config `useGlobalPkgs` shares with the NixOS-embedded build.
      pkgs = import nixpkgs {
        inherit (host) system;
        config = nixpkgsConfig host;
      };
      modules = config.standaloneHomeModules ++ [
        (hostModule name host)
        config.homeManager.${name}
      ];
    };
in
{
  options.standaloneHomeModules = lib.mkOption {
    type = lib.types.listOf lib.types.raw;
    default = [ ];
    description = ''
      Home-manager modules only for standalone builds (`hms`), for things the
      NixOS side injects into embedded home-manager by itself (stylix).
    '';
  };

  options.hosts = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption {
            type = lib.types.str;
            default = "x86_64-linux";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = config.my.user;
            description = "The user home-manager is set up for on this host.";
          };
          nixos = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Build a NixOS system for this host (false: standalone home-manager only, e.g. darwin or non-NixOS WSL).";
          };
          nixOnDroid = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Build a Nix-on-Droid configuration (Android) instead of a NixOS or standalone home-manager one; needs nixos = false.";
          };
          nixpkgsConfig = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Extra nixpkgs config (on top of allowUnfree), shared by the NixOS and standalone home-manager builds, e.g. { cudaSupport = true; }.";
          };
        };
      }
    );
  };

  config.flake = {
    nixosConfigurations = lib.mapAttrs mkSystem (lib.filterAttrs (_: host: host.nixos) config.hosts);
    nixOnDroidConfigurations = lib.mapAttrs mkDroid (
      lib.filterAttrs (_: host: host.nixOnDroid) config.hosts
    );
    homeConfigurations = lib.mapAttrs' (
      name: host: lib.nameValuePair "${host.user}@${name}" (mkHome name host)
    ) (lib.filterAttrs (_: host: !host.nixOnDroid) config.hosts);
  };
}
