#!/bin/bash
# attach-gpu.sh — unbind the 4090 from vfio-pci, restore the nvidia driver
# Run with sudo. Run this manually after stopping the VM if not using
# the libvirt hook, to get the card back for inference.
set -e

GPU_PCI="0000:01:00.0"
AUDIO_PCI="0000:01:00.1"
GPU_IDS="10de:2684"
AUDIO_IDS="10de:22ba"

USB_PCI="0000:0d:00.0"
USB_IDS="1022:43f7"

echo "==> Unbinding GPU/audio/USB controller from vfio-pci"
for dev in "$GPU_PCI" "$AUDIO_PCI" "$USB_PCI"; do
  driver="/sys/bus/pci/devices/$dev/driver"
  if [ -e "$driver" ]; then
    echo "$dev" >"$driver/unbind"
  fi
done

echo "==> Releasing vfio-pci device IDs"
echo "$GPU_IDS" >/sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true
echo "$AUDIO_IDS" >/sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true
echo "$USB_IDS" >/sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true

echo "==> nvidia module is already loaded (serving the 3090) — just re-probing devices"
for dev in "$GPU_PCI" "$AUDIO_PCI" "$USB_PCI"; do
  echo "$dev" >/sys/bus/pci/drivers_probe
done

nvidia-smi -i 0 -pm 1

sleep 1
echo "==> Done. Current drivers:"
lspci -k -s "${GPU_PCI#0000:}"
lspci -k -s "${AUDIO_PCI#0000:}"
lspci -k -s "${USB_PCI#0000:}"

echo "==> nvidia-smi check:"
nvidia-smi -L

echo "==> Restarting llama-swap (both GPUs available again)"
docker restart llama-swap 2>/dev/null || echo "    (couldn't restart llama-swap — check it manually)"

echo "==> Starting penguin-burnerd"
systemctl start penguin-burnerd.service 2>/dev/null || echo "    (couldn't start penguin-burnerd — check it manually)"
