{
  description = "A flake providing a NixOS optimized distrobox wrapper";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosModules = { default = ./modules; };
  };
}
