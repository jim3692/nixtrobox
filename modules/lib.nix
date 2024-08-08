{ pkgs }:

let lib = pkgs.lib;

in {
  getArchContainer = { username, home, additionalPackages ? [ ] }: {
    image = "archlinux:latest";
    extraOptions = [
      "--privileged"
      "--security-opt=label=disable"
      "--security-opt=apparmor=unconfined"
      "--pids-limit=-1"
      "--user=root:root"
      "--ipc=host"
      "--network=host"
      "--pid=host"
    ];
    volumes = [
      "/:/run/host:rslave"
      "/tmp:/tmp:rslave"
      "/dev:/dev:rslave"
      "/sys:/sys:rslave"
      "${home}:${home}:rslave"
      "/nix/store:/nix/store:ro"
      "/etc/hosts:/etc/hosts:ro"
      "/etc/resolv.conf:/etc/resolv.conf:ro"
    ] ++ mounts;
    environment = {
      container = "docker";
      SHELL = "/bin/bash";
      HOME = home;
      TERMINFO_DIRS = (lib.strings.concatStringsSep ":" [
        "/usr/share/terminfo"
        "${home}/.nix-profile/share/terminfo"
        "/nix/profile/share/terminfo"
        "${home}/.local/state/nix/profile/share/terminfo"
        "/etc/profiles/per-user/alice/share/terminfo"
        "/nix/var/nix/profiles/default/share/terminfo"
        "/run/current-system/sw/share/terminfo"
      ]);
    };
    entrypoint = with pkgs;
      let
        idCommand = "${coreutils}/bin/id";
        executeOnHost = "nsenter -t 1 -m -u -n -i";
        initScript = writeShellScriptBin "init" ''
          read -r uid gid <<<$(
            ${executeOnHost} ${bash}/bin/bash -c 'printf "%s %s\n" `${idCommand} -u ${username}` `${idCommand} -g ${username}`'
          )

          mkdir -p /run/user/$uid

          hostRuntime="/run/host/run/user"
          echo "Waiting for /run/user/$uid to appear ..."
          [ ! -d $hostRuntime/$uid ] && ${inotify-tools}/bin/inotifywait -e create,moved_to,attrib --include "/$uid" -qq $hostRuntime
          mount --rbind -o rslave $hostRuntime/$uid /run/user/$uid

          ${distrobox}/bin/distrobox-init \
            -n ${username} \
            -u $uid -g $gid \
            -d ${home} \
            --additional-packages "${builtins.toString additionalPackages}"
        '';
      in "${initScript}/bin/init";
  };
}
