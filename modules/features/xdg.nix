# Keeps ~ free of dotfiles: whatever can live under ~/.config, ~/.local/share,
# ~/.local/state or ~/.cache does. What stays in ~ has no alternative: bash's
# ~/.bashrc, ~/.bash_profile and ~/.profile, ~/.manpath (man-db, for
# `man.generateCaches` in cli-tools.nix), ~/.mozilla/native-messaging-hosts
# (gopass-jsonapi, where the browsers look) and ~/.zshenv off NixOS.
#
# Moving a path doesn't move what's already there: existing data (gnupg,
# cargo, rustup, go, ...) is moved by hand once, see each entry.
{
  # Nix's own ~/.nix-profile, ~/.nix-defexpr and ~/.nix-channels go to
  # ~/.local/state/nix (the profile already lives there, ~/.nix-profile is a
  # link to it). home-manager follows it through osConfig; standalone builds
  # (`hms`) are told with `nix.assumeXdg` below.
  nixos.base = {
    nix.settings.use-xdg-base-directories = true;

    # zsh reads ~/.zshenv only to learn ZDOTDIR; set it system-wide so the
    # file isn't needed (home-manager's copy is dropped below). Only for users
    # whose zsh config is there (root's isn't).
    programs.zsh.shellInit = ''
      if [[ -z $ZDOTDIR && -r $HOME/.config/zsh/.zshenv ]]; then
        export ZDOTDIR=$HOME/.config/zsh
      fi
    '';
  };

  homeManager.base =
    { config, lib, ... }:
    let
      inherit (config.xdg)
        configHome
        dataHome
        stateHome
        cacheHome
        ;
    in
    {
      xdg.enable = true;
      # Modules that support it on their own: gtk2 (~/.gtkrc-2.0), atuin's
      # logs (~/.atuin), readline, npm's npmrc.
      home.preferXdgDirectories = true;

      nix.assumeXdg = config.dotfiles.nixos;

      programs.zsh = {
        dotDir = "${configHome}/zsh";
        # mv ~/.zsh_history ~/.local/state/zsh/history
        history.path = "${stateHome}/zsh/history";
        completionInit = ''
          autoload -U compinit && compinit -d ${cacheHome}/zsh/zcompdump-$ZSH_VERSION
        '';
      };
      home.file.".zshenv".enable = lib.mkIf config.dotfiles.nixos false;
      # Also in the session's environment: terminals with shell integration
      # (ghostty) start zsh with their own ZDOTDIR, so /etc/zshenv skips, and
      # hand back only a ZDOTDIR they inherited (else they read ~/.zshenv).
      systemd.user.sessionVariables.ZDOTDIR = config.programs.zsh.dotDir;

      programs.bash.historyFile = "${stateHome}/bash/history";

      # mv ~/.gnupg ~/.local/share/gnupg (after `gpgconf --kill all`).
      programs.gpg.homedir = "${dataHome}/gnupg";
      # For user services too (mbsync's `gopass show` in email/).
      systemd.user.sessionVariables.GNUPGHOME = config.programs.gpg.homedir;

      # Nothing loads it on Wayland; it's written for XWayland clients that
      # read it by hand.
      xresources.path = "${configHome}/X11/xresources";

      # Its copy of the GTK theme in ~/.themes is for Flatpak apps (none here).
      stylix.targets.gtk.flatpakSupport.enable = false;

      # mv ~/go ~/.local/share/go
      programs.go.env.GOPATH = "${dataHome}/go";

      home.sessionVariables = {
        # mv ~/.cargo ~/.local/share/cargo; mv ~/.rustup ~/.local/share/rustup
        CARGO_HOME = "${dataHome}/cargo";
        RUSTUP_HOME = "${dataHome}/rustup";
        NPM_CONFIG_CACHE = "${cacheHome}/npm";
        DOCKER_CONFIG = "${configHome}/docker";
        GRADLE_USER_HOME = "${dataHome}/gradle";
        ANDROID_USER_HOME = "${dataHome}/android";
        KERAS_HOME = "${dataHome}/keras";
        CUDA_CACHE_PATH = "${cacheHome}/nv";
        W3M_DIR = "${dataHome}/w3m";
        PYTHON_HISTORY = "${stateHome}/python/history";
      };
    };
}
