# modules/hardware/disko.nix - Per-host disko template (intentionally a no-op)
#
# This module is imported by modules/hardware/default.nix but defines nothing
# on its own. Real disk layouts (LUKS, Btrfs, etc.) live per host in
# hosts/*/disko.nix. Keep this placeholder so the hardware aggregator has a
# stable import point for shared disko defaults if they are ever needed.
{ lib, ... }:

{
}
