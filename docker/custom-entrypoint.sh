#!/bin/sh

# Ensure Unbound log directory exists and has appropriate ownership
mkdir -p /var/log/unbound
chown unbound /var/log/unbound

# Start Unbound with error checking
echo "  [i] Starting Unbound"
/usr/sbin/unbound -d -c /etc/unbound/unbound.conf.d/pi-hole.conf &
UNBOUND_PID=$!

# Wait briefly and check if Unbound started successfully
sleep 1
if ps -p "$UNBOUND_PID" > /dev/null 2>&1; then
    echo "  [i] Unbound started successfully with PID $UNBOUND_PID"
else
    echo "  [i] ERROR: Unbound failed to start. Check /var/log/unbound.log for details."
    # Optionally exit to fail the container startup if Unbound is critical
    # exit 1
fi

# Call the original start.sh
exec /usr/bin/start.sh
