# llama-swap-watcher

This is very specific to my own setup, but sharing just in case it might be
helpful to someone else. I have two gpus and single/dual profiles in
llama-swap, and this CLI switches between them and frees GPU VRAM on demand.
The old sddm-watching daemon is retired: profile switching is now driven by
[mediabox-ctl](../mediabox-ctl), which calls this CLI.

As a bonus, the [qemu](qemu) directory contains start/release scripts for
libvirt to successfully unbind one of the gpus from Linux so it can be passed
through to the VM and then reattach it when the VM is done.

# AI description below

`llama-swap-cli` talks to the llama-swap HTTP API. The command is named
`llama-swap-cli` on purpose: the daemon's own binary is `llama-swap`, so the
CLI cannot take that name.

## Usage

`llama-swap-cli list` prints all profiles, with a `*` on the active one.

`llama-swap-cli status` prints only the active profile name (or `none`),
for scripts.

`llama-swap-cli set <profile>` switches the active profile. Once installed,
zsh completes profile names after `llama-swap-cli set`, reading them from the
llama-swap config file.

`llama-swap-cli unload` stops every loaded model via
`POST /api/models/unload`, freeing GPU VRAM. That call blocks until the model
processes stop (docker stop), so it can take a few seconds. llama-swap only
swaps models on demand, so switching the active profile does not unload an
already-loaded model; callers that need the VRAM back (like mediabox-ctl when
switching to linux-gaming) run `unload` explicitly after `set`.

`sudo ./install.sh` installs the command to `/usr/local/bin/llama-swap-cli`
and the completion to `/usr/local/share/zsh/site-functions/_llama-swap-cli`.
It also removes the retired `llama-swap-sddm.service` unit if an older install
left it behind.

## Configuration

The env overrides are `LLAMA_SWAP_URL` (daemon base URL, default
`http://localhost:8020`) and `LLAMA_SWAP_API_KEY` (sent as a Bearer token when
non-empty; this deployment has none). The zsh completion additionally reads
`LLAMA_SWAP_CONFIG` (the config file it lists profiles from, default
`$HOME/dotfiles/llama-swap/config.yaml`). Profile names are not configured
here; they live in the llama-swap config, and the caller (mediabox-ctl)
decides which ones to activate.
