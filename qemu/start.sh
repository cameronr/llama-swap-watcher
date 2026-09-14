#!/bin/bash
# detach-gpu.sh — unbind the 4090 from nvidia, bind to vfio-pci
# Run with sudo. Run this manually before starting the VM if not using
# the libvirt hook, or to test the process by hand.
set -e

GPU_PCI="0000:01:00.0"
AUDIO_PCI="0000:01:00.1"
GPU_IDS="10de:2684"
AUDIO_IDS="10de:22ba"

USB_PCI="0000:0d:00.0"
USB_IDS="1022:43f7"

# Unmount d if it's mounted
umount /mnt/d 2>/dev/null || true

# NOTE: USB_PCI is the whole onboard USB 3.2 controller (K830 receiver +
# both Xbox controllers live on it). The moment this unbinds, your host
# keyboard/mouse on that controller go dead until attach-gpu.sh runs.
# If you're running this from that same keyboard, make sure you don't
# need to type anything else on the host afterward — SSH in from another
# machine first if you're not already on a separate input device.

echo "==> Stopping GPU-using services so the 4090 can be released cleanly"
docker stop llama-swap 2>/dev/null || echo "    (llama-swap already stopped or not found)"
systemctl stop penguin-burnerd.service 2>/dev/null || echo "    (penguin-burnerd already stopped)"
nvidia-smi -i 0 -pm 0

echo "==> Checking nothing has the 4090 open (nvidia module stays loaded for the 3090)"
if command -v nvidia-smi >/dev/null; then
  if nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader -i "$(nvidia-smi --query-gpu=index,pci.bus_id --format=csv,noheader | grep -i "${GPU_PCI#0000:}" | cut -d, -f1)" 2>/dev/null | grep -q .; then
    echo "    WARNING: a process still has the 4090 open. Unbind will likely fail."
    echo "    Check 'nvidia-smi' and make sure your inference workload is pinned to the 3090."
  fi
fi

echo "==> Unbinding GPU/audio/USB controller from current drivers"
for dev in "$GPU_PCI" "$AUDIO_PCI" "$USB_PCI"; do
  driver="/sys/bus/pci/devices/$dev/driver"
  if [ -e "$driver" ]; then
    echo "$dev" >"$driver/unbind"
  fi
done

echo "==> Loading vfio-pci and claiming device IDs"
modprobe vfio-pci
echo "$GPU_IDS" >/sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
echo "$AUDIO_IDS" >/sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
echo "$USB_IDS" >/sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true

echo "==> Binding to vfio-pci"
for dev in "$GPU_PCI" "$AUDIO_PCI" "$USB_PCI"; do
  echo "$dev" >/sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
done

echo "==> Done. Current drivers:"
lspci -k -s "${GPU_PCI#0000:}"
lspci -k -s "${AUDIO_PCI#0000:}"
lspci -k -s "${USB_PCI#0000:}"

echo "==> Restarting llama-swap (4090 is gone now, so this should land on the 3090)"
docker start llama-swap 2>/dev/null || echo "    (couldn't start llama-swap — check it manually)"
# penguin-burnerd stays down for the duration of the VM session;
# it's restarted in release.sh when the VM stops.
