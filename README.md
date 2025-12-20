## Quickstart (Nix)

Prereqs:

- Nix installed
- Flakes enabled (`nix-command` + `flakes`)

Enter the dev shell:

```bash
nix develop
```

If you want to run without writing/using a lock file:

```bash
nix develop . --no-write-lock-file
```

## Container image (built by Nix, Linux only)

Build the image:

```bash
nix build .#containerImage
```

Load it into Podman and run:

```bash
podman load < result
podman run --rm -it --userns=keep-id dev-env:latest
```

Notes:

- The image runs as a non-root user by default and uses `tini` as PID 1.
- `--userns=keep-id` is recommended for rootless Podman so files created in bind mounts map cleanly to your host UID/GID.

## Container image (without Nix)

If you don’t have Nix installed, you can build the included `Dockerfile`. It installs Nix inside the container and then installs this flake’s environment into the image.

Using Podman:

```bash
podman build -t dev-env .
podman run --rm -it --userns=keep-id dev-env
```

Using Docker:

```bash
docker build -t dev-env .
docker run --rm -it dev-env
```