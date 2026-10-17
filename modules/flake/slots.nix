# Named lower-level modules. A feature file adds to `nixos.<name>`,
# `nixOnDroid.<name>` and/or `homeManager.<name>`; a host imports the names it wants. Each value is
# wrapped with a `key` (importing it twice is a no-op) and a `_class` (importing
# it into the wrong kind of configuration is an evaluation error).
{ lib, ... }:
let
  slot =
    class:
    lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      apply = lib.mapAttrs (
        name: module: {
          _class = class;
          key = "${class}/${name}";
          imports = [ module ];
        }
      );
      description = "Named ${class} modules; importing one enables its feature.";
    };
in
{
  options.nixos = slot "nixos";
  options.nixOnDroid = slot "nixOnDroid";
  options.homeManager = slot "homeManager";
}
