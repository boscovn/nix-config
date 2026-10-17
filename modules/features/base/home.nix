{
  homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.dotfiles.gui = lib.mkEnableOption "the Linux desktop session (set by the gui bundle)";

      config.home = {
        username = config.dotfiles.user;
        # Nix-on-Droid sets its own (fixed) home directory.
        homeDirectory = lib.mkDefault (
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Users/${config.dotfiles.user}"
          else
            "/home/${config.dotfiles.user}"
        );
      };
    };
}
