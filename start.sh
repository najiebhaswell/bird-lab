#!/bin/bash

# Find the management interface. We'll run dhclient on it.
# Assuming the mgmt interface is the one that has a default route or we simply run dhclient on all interfaces.
# Running dhclient will test all interfaces and succeed on the mgmt one, but it might take time testing ptp links.
# Let's identify the mgmt interface. In docker compose we can assign it MAC address or just let dhclient find it.
# Actually, it's safer to just run `dhclient` and let it broadcast on all interfaces. The PTP bridges don't have DHCP servers anyway.
echo "Starting DHCP client..."
dhclient -v

# Wait a moment for IP to be assigned
sleep 2

echo "Management IP Configuration:"
ip -4 addr show

echo "Flushing IPv4 from PTP interfaces..."
for iface in $(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1); do
    if ip -6 addr show dev "$iface" | grep -q "2401:1700:1:"; then
        ip -4 addr flush dev "$iface"
    fi
done

# Override router ID in BIRD config explicitly using container's main IP if we want, or let BIRD pick it up.
# For BIRD to work, we need to bring up loopback
ip link set lo up
if [ -n "$LOOPBACK_IP" ]; then
    echo "Adding loopback IP: $LOOPBACK_IP"
    ip addr add "$LOOPBACK_IP/32" dev lo
fi

echo "Starting SSH server..."
service ssh start

echo "Starting BIRD..."
mkdir -p /run/bird
bird -c /etc/bird/bird.conf

# Keep container running and tail syslog for BIRD if needed
tail -f /dev/null
