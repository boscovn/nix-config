---
name: verify
description: Check that a change to these dotfiles evaluates and builds, without switching. Use after editing any module, before telling the user a change is done or committing it.
---

# Verify a dotfiles change

Never switch (`nh os switch`, `nh home switch`, `nixos-rebuild switch`): that is the user's call. Building is fine.

1. **New files are staged.** The flake only sees tracked files: `git status --short` and `git add <file>` for each new file you created (by name; never `-A`/`-u`).
2. **Formatting.** `nix fmt` (the post-edit hook already formats edited `.nix` files; this catches the rest).
3. **Evaluation** of every configuration the change can touch. Fast; run both unless the change is clearly one-sided:
   ```bash
   nix eval --raw .#nixosConfigurations.thinkpad.config.system.build.toplevel.drvPath
   nix eval --raw '.#homeConfigurations."bosco@thinkpad".activationPackage.drvPath'
   ```
   For hosts other than thinkpad, list them with `nix eval .#nixosConfigurations --apply builtins.attrNames` and `nix eval .#homeConfigurations --apply builtins.attrNames`.
4. **Build and diff** when the change affects packages or generated files:
   ```bash
   nh os build ~/nix-config     # system + embedded home-manager, prints the package diff
   nh home build ~/nix-config   # standalone home-manager
   ```
   Inspect generated files in the result (e.g. `nix build --no-link --print-out-paths '.#homeConfigurations."bosco@thinkpad".activationPackage'`, then `home-files/...`) when the change is about their content.
5. **Portability**, when `homeManager.base` changed: the throwaway aarch64-darwin host from CLAUDE.md ("Checking portability"), then delete it.
6. **`nix flake check`** before committing changes to `modules/flake/` or templates.

Report what ran and what didn't, and remind the user to `reb`/`hms` to apply.
