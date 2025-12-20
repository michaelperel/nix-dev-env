{
  description = "Nix dev image optimized for rootless Podman with --userns=keep-id";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        isLinux = pkgs.stdenv.isLinux;
        # isDarwin = pkgs.stdenv.isDarwin;

        # ---------------- Cross-platform Packages ----------------
        commonPackages = with pkgs; [
          # Shell & UX
          bash
          bash-completion
          cacert
          coreutils
          gnugrep
          gnused
          gawk
          file
          less
          watch
          man
          procps
          ncurses
          which

          # Editors & utils
          vim
          nano
          tree
          jq
          zip
          unzip
          gnutar
          xz

          # Networking & diagnostics
          openssh
          curl
          wget
          netcat
          bind
          nmap
          lsof
          tcpdump
          iftop

          # Dev & build
          git
          gnumake
          shellcheck
          tmux
          htop
          gcc
          go
          gotools
          golangci-lint
          gopls
          delve
          python3
          python3Packages.pip
          python3Packages.flake8
          python3Packages.black
          nodejs
          nodePackages.eslint
          nodePackages.prettier
          podman
          postgresql
          sqlite
          doctl
        ];

        # ---------------- Linux-only Packages ----------------
        linuxPackages = with pkgs; [
          # Users
          shadow

          # Networking & diagnostics (Linux-specific)
          traceroute
          iputils
          iproute2

          # Dev & build (Linux-specific)
          glibc.dev

          # Init
          tini
        ];

        # ---------------- All Packages ----------------
        allPackages = commonPackages ++ (if isLinux then linuxPackages else []);

        mergedEnv = pkgs.buildEnv {
          name = "dev-env";
          paths = allPackages;
          pathsToLink = [ "/bin" "/share" ];
        };

        # ---- Shell snippets for /etc/profile.d ----
        profileEnv = pkgs.writeText "00-env.sh" ''
          export LANG=C.UTF-8
          export LC_ALL=C.UTF-8
          export CC=gcc

          # TLS trust
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export SSL_CERT_DIR=${pkgs.cacert}/etc/ssl/certs
        '';

        profileCompletion = pkgs.writeText "10-completion.sh" ''
          . ${pkgs.bash-completion}/share/bash-completion/bash_completion
        '';

        profilePrompt = pkgs.writeText "20-prompt.sh" ''
          shopt -s histappend cmdhist checkwinsize
          export HISTSIZE=100000
          export HISTFILESIZE=200000
          export HISTCONTROL=ignoredups:erasedups
          export PROMPT_COMMAND='history -a; history -n; '"$PROMPT_COMMAND"

          . ${pkgs.git}/share/git/contrib/completion/git-prompt.sh

          export GIT_PS1_SHOWDIRTYSTATE=1
          export GIT_PS1_SHOWUPSTREAM=auto

          # Define colors (shell variables)
          RED='\[\033[0;31m\]'
          GREEN='\[\033[0;32m\]'
          BLUE='\[\033[0;34m\]'
          YELLOW='\[\033[0;33m\]'
          CYAN='\[\033[0;36m\]'
          RESET='\[\033[0m\]'

          # Prompt: [nix-dev] user@host:cwd (gitbranch)
          PS1="''${BLUE}[nix-dev]''${RESET} ''${GREEN}\u@\h''${RESET}:''${YELLOW}\w''${RESET}"
          # Escape `$` so __git_ps1 runs each time the prompt is drawn.
          PS1+="''${CYAN}\$(__git_ps1 ' (%s)')''${RESET}\$ "

          alias ll='ls -alF'
          alias la='ls -A'
          alias l='ls -CF'
          command -v grep >/dev/null 2>&1 && alias grep='grep --color=auto'
          command -v ls   >/dev/null 2>&1 && alias ls='ls --color=auto'
        '';

        userBashrc = pkgs.writeText "user.bashrc" ''
          if [ -f /etc/profile ]; then . /etc/profile; fi
        '';

        # ---- Installable bundle for "nix profile install .#profileEnv" ----
        profileEnvPkg = pkgs.runCommand "profile-env-1.0" { } ''
          mkdir -p "$out/share/profile.d" "$out/share/skel"
          cp ${profileEnv}        "$out/share/profile.d/00-env.sh"
          cp ${profileCompletion} "$out/share/profile.d/10-completion.sh"
          cp ${profilePrompt}     "$out/share/profile.d/20-prompt.sh"
          cp ${userBashrc}        "$out/share/skel/.bashrc"
        '';
      in
      {
        # ---------------- nix develop shell ----------------
        devShells.default = pkgs.mkShell {
          name = "dev-env";
          packages = allPackages;
          shellHook = ''
            . ${profileEnv}
            . ${profileCompletion}
            . ${profilePrompt}
          '';
        };

        # ---------------- merged environment ----------------
        packages = {
          # default installable package
          default = mergedEnv;

          # profile bundle for nix profile
          profileEnv = profileEnvPkg;
        } // pkgs.lib.optionalAttrs isLinux {
          # Container image (Linux only)
          containerImage = pkgs.dockerTools.buildImage {
            name = "dev-env";
            tag  = "latest";

            copyToRoot = mergedEnv;

            extraCommands = ''
              #!${pkgs.bash}/bin/bash
              set -euxo pipefail

              # `extraCommands` runs while assembling the image filesystem tree.
              # Use relative paths so we write into the image root, not the builder's real '/'.
              mkdir -p etc/profile.d etc/skel root tmp app home/nonroot etc/ssl
              chmod 1777 tmp
              chmod 0777 app
              # Make HOME writable without relying on chown/fakeroot
              chmod 0777 home/nonroot

              # Global profile loader
              cat > etc/profile <<"EOF"
for f in /etc/profile.d/*.sh; do
  . "$f"
done
EOF

              # Profile snippets
              install -m 0644 ${profileEnv}        etc/profile.d/00-env.sh
              install -m 0644 ${profileCompletion} etc/profile.d/10-completion.sh
              install -m 0644 ${profilePrompt}     etc/profile.d/20-prompt.sh

              # Skeleton files
              install -m 0644 ${userBashrc} etc/skel/.bashrc
              # `useradd --create-home` would normally copy this into the user's home.
              # Since we don't run useradd/groupadd during image assembly, do it explicitly.
              install -m 0644 ${userBashrc} home/nonroot/.bashrc

              # --- Users ---
              # Avoid useradd/groupadd here: during dockerTools image assembly we may not have
              # all the OS config files those tools expect. For containers, minimal passwd/group
              # entries are sufficient for `User = "nonroot"` to resolve.
              cat > etc/passwd <<"EOF"
root:x:0:0:root:/root:/bin/bash
nonroot:x:1000:1000:nonroot:/home/nonroot:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

              cat > etc/group <<"EOF"
root:x:0:
nonroot:x:1000:
nogroup:x:65534:
EOF

              echo '. /etc/profile' > etc/bash.bashrc

              # TLS trust (ensure it's a symlink, not a directory)
              rm -rf etc/ssl/certs
              ln -sfn ${pkgs.cacert}/etc/ssl/certs etc/ssl/certs
            '';

            config = {
              Entrypoint = [ "/bin/tini" "--" ];
              User = "nonroot";
              WorkingDir = "/app";
              Cmd = [ "bash" "-l" "-i" ];
            };
          };
        };
      }
    );
}
