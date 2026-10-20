# Portable CLI tooling. Prefer a programs.<name>.enable module when
# home-manager has one (config/theming/shell integration for free); the rest are
# plain packages. Desktop/hardware tools live in the gui bundle. Not available
# to root/sudo sessions, by design.
{ inputs, ... }:
{
  homeManager.base =
    { lib, pkgs, ... }:
    let
      # Claude Code plugins run their hooks and MCP servers with node / npx,
      # uvx or python3, which a NixOS system doesn't have unless declared.
      # They're on claude's own PATH (inherited by what it starts), not
      # everyone's; appended, so a project's dev shell tools win. Also the
      # language servers of the LSP plugins (nixd is in home.packages) and
      # mcp-nixos, which the dotfiles' .mcp.json starts.
      claude-code = pkgs.symlinkJoin {
        inherit (pkgs.claude-code) name meta;
        paths = [ pkgs.claude-code ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude --suffix PATH : ${
            lib.makeBinPath [
              pkgs.nodejs
              pkgs.uv
              pkgs.python3
              pkgs.lua-language-server
              pkgs.pyright
              pkgs.mcp-nixos
            ]
          }
        '';
      };

      # trashy 2.0.0's generated zsh completion has two rest-argument specs
      # (`trash <paths>` and `trash <subcommand> ...`), which zsh rejects on
      # every Tab ("doubled rest argument definition"). Patched: the first
      # argument offers subcommands and files, and when it isn't a subcommand
      # the rest complete as files. The subcommand is then $line[1], not [2].
      # --replace-fail makes a changed upstream file fail the build.
      trashy = pkgs.symlinkJoin {
        inherit (pkgs.trashy) name meta;
        paths = [ pkgs.trashy ];
        postBuild = ''
          f=$out/share/zsh/site-functions/_trash
          rm "$f"
          cp ${pkgs.trashy}/share/zsh/site-functions/_trash "$f"
          substituteInPlace "$f" \
            --replace-fail ${lib.escapeShellArg "'*::paths -- The paths to put into the trash:_files' \\\n\":: :_trash_commands\" \\"} ${lib.escapeShellArg "\":: :_trash_first_arg\" \\"} \
            --replace-fail '$line[2]' '$line[1]' \
            --replace-fail ${lib.escapeShellArg "        esac\n    ;;\nesac\n}"} ${lib.escapeShellArg "            (*)\n_files && ret=0\n;;\n        esac\n    ;;\nesac\n}"} \
            --replace-fail ${lib.escapeShellArg "(( $+functions[_trash_commands] )) ||"} ${lib.escapeShellArg "_trash_first_arg() {\n    _alternative 'commands:command:_trash_commands' 'files:file:_files'\n}\n\n(( $+functions[_trash_commands] )) ||"}
        '';
      };
    in
    {
      programs = {
        bat.enable = true;
        fd.enable = true;
        go.enable = true;
        # Builds the mandb index so `man -k`/apropos work (Telescope man_pages,
        # :Man completion); off by default, so `man -k .` finds nothing.
        man.generateCaches = true;
        ripgrep.enable = true;
        yazi = {
          enable = true;
          shellWrapperName = "y";
        };
        # Per-project dev shells on `cd`: `use flake` / `use devenv` in .envrc,
        # then `direnv allow`. nix-direnv caches them in .direnv/ (globally
        # git-ignored, git.nix) as GC roots, re-evaluating only when the
        # flake/devenv files change.
        devenv = {
          enable = true;
          enableZshIntegration = true;
          enableBashIntegration = true;
        };
        direnv = {
          enable = true;
          nix-direnv.enable = true;
          silent = true;
        };
      };

      home.packages =
        with pkgs;
        [
          claude-code
          gopass
          inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
          jq
          just
          nixd
          nixfmt
          opensc
          ouch
          pcsc-tools
          wget
        ]
        # trashy is Linux-only (freedesktop trash spec).
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ trashy ];
    };
}
