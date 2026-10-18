#!/bin/bash
# release hook for the win11 VM: bring the host back after the VM stops.
#
# libvirt has already re-attached the GPU, its audio function and the USB
# 3.2 controller to their host drivers (managed='yes' hostdevs) before this
# runs, so there is no PCI work here — just restart what start.sh stopped
# and remount the WD data disk the VM was holding.
set -e

mount /mnt/d 2>/dev/null || true

# put nvidia-persistenced back (start.sh stopped it); it re-enables
# persistence on the 4090 now that the card is on the host again
systemctl start nvidia-persistenced.service 2>/dev/null || echo "    (nvidia-persistenced not present)"

# reapply power limits
systemctl restart nvidia-power-limit.service

sleep 1
echo "==> nvidia-smi check:"
nvidia-smi -L

echo "==> Restarting llama-swap (both GPUs available again)"
docker restart llama-swap 2>/dev/null || echo "    (couldn't restart llama-swap — check it manually)"

echo "==> Starting penguin-burnerd"
# systemctl start penguin-burnerd.service 2>/dev/null || echo "    (couldn't start penguin-burnerd — check it manually)"
/home/cam/.local/bin/pburn-apply-profiles.sh
