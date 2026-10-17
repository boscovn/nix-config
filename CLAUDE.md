# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS + Home Manager dotfiles for a ThinkPad (NixOS, x86_64-linux), a Rock 5T (home-manager only, aarch64-linux) and a Pixel 10 (Nix-on-Droid, `pixel-10`), organized with the **dendritic pattern**: every `.nix` file under `modules/` is a [flake-parts](https://flake.parts) module implementing one feature across every configuration class it touches (NixOS, Nix-on-Droid and/or home-manager). Hosts are compositions: importing a feature enables it.

## Key Commands

```bash
# Rebuild and switch the system (+ embedded home-manager) through nh: build,
# diff, then switch (asks for sudo itself); aliased as `reb`
nh os switch ~/nix-config

# Home-manager only, standalone (picks bosco@<hostname>); aliased as `hms`
nh home switch ~/nix-config

# Equivalents without nh
sudo nixos-rebuild switch --flake ~/nix-config#thinkpad
home-manager switch --flake ~/nix-config#bosco@thinkpad

# On the phone (Nix-on-Droid, home-manager embedded; nh doesn't support it);
# aliased as `reb` there. Its generation needs --impure, which it passes itself
nix-on-droid switch --flake ~/nix-config#pixel-10

# Neovim is its own flake (~/nvim, github:boscovn/nvim). `nvim` is a launcher
# (modules/features/neovim.nix) that rebuilds it only when ~/nvim changed;
# NVIM_REBUILD=1 forces a rebuild (e.g. to update from GitHub)
nvim

# Format all Nix files
nix fmt

# Check formatting and flake validity
nix flake check
```

Flakes only see files git tracks: `git add` new files before building. The user often has uncommitted edits of their own in the tree: stage and commit files by name, never `git add -u`/`-A`.

nh also cleans weekly (`nh clean`, `base/nix.nix`: `--keep-since 7d --keep 5 --keep-one`); it ages out `result*` links and direnv GC roots, so anything that must survive is rooted elsewhere (the nvim launcher uses `~/.cache/nvim-flake/current`).

## Architecture

### Entry point

`flake.nix` only declares inputs and hands everything to flake-parts:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ (inputs.import-tree ./modules) ];
};
```

[import-tree](https://github.com/vic/import-tree) imports every `.nix` file under `modules/` recursively, **except paths containing `/_`**. Use a `_` prefix for files that are not flake-parts modules: plain NixOS/home-manager modules imported by path (`_disko.nix`), or a module kept but not loaded (`desktop/_waybar.nix`; ashell is used instead). Non-Nix files sit next to the module that references them by path (`hardware/laptop-lid.lua`, `desktop/display-mirror.lua`, `email/notmuch-notify.py`). Inputs are written by hand in `flake.nix` (no flake-file).

### Plumbing (`modules/flake/`)

- **`slots.nix`**: declares `nixos.<name>`, `nixOnDroid.<name>` and `homeManager.<name>` (typed `deferredModule`). Features add to them; hosts import them. Each value is wrapped with a `key` (importing it twice is a no-op) and a `_class`, so importing a home-manager slot into NixOS (or vice versa) is an evaluation error.
- **`hosts.nix`**: each `hosts.<name>` becomes `nixosConfigurations.<name>` (home-manager embedded; skipped when `hosts.<name>.nixos = false`) and `homeConfigurations."<user>@<name>"` (standalone). Both use the **same** `homeManager.<name>` module and the same nixpkgs config (`allowUnfree` plus `hosts.<name>.nixpkgsConfig`), so `reb` and `hms` cannot drift. It also sets `networking.hostName` and, for home-manager, the read-only `dotfiles.hostname` / `dotfiles.nixos`. A host with `nixOnDroid = true` (and `nixos = false`) becomes `nixOnDroidConfigurations.<name>` only (embedded home-manager with `osConfig`, user name `hosts.<name>.user`, fixed home `/data/data/com.termux.nix/files/home`; no `homeConfigurations`); home-manager sees it as `dotfiles.nixOnDroid` (no systemd: gpg-agent is off, `reb` is `nix-on-droid switch`). Off-device only its home-manager part evaluates purely (`.#nixOnDroidConfigurations.pixel-10.config.home-manager.config.home.activationPackage`): the whole generation needs `--impure` and nix-on-droid's proot in the local store (`builtins.storePath`; `nix-store -r <path> --option extra-substituters https://nix-on-droid.cachix.org --option extra-trusted-public-keys nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU=`). `standaloneHomeModules` holds modules only the standalone build needs (stylix's home-manager module, which NixOS otherwise injects itself).
- **`systems.nix`**, **`formatter.nix`**: flake systems and the treefmt formatter/check.

There are **no `specialArgs`**. Values shared across files come from the top-level flake-parts config, reached by closure: `config.my.{user,fullName,email}` (`modules/meta.nix`) and flake `inputs`. Inside a lower-level module, `config` is the NixOS/home-manager config, so bind top-level values before it (e.g. `{ config, ... }: let inherit (config.my) user; in { homeManager.base = { config, ... }: ...; }`).

### Features (`modules/features/`)

A feature file writes to one or more slots. Small, related pieces merge under a shared **bundle** name instead of each getting its own name:

- **`base`** (every host): `nixos.base` (boot, nix settings/caches, locale, user, network, stylix), `nixOnDroid.base` (nix caches, timezone, zsh login shell, stylix for the terminal; stylix's overlays off, Nix-on-Droid refuses `nixpkgs.*` in a flake) and `homeManager.base` (shell, git/gh, gpg, CLI tools, the `nvim` launcher, stylix's terminal targets).
- **`gui`** (Linux desktop session): `nixos.gui` (greetd autologin, Hyprland, plymouth, keyring PAM, audio, fonts) and `homeManager.gui` (Hyprland lua config, hyprlock, hypridle, ashell, ghostty, apps, browsers, mpv, imv).

Distinct, optional features have their own names: `nixos.{nvidia,nvidia-prime,cuda,intel-graphics,laptop,bluetooth,docker,gaming,kdeconnect,ssh,nixbuild,tailscale,secrets,howdy}`, `homeManager.{email,kdeconnect,laptop,tailscale,secrets}`. The thinkpad imports all of them except `howdy` (paused).

Conventions:
- **Importing enables.** No `enable` flags: a host that should not have a feature does not import it.
- **Tunable values** are set by the feature with `lib.mkDefault` and overridden in the host file with plain options (e.g. mpv's `hwdec` defaults to `auto-safe`; the thinkpad sets `vaapi`).
- **Cross-feature facts** are typed home-manager options, not host data: `dotfiles.gui` (declared in `base`, set by `gui`) drives the gpg pinentry, stylix `autoEnable` and Thunderbird; `dotfiles.kbLayouts` (Hyprland, default `es,us`).
- **Platform differences** use the platform (`pkgs.stdenv.hostPlatform.isDarwin`/`isLinux`), e.g. `home.homeDirectory`, gpg-agent.
- `base` must stay portable (no Linux-desktop assumptions); GUI and Linux-only things go in `gui`.

### Notable features

- **Hyprland** (`desktop/hyprland.nix`, gui): settings are written in Nix and rendered to Hyprland's Lua config (0.56 Lua API); logic that needs code goes in `.lua` files added with `extraLuaFiles` (`display-mirror.lua`, SUPER+M; `laptop-lid.lua` from `laptop`: panel off when docked, lock + DPMS off otherwise). Programs are referenced by store path. The terminal is the typed `dotfiles.terminal` (`{ package, newWindow }`), set per host. Bar: ashell (module names must match its enum exactly; wrong ones vanish silently).
- **Email** (`email/`, `homeManager.email`; the directory's files all add to it, see `email/default.nix`'s header): mbsync/msmtp accounts (passwords via `gopass show -o`), one goimapnotify (IMAP IDLE) service per account running `mail-sync <account>`, notmuch with tag rules in its post-new hook, aerc (notmuch `meta` account, viewer filters, `less -Rc`). On gui hosts the post-new hook sends new mail as JSON to a socket-activated user service (`notmuch-notify.socket`/`.service`, `notmuch-notify.py`) that shows notifications, opens a clicked one in aerc over aerc's IPC (`mail-open`) and offers to copy one-time codes (`wl-copy --sensitive`).
- **KDE Connect**: daemon and indicator in home-manager; the NixOS side only opens the firewall (`programs.kdeconnect.package = null`) and enables `hypr-kdeconnect-fix` (flake input).
- **Neovim** lives in its own flake (`~/nvim`, github:boscovn/nvim, nixvim, tokyonight; not themed by stylix). `neovim.nix` installs an `nvim`/`vim` launcher and sets `EDITOR` (`home.sessionVariables` + systemd user env).
- **Dev tooling** (`cli-tools.nix`): direnv with nix-direnv (`use flake` in `.envrc`), devenv; Claude Code is wrapped with nodejs, uv and python3 appended to its PATH (for plugins). Global git ignores (`git.nix`): `.direnv/`, `**/.claude/settings.local.json`.
- **nixbuild** (`services/nixbuild.nix`): eu.nixbuild.net as remote builder for x86_64-linux and aarch64-linux, with a dedicated ssh key from the host's sops secrets (`nixbuild-ssh-key`; creating one for a new host: see the file).
- **Secrets** (`secrets.nix`): sops-nix. Recipients in `.sops.yaml` (bosco's GPG key + each host's age key from its ssh host key, `ssh-to-age`); a host's secrets in `modules/hosts/<name>/secrets.yaml` (its `sops.defaultSopsFile`), edited with `sops <file>`, `sops updatekeys <file>` after changing recipients. A feature needing a secret imports `nixos.secrets` itself and declares `sops.secrets.<name>` (nixbuild's ssh key → `/run/secrets/nixbuild-ssh-key`). home-manager decrypts with `~/.config/sops/age/keys.txt` (placed by hand). gopass stays for interactive passwords.
- **Theme**: stylix with Catppuccin Mocha (`stylix.nix`), NixOS and home-manager.

### Hosts (`modules/hosts/<name>/`)

- `features.nix`: what the host runs (`nixos.<name>.imports` / `homeManager.<name>.imports` lists).
- `default.nix`: `hosts.<name>` (system, `nixos`, `nixpkgsConfig`) and host-specific settings (`system.stateVersion`, `home.stateVersion`, driver branch, mpv decode; `nvidia-prime` reads the PRIME bus ids from facter.json). Hardware comes from a nixos-facter report (`hardware.facter.reportPath = ./facter.json`, regenerated with `sudo nixos-facter -o facter.json`) and disks from disko (`_disko.nix`, imported with `inputs.disko.nixosModules.disko`). Facter's detected defaults can be overridden under `hardware.facter.detected.*` (the thinkpad keeps GPU drivers out of the initrd and turns off its per-interface DHCP). Disko only generates `fileSystems`/LUKS entries; nothing is partitioned unless its format script is run. The thinkpad's `_disko.nix` pins the existing UUIDs, so it describes the current install rather than a fresh one.

The thinkpad decodes video on the Intel iGPU (`vaapi`): its MX150 exposes no usable NVDEC (ffmpeg `-hwaccel cuda` reports "Hardware is lacking required capabilities" for H.264, HEVC and VP9), and the iGPU avoids waking the dGPU. nixpkgs' global `cudaSupport` is deliberately off (`nixos.cuda` only adds the toolkit and cache): it rebuilds every CUDA-capable package (firefox pulls a ~6 GiB CUDA onnxruntime); use explicit packages like `pkgs.ollama-cuda`.

### Adding things

- **A feature**: create `modules/features/<area>/<name>.nix` writing to `nixos.<name>` / `homeManager.<name>` (or into `base`/`gui`), then add it to the hosts' `features.nix`. `git add` it.
- **A host**: `nix run .#new-host -- <name>` (`modules/flake/new-host.nix`) creates `modules/hosts/<name>` from `templates/<kind>`:
  - `nixos`: facter report (this machine or over ssh), disko layout on a chosen disk (1G ESP + LUKS ext4), features preselected from the hardware;
  - `wsl`: NixOS-WSL (`inputs.nixos-wsl`), with `base`'s bootloader, fwupd and NetworkManager forced off;
  - `home`: home-manager only on another distribution (`nixos = false`, `targets.genericLinux`);
  - `droid`: Nix-on-Droid (`nixOnDroid = true`, aarch64-linux, its own `system.stateVersion` "24.05"); `--nixos-features` then picks `nixOnDroid` features.

  It fills in `system` and `stateVersion` (the locked nixpkgs release, written once), writes `features.nix` (with `dotfiles.terminal` when `gui` is picked), `git add`s and evaluates the host. Flags (`--kind`, `--report`, `--disk`, `--nixos-features`, `--home-features`) skip the menus. Hosts are named after their directory (`baseNameOf ./.`). The templates are also `nix flake init -t .#<kind>` templates with `@placeholders@` to fill by hand. darwin isn't supported yet (needs a `darwin` slot class and `darwinConfigurations`).
- **Checking a throwaway host**: `nix run .#new-host -- tmp --kind home --home-features base` (or `--kind wsl`/`nixos`), then `git rm -r --cached modules/hosts/tmp && rm -r modules/hosts/tmp`.
- **Checking portability** (no darwin host exists yet): add a throwaway `modules/hosts/tmp/default.nix` with `hosts.tmp = { system = "aarch64-darwin"; nixos = false; };` and `homeManager.tmp = { imports = [ config.homeManager.base ]; home.stateVersion = "24.05"; };`, then `nix eval '.#homeConfigurations."bosco@tmp".activationPackage.drvPath'` (darwin can only be evaluated on Linux, which is what catches Linux-only packages/options). Delete it afterwards.

### NixOS vs home-manager

System services, hardware, boot, display manager, PAM → `nixos.*`. User programs, dotfiles, user services and **all user-facing packages** → `homeManager.*` (prefer `programs.<name>.enable` when home-manager has a module). There is no shared `environment.systemPackages` (only hardware-gated extras like the CUDA toolkit); home-manager packages are not on root's PATH (`sudo`).
