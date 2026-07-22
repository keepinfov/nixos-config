# modules/user/default.nix - User-level (home-manager) configuration
{ conf, ... }:

let
  userName = conf.user.name;
in
{
  imports = [
    ./shell.nix
    ./packages.nix
  ];

  home-manager.users.${userName} = {
    home = {
      username = userName;
      homeDirectory = "/home/${userName}";
      stateVersion = conf.stateVersion;
    };

    programs.home-manager.enable = true;
  };
}
