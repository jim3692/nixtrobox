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
      "--pull=always"
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
        "/etc/profiles/per-user/${username}/share/terminfo"
        "/nix/var/nix/profiles/default/share/terminfo"
        "/run/current-system/sw/share/terminfo"
      ]);
    };
    entrypoint = with pkgs;
      let
        idCommand = "${coreutils}/bin/id";
        gitCommand = "${git}/bin/git";
        executeOnHost = "nsenter -t 1 -m -u -n -i";

        hostRuntimeDir = "/run/host/run/user";

        initScript = writeShellScriptBin "init" ''
          # Install host-spawn
          ${distrobox}/bin/distrobox-host-exec --yes yes

          # Get User and Group IDs from host
          read -r uid gid <<<$(
            ${executeOnHost} ${bash}/bin/bash -c 'printf "%s %s\n" `${idCommand} -u ${username}` `${idCommand} -g ${username}`'
          )

          # Bind mount host's $XDG_RUNTIME_DIR to container
          mkdir -p /run/user/$uid
          echo "Waiting for /run/user/$uid to appear ..."
          [ ! -d ${hostRuntimeDir}/$uid ] && ${inotify-tools}/bin/inotifywait -e create,moved_to,attrib --include "/$uid" -qq $hostRuntime
          mount --rbind -o rslave ${hostRuntimeDir}/$uid /run/user/$uid

          # Execute distrobox's inialization
          ${distrobox}/bin/distrobox-init \
            -n ${username} \
            -u $uid -g $gid \
            -d ${home} \
            --additional-packages "${builtins.toString additionalPackages}"
        '';
      in "${initScript}/bin/init";
  };
}
