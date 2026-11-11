{
  homeManager.base = { pkgs, ... }: {
    programs.zellij = {
      enable = true;
      enableZshIntegration = true;
      plugins = with pkgs.zellijPlugins; [ vim-zellij-navigator ];
      settings = {
        show_startup_tips = false;
      };
    };
  };
}
