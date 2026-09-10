# llama-swap-watcher

A small CLI client for the llama-swap model-swap daemon's profile API, plus a
systemd service that keeps the active profile in sync with the sddm display
manager. The desktop profile runs while sddm is up, the headless profile when
it is down.

Two artifacts: `llama-swap-cli`, the command, and `llama-swap-sddm.service`,
the unit that runs `llama-swap-cli watch` forever. `install.sh` puts both on
the machine. The command is named `llama-swap-cli` on purpose: the daemon's
own binary is `llama-swap`, so the CLI cannot take that name.

## Usage

`llama-swap-cli list` prints all profiles, with a `*` on the active one.

`llama-swap-cli set <profile>` switches the active profile. Once installed,
zsh completes profile names after `llama-swap-cli set`, reading them from the
llama-swap config file.

`llama-swap-cli unload` stops every loaded model via
`POST /api/models/unload`, freeing GPU VRAM.

`sudo ./install.sh` installs the command to `/usr/local/bin/llama-swap-cli`,
the completion to `/usr/local/share/zsh/site-functions/_llama-swap-cli`, the
unit to `/etc/systemd/system/`, then runs `systemctl daemon-reload` and
`systemctl enable --now`.

## How the service behaves

`llama-swap-cli watch` polls `systemctl is-active sddm` every 2 seconds. When
sddm is `active` or `activating`, the profile becomes `vllm-3090`; in every
other state it becomes `vllm-dual`. The watcher acts on transitions only. If
the right profile is already active it does nothing, so a healthy setup
generates no API traffic. If the daemon is unreachable, the watcher retries
every 10 seconds instead of exiting, which is why the unit's
`Restart=on-failure` never trips during a daemon outage.

When a switch to the desktop profile (`vllm-3090`) succeeds, the CLI follows
up with `POST /api/models/unload` so no model keeps the 3090's VRAM while
hyprland runs. That call blocks until the model processes stop (docker
stop), so the first switch after a headless session takes a few extra
seconds. The unload is best effort: if it fails the profile switch stays in
place and a warning is printed. Switches to other profiles, and a no-op set
of the already-active profile, do not unload anything.

## Configuration

The env overrides are `LLAMA_SWAP_URL` (daemon base URL, default
`http://localhost:8020`), `LLAMA_SWAP_API_KEY` (sent as a Bearer token when
non-empty; this deployment has none), and `LLAMA_SWAP_POLL` (watcher poll
interval in seconds, default 2). The zsh completion additionally reads
`LLAMA_SWAP_CONFIG` (the config file it lists profiles from, default
`$HOME/dotfiles/llama-swap/config.yaml`). The profile names themselves are not env vars:
`PROFILE_DESKTOP` and `PROFILE_HEADLESS` sit at the top of `llama-swap-cli`.
