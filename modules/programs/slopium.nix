# modules/programs/slopium.nix - Slopium language toolchain
#
# The options themselves come from inputs.slopium.nixosModules.default, which
# flake.nix adds to every host; this file only decides the policy.
{ lib, config, inputs, conf, ... }:

with lib;

let
  cfg = config.programs.slopium;
  userName = conf.user.name;
in
{
  config = mkMerge [
    # slopic, slopium, slopium-lsp and their shell completions, system-wide.
    # The overlay comes with it, so pkgs.slopium is available to other modules.
    { programs.slopium.enable = mkDefault true; }

    # The toolchain is system-wide; only the editor plugin is per-user, because
    # it lives under the user's Neovim data directory.
    (mkIf cfg.enable {
      home-manager.users.${userName} = {
        imports = [ inputs.slopium.homeModules.default ];

        programs.slopium.neovim = {
          enable = true;
          # lazy.nvim resets runtimepath by default, so a native package under
          # site/pack is never loaded without this spec.
          lazySpec = true;
        };
      };
    })
  ];
}
