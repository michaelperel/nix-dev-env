# Base image - Microsoft's GitHub Codespaces universal image
FROM mcr.microsoft.com/devcontainers/universal:2

# Preseed nix.conf to enable flakes + nix-command
RUN mkdir -p /etc/nix && \
    printf '%s\n' \
      'build-users-group =' \
      'experimental-features = nix-command flakes' \
      'sandbox = false' \
    > /etc/nix/nix.conf

# Install Nix using the official installer (single-user)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes

# Add Nix to PATH
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
