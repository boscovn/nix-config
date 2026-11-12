{
  homeManager.base =
    { pkgs, ... }:
    let
      # Ctrl+hjkl: vim-zellij-navigator forwards the key to the pane when it
      # runs nvim (zellij-nav.nvim in ~/nvim then moves between nvim windows,
      # handing back to zellij at the edge); otherwise it moves zellij's focus.
      # h/l continue into the neighbouring tab at the edge of the screen.
      navigate = key: name: payload: {
        bind = {
          _args = [ "Ctrl ${key}" ];
          _children = [
            {
              MessagePlugin = {
                _args = [ "vim-zellij-navigator" ];
                inherit name payload;
              };
            }
          ];
        };
      };
    in
    {
      programs.zellij = {
        enable = true;
        enableZshIntegration = true;
        plugins = with pkgs.zellijPlugins; [ vim-zellij-navigator ];
        settings = {
          show_startup_tips = false;
          keybinds._children = [
            {
              shared_except = {
                _args = [ "locked" ];
                _children = [
                  (navigate "h" "move_focus_or_tab" "left")
                  (navigate "j" "move_focus" "down")
                  (navigate "k" "move_focus" "up")
                  (navigate "l" "move_focus_or_tab" "right")
                ];
              };
            }
            # Ctrl h was zellij's key for move mode (entering and leaving it)
            {
              shared_except = {
                _args = [
                  "move"
                  "locked"
                ];
                bind = {
                  _args = [ "Alt m" ];
                  SwitchToMode = "move";
                };
              };
            }
            {
              move.bind = {
                _args = [ "Alt m" ];
                SwitchToMode = "normal";
              };
            }
          ];
        };
      };
    };
}
