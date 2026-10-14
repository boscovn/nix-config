{
  homeManager.base = { pkgs, ... }: {
    home.packages = with pkgs; [ jellyfin-tui ];
  };
  homeManager.gui = { pkgs, ... }: {
    home.packages = with pkgs; [ jellyfin-desktop ];
  };
}
