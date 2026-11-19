{ config, ... }:
{
  homeManager.base =
    { lib, ... }:
    {
      programs.git = {
        enable = true;
        settings.user = {
          name = config.my.fullName;
          # Hosts can override it (weasel uses its workplace address).
          email = lib.mkDefault config.my.email;
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
