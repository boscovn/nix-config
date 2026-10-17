# Defaults for where I live; a host elsewhere overrides them.
{
  nixos.base =
    { lib, ... }:
    {
      time.timeZone = lib.mkDefault "Europe/Madrid";
      i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";
      # Regional formats (dates, currency, paper size, ...).
      i18n.extraLocaleSettings = lib.genAttrs [
        "LC_ADDRESS"
        "LC_IDENTIFICATION"
        "LC_MEASUREMENT"
        "LC_MONETARY"
        "LC_NAME"
        "LC_NUMERIC"
        "LC_PAPER"
        "LC_TELEPHONE"
        "LC_TIME"
      ] (_: lib.mkDefault "es_ES.UTF-8");
      services.xserver.xkb = {
        layout = lib.mkDefault "es";
        variant = lib.mkDefault "";
      };
      console.keyMap = lib.mkDefault "es";
    };

  # Android keeps its own locale and keyboard; only the clock for Nix programs.
  nixOnDroid.base =
    { lib, ... }:
    {
      time.timeZone = lib.mkDefault "Europe/Madrid";
    };
}
