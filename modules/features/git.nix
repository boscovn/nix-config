{ config, ... }:
{
  homeManager.base =
    { lib, pkgs, ... }:
    {
      programs.git = {
        enable = true;
        settings.user = {
          name = config.my.fullName;
          inherit (config.my) email;
        };
        # glab as credential helper for GitLab (what `glab auth login` would
        # write to the read-only config); gh does the same for GitHub through
        # programs.gh.gitCredentialHelper. The empty entry resets other helpers.
        settings.credential."https://gitlab.com".helper = [
          ""
          "!${lib.getExe pkgs.glab} auth git-credential"
        ];
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
