{ lib, ... }: {
  options = with lib; {
    nixtrobox = {
      containers = mkOption {
        default = { };
        type = types.attrsOf (types.submodule ({ ... }: {
          options = {
            username = mkOption { type = types.str; };
            home = mkOption { type = types.str; default = ""; };
            mounts = mkOption {
              type = with types; listOf str;
              default = [ ];
            };
            additionalPackages = mkOption {
              type = with types; listOf str;
              default = [ ];
            };
          };
        }));
      };
    };
  };
}
