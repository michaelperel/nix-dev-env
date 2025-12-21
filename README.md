## Quickstart (Nix)

Prereqs:

- Nix installed
- Flakes enabled (`nix-command` + `flakes`)

Enter the dev shell:

```bash
nix develop
```

## Container image (built by Nix, Linux only)

Build the image:

```bash
nix build .#containerImage
```

Load it into Podman and run:

```bash
podman load < result
podman run --rm -it --userns=keep-id nix-dev-env:latest
```

If `podman load` fails with “no policy.json file found”, create a minimal policy file (dev-only) or install your distro’s `containers-common` package:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/containers"
cat > "${XDG_CONFIG_HOME:-$HOME/.config}/containers/policy.json" <<'EOF'
{
	"default": [
		{ "type": "insecureAcceptAnything" }
	]
}
EOF
```

If you see an error mentioning `newuidmap`/`newgidmap` not being setuid (common on rootless Podman), install the system `uidmap` package:

```bash
sudo apt-get update && sudo apt-get install -y uidmap
podman load < result
```

Notes:

- The image runs as a non-root user by default and uses `tini` as PID 1.
- `--userns=keep-id` is recommended for rootless Podman so files created in bind mounts map cleanly to your host UID/GID.

## Container image (without Nix)

If you don’t have Nix installed, you can build the included `Dockerfile`. It installs Nix inside the container and then installs this flake’s environment into the image.

Using Podman:

```bash
podman build -t nix-dev-env .
podman run --rm -it --userns=keep-id nix-dev-env
```

Using Docker:

```bash
docker build -t nix-dev-env .
docker run --rm -it nix-dev-env
```