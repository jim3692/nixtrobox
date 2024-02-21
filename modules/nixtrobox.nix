{ config, pkgs, ... }:

let myLib = import ./lib.nix { inherit pkgs; };
in {
  virtualisation.oci-containers.containers =
    builtins.mapAttrs (k: v: myLib.getArchContainer v)
    config.nixtrobox.containers;
}
