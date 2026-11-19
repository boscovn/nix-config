{ config, ... }:
{
  homeManager.base = {
    programs.git = {
      enable = true;
      settings.user = {
        name = config.my.fullName;
        inherit (config.my) email;
      };
      # Global ignores (~/.config/git/ignore): direnv's per-project cache
      # (cli-tools.nix) and Claude Code's per-project local settings.
      ignores = [
        ".direnv/"
        "**/.claude/settings.local.json"
      ];
    };
    programs.gh.enable = true;
  };
}
