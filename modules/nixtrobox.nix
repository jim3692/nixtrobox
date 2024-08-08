{ config, pkgs, ... }:

let myLib = import ./lib.nix { inherit pkgs; };
in {
  virtualisation.oci-containers.containers =
    builtins.mapAttrs (k: v: myLib.getArchContainer (
      let
        home = if v.home == "" then config.users.users.${v.username}.home else v.home;
      in v // { inherit home; }
    ))
    config.nixtrobox.containers;
}
