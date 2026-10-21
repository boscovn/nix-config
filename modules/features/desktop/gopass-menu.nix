{
  # SUPER + G: gopass entries in fuzzel, then type or copy the password, a
  # field or the OTP (gopass-menu.sh).
  homeManager.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      gopass-menu = pkgs.writeShellApplication {
        name = "gopass-menu";
        runtimeInputs = [
          pkgs.gopass
          config.programs.fuzzel.package
          pkgs.wtype
          # gopass --clip copies (and clears) with wl-copy
          pkgs.wl-clipboard
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
        ];
        text = builtins.readFile ./gopass-menu.sh;
      };
    in
    {
      home.packages = [ gopass-menu ];
      wayland.windowManager.hyprland.settings.bind = [
        {
          _args = [
            "SUPER + G"
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${lib.getExe gopass-menu}")'')
          ];
        }
      ];
    };
}
