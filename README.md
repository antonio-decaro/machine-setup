# machine-setup
A repository to automatize the environment setup for clusters and shared machines.

## Quick install
Run from a local checkout:

```sh
sh install.sh
```

Or host `install.sh` and run it with curl/wget:

```sh
curl -fsSL https://example.com/install.sh | sh
```

This creates `~/.config/login` and a `~/.config/modules.conf` file.
Source `~/.config/login/*.sh` from your shell startup file (e.g. `.bash_profile` or `.zprofile`).
