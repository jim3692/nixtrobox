{ pkgs }:

let
  lib = pkgs.lib;
  mkShims = binaries: ''
    set -e
    export PATH=$PATH:${pkgs.coreutils}/bin
    mkdir -p $out
    cd $out
    ${lib.strings.concatStrings (builtins.map (bin: "ln -s ${bin} $(basename ${bin})\n") binaries)}
  '';

in {
  getArchContainer = { username, home, mounts ? [ ], additionalPackages ? [ ] }: {
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
      "/nix:/nix:ro"
      "/run/current-system:/run/current-system:ro"
      "/etc/profiles:/etc/profiles:ro"
      "/etc/static/profiles:/etc/static/profiles:ro"
      "/etc/hosts:/etc/hosts:ro"
      "/etc/resolv.conf:/etc/resolv.conf:ro"

      # Prepend container's `passwd` and `sudo` to $PATH, to prevent conflicts with NixOS's versions
      "${derivation {
        name = "arch-shims";
        builder = "${pkgs.bash}/bin/bash";
        args = [ "-c" (mkShims [ "/usr/bin/passwd" "/usr/bin/sudo" ]) ];
        system = builtins.currentSystem;
      }}:/run/shims:ro"
      "${builtins.toFile "shims.sh" "export PATH=\"/run/shims:$PATH\""}:/etc/profile.d/shims.sh"
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
