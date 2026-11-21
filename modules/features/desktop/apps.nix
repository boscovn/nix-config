# Desktop applications and Linux hardware tools.
{
  homeManager.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        android-tools
        corefonts
        firefox
        kdePackages.dolphin
        liberation_ttf
        libva-utils
        onlyoffice-desktopeditors
        pavucontrol
        telegram-desktop
        usbutils
        v4l-utils
        vista-fonts
        wdisplays # arrange displays live (wlr-output-management); not saved
      ];
      programs.foot.enable = true;
      programs.obsidian.enable = true;
      programs.zathura = {
        enable = true;
        # Selected text goes to the PRIMARY selection by default (middle-click
        # paste only); send it to the regular clipboard (Ctrl+V) instead.
        options.selection-clipboard = "clipboard";
      };
      xdg.mimeApps = {
        enable = true;
        defaultApplications."application/pdf" = [ "org.pwmt.zathura.desktop" ];
        # Without it, KDE apps (KDE Connect's "browse device") fall back to
        # another inode/directory handler such as zathura's comic-book reader.
        defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
      };
    };
}
