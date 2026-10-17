# `nix run .#new-host -- <name>` creates modules/hosts/<name> from
# templates/<kind> (nixos, wsl, home, droid): fills in the system and stateVersion,
# fetches the nixos-facter report and picks the disk (nixos), writes
# features.nix from menus, then `git add`s and evaluates the new host.
# The templates are also flake templates (`nix flake init -t .#<kind>`), with
# the @placeholders@ left to fill in by hand.
{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (config.my) user;
  hostNames = lib.attrNames config.hosts;
  # Feature slots, without the per-host ones.
  features = class: lib.subtractLists hostNames (lib.attrNames config.${class});
  release = inputs.nixpkgs.lib.trivial.release;

  template = kind: description: {
    path = ../../templates/${kind};
    inherit description;
    welcomeText = ''
      # New ${kind} host

      Replace the @placeholders@ in default.nix${
        lib.optionalString (kind == "nixos") " and _disko.nix"
      }, ${
        lib.optionalString (kind == "nixos") "add facter.json (`sudo nixos-facter -o facter.json`), "
      }pick features in features.nix and `git add` the directory.
      `nix run .#new-host -- <name>` does all of this.
    '';
  };
in
{
  flake.templates = {
    nixos = template "nixos" "NixOS host with nixos-facter and disko";
    wsl = template "wsl" "NixOS-WSL host";
    home = template "home" "Home-manager-only host on a non-NixOS distribution";
    droid = template "droid" "Nix-on-Droid host (Android)";
  };

  perSystem =
    { pkgs, ... }:
    let
      new-host = pkgs.writeShellApplication {
        name = "new-host";
        runtimeInputs = with pkgs; [
          coreutils
          gnused
          git
          gum
          jq
          nixos-facter
          openssh
        ];
        # features.nix is written with single-quoted Nix `${...}` on purpose.
        excludeShellChecks = [ "SC2016" ];
        text = ''
          templates=${../../templates}
          release=${release}
          user=${user}
          nixos_features=(${lib.escapeShellArgs (features "nixos")})
          home_features=(${lib.escapeShellArgs (features "homeManager")})
          droid_features=(${lib.escapeShellArgs (features "nixOnDroid")})

          die() { echo "new-host: $*" >&2; exit 1; }
          usage() {
            cat <<EOF
          usage: new-host <name> [--kind nixos|wsl|home|droid] [--report FILE] [--disk DEVICE]
                                 [--nixos-features a,b] [--home-features a,b]
          (--nixos-features are the nixOnDroid features for --kind droid)
          Prompts for whatever isn't given. Run inside the dotfiles repository.
          EOF
            exit "''${1:-1}"
          }

          name="" kind="" report="" disk="" nixos_sel="" home_sel=""
          while (($#)); do
            case $1 in
              --kind) kind=$2; shift 2 ;;
              --report) report=$(realpath "$2"); shift 2 ;;
              --disk) disk=$2; shift 2 ;;
              --nixos-features) nixos_sel=$2; shift 2 ;;
              --home-features) home_sel=$2; shift 2 ;;
              -h | --help) usage 0 ;;
              -*) usage ;;
              *) [[ -z $name ]] || usage; name=$1; shift ;;
            esac
          done
          [[ -n $name ]] || usage
          [[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "'$name' is not a valid hostname (lowercase letters, digits, -)"

          root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run inside the dotfiles repository"
          [[ -f $root/flake.nix && -d $root/modules/hosts ]] || die "$root is not the dotfiles repository"
          dir=$root/modules/hosts/$name
          [[ ! -e $dir ]] || die "$dir already exists"

          # Guess the kind from the machine this runs on; it's only the default.
          guess=home
          [[ -e /etc/NIXOS ]] && guess=nixos
          grep -qi microsoft /proc/version 2>/dev/null && guess=wsl
          if [[ -z $kind ]]; then
            kind=$(gum choose --header "Kind of host" --selected "$guess" nixos wsl home droid)
          fi
          [[ $kind =~ ^(nixos|wsl|home|droid)$ ]] || die "unknown kind '$kind'"
          # The system-level slot the host's features.nix imports from.
          sys_class=nixos
          if [[ $kind == droid ]]; then
            sys_class=nixOnDroid
            nixos_features=("''${droid_features[@]}")
          fi

          # Build the host in a scratch directory and move it in at the end, so
          # a failure or ^C leaves nothing behind.
          work=$(mktemp -d)
          trap 'rm -rf "$work"' EXIT
          cp -r --no-preserve=mode "$templates/$kind" "$work/$name"
          host=$work/$name

          system=$(nix eval --impure --raw --expr builtins.currentSystem)
          suggested=()

          if [[ $kind == nixos ]]; then
            if [[ -n $report ]]; then
              cp "$report" "$host/facter.json"
            else
              case $(gum choose --header "Hardware report (nixos-facter)" "this machine" "over ssh") in
                "this machine")
                  echo "Running nixos-facter (needs root)…"
                  sudo "$(command -v nixos-facter)" -o "$host/facter.json"
                  ;;
                "over ssh")
                  target=$(gum input --header "ssh target (e.g. root@nixos on the live ISO)" --placeholder "root@host")
                  # shellcheck disable=SC2029
                  ssh "$target" "sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#nixos-facter" \
                    >"$host/facter.json"
                  ;;
              esac
            fi
            jq -e .hardware "$host/facter.json" >/dev/null || die "facter.json is not a nixos-facter report"
            system=$(jq -r .system "$host/facter.json")

            if [[ -z $disk ]]; then
              # One line per disk: its stable by-id name, model and size.
              mapfile -t disks < <(jq -r '
                .hardware.disk[]?
                | (.unix_device_names // [])
                  as $names
                | ($names | map(select(startswith("/dev/disk/by-id/") and (test("eui\\.|wwn-|_1$") | not))) | first // $names[-1]) as $dev
                | ([.resources[]? | select(.type == "size" and .unit == "sectors") | .value_1 * .value_2] | first // 0) as $bytes
                | "\($dev)  \(.model // "?")  \($bytes / 1e9 | floor)G"
              ' "$host/facter.json")
              ((''${#disks[@]})) || die "the report lists no disks"
              disk=$(gum choose --header "Disk for disko (it is ERASED when you install)" "''${disks[@]}")
              disk=''${disk%%  *}
            fi
            sed -i "s|@disk@|$disk|" "$host/_disko.nix"

            # Features the hardware suggests (only those that exist).
            r=$host/facter.json
            gpu() { jq -e --arg v "$1" '[.hardware.graphics_card[]? | select(.vendor.hex == $v)] | length > 0' "$r" >/dev/null; }
            gpu 10de && suggested+=(nvidia)
            gpu 8086 && suggested+=(intel-graphics)
            gpu 10de && gpu 8086 && suggested+=(nvidia-prime)
            jq -e '(.hardware.bluetooth // []) | length > 0' "$r" >/dev/null && suggested+=(bluetooth)
            jq -e '.hardware.system.form_factor == "laptop"' "$r" >/dev/null && suggested+=(laptop)
          fi

          sed -i "s|@system@|$system|; s|@stateVersion@|$release|" "$host"/*.nix

          # Features: menus unless given on the command line.
          available() { local f; for f in "$@"; do printf '%s\n' "''${list[@]}" | grep -qx "$f" && printf '%s,' "$f"; done; }
          if [[ $kind != home && -z $nixos_sel ]]; then
            list=("''${nixos_features[@]}")
            preselect=$(available base "''${suggested[@]}")
            nixos_sel=$(gum choose --no-limit --header "$sys_class features (hardware suggestions preselected)" \
              --selected "''${preselect%,}" "''${nixos_features[@]}" | paste -sd,)
          fi
          if [[ -z $home_sel ]]; then
            home_sel=$(gum choose --no-limit --header "home-manager features" \
              --selected base "''${home_features[@]}" | paste -sd,)
          fi
          nix_list() { tr ',' '\n' <<<"$1" | sed '/^$/d; s/^/      /'; }

          {
            echo '# What this host runs: importing a feature enables it.'
            echo '{ config, ... }:'
            echo 'let'
            echo '  name = baseNameOf ./.;'
            echo '  slots = config;'
            echo 'in'
            echo '{'
            if [[ $kind != home ]]; then
              echo "  $sys_class.\''${name}.imports = with slots.$sys_class; ["
              nix_list "$nixos_sel"
              echo '  ];'
              echo
            fi
            if [[ ,$home_sel, == *,gui,* ]]; then
              echo '  homeManager.''${name} ='
              echo '    { config, lib, ... }:'
              echo '    {'
              echo '      imports = with slots.homeManager; ['
              nix_list "$home_sel" | sed 's/^/  /'
              echo '      ];'
              echo '      # gui binds it to SUPER + Return.'
              echo '      dotfiles.terminal = rec {'
              echo '        package = config.programs.ghostty.package;'
              echo '        newWindow = "''${lib.getExe package} +new-window";'
              echo '      };'
              echo '    };'
            else
              echo '  homeManager.''${name}.imports = with slots.homeManager; ['
              nix_list "$home_sel"
              echo '  ];'
            fi
            echo '}'
          } >"$host/features.nix"

          mv "$host" "$dir"
          git -C "$root" add "$dir"
          nix fmt -- "$dir" >/dev/null 2>&1 || true
          git -C "$root" add "$dir"
          echo "Created $dir ($kind, $system)."

          echo "Evaluating…"
          if [[ $kind == home ]]; then
            attr="homeConfigurations.\"$user@$name\".activationPackage.drvPath"
          elif [[ $kind == droid ]]; then
            # Its home-manager part: the whole generation needs --impure and
            # nix-on-droid's proot (builtins.storePath), present only on a device.
            attr="nixOnDroidConfigurations.$name.config.home-manager.config.home.activationPackage.drvPath"
          else
            attr="nixosConfigurations.$name.config.system.build.toplevel.drvPath"
          fi
          if ! nix eval --raw "$root#$attr" >/dev/null; then
            echo "new-host: $dir was created but doesn't evaluate yet; fix the error above." >&2
            exit 1
          fi
          echo "OK: $attr evaluates."

          case $kind in
            nixos) echo "Install: disko-install or nixos-anywhere with --flake $root#$name (formats $disk)." ;;
            wsl) echo "Build the WSL tarball from it: see NixOS-WSL's docs (nixos-wsl.nixosModules.default)." ;;
            home) echo "On that machine: home-manager switch --flake <repo>#$user@$name, then 'hms'." ;;
            droid) echo "In the Nix-on-Droid app: clone the repo to ~/nix-config, nix-on-droid switch --flake ~/nix-config#$name, then 'reb'." ;;
          esac
        '';
      };
    in
    {
      apps.new-host = {
        type = "app";
        program = lib.getExe new-host;
        meta.description = "Create a host in modules/hosts from a template";
      };
    };
}
