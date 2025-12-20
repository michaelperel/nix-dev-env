# Base image
FROM fedora

# Preseed nix.conf so the installer doesn't look for the nixbld group
# and enable flakes + nix-command up front.
RUN mkdir -p /etc/nix && \
    printf '%s\n' \
      'build-users-group =' \
      'experimental-features = nix-command flakes' \
      'sandbox = false' \
    > /etc/nix/nix.conf

# Install Nix using the official installer (single-user, good for containers)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes

ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

WORKDIR /tmp
COPY flake.nix flake.lock ./

# Install the dev environment and profile bundle into *root's* nix profile
RUN nix profile install .#default && \
    nix profile install .#profileEnv

# Set up system-wide profile scripts for login + interactive shells
RUN mkdir -p /etc/profile.d /etc/skel /app && \
    cp /nix/var/nix/profiles/per-user/root/profile/share/profile.d/*.sh /etc/profile.d/ && \
    cp /nix/var/nix/profiles/per-user/root/profile/share/skel/.bashrc /etc/skel/.bashrc && \
    echo '. /etc/profile' > /etc/bash.bashrc

# Create nonroot user (uid=1000, gid=1000)
RUN groupadd --gid 1000 nonroot && \
    useradd --create-home --uid 1000 --gid nonroot --shell /bin/bash nonroot && \
    chown --recursive nonroot:nonroot /home/nonroot

# Symlink system certs to the Nix cacert bundle
RUN . /nix/var/nix/profiles/per-user/root/profile/share/profile.d/00-env.sh && \
    ln -snf "$SSL_CERT_DIR" /etc/ssl/certs

WORKDIR /app

# Drop to nonroot user
USER nonroot

# tini comes from nix profile on PATH; run it as PID 1
ENTRYPOINT ["tini", "--"]

# Login + interactive bash by default
CMD ["/bin/bash", "-l", "-i"]
