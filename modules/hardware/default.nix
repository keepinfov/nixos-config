# modules/hardware/default.nix - Hardware modules index
{ ... }:

{
  imports = [
    ./base.nix
    ./nvidia.nix
    ./power.nix
    ./disko.nix
  ];
}
