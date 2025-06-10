#!/bin/bash

set -e

apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg arch=$(dpkg --print-architecture)] https://packages.clickhouse.com/deb stable main" \
    | tee /etc/apt/sources.list.d/clickhouse.list
apt-get update -y

DEBIAN_FRONTEND=noninteractive apt-get install -y clickhouse-server clickhouse-client

# Configure ClickHouse default user password
mkdir -p /etc/clickhouse-server/users.d
cat > /etc/clickhouse-server/users.d/default-password.xml <<EOF
<yandex>
    <users>
        <default>
            <password>${clickhouse_password}</password>
            <networks>
                <ip>::/0</ip>
                <ip>0.0.0.0/0</ip>
            </networks>
            <!-- other settings (profile, quotas) will inherit defaults -->
        </default>
    </users>
</yandex>
EOF

# Configure ClickHouse to listen on all interfaces
mkdir -p /etc/clickhouse-server/config.d
cat > /etc/clickhouse-server/config.d/listen_host.xml <<EOF
<clickhouse>
    <listen_host>0.0.0.0</listen_host>
</clickhouse>
EOF

systemctl enable clickhouse-server
systemctl start clickhouse-server

# Wait until ClickHouse to be ready
until curl -sf http://localhost:8123/ping | grep -q "Ok."; do
    echo "Waiting for ClickHouse to be ready..."
    sleep 2
done
echo "ClickHouse is ready."


# Create health check script
cat > /usr/local/bin/clickhouse-health.sh << 'EOF'
#!/bin/bash
# Exit 0 only if /ping returns HTTP 200
curl -sf http://localhost:8123/ping
EOF

chmod +x /usr/local/bin/clickhouse-health.sh

# Create systemd service
cat > /etc/systemd/system/clickhouse-health.service << 'EOF'
[Unit]
Description=ClickHouse Health Check
After=network.target clickhouse-server.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/clickhouse-health.sh
User=root
EOF

# Create timer to run every 5 minutes
cat > /etc/systemd/system/clickhouse-health.timer << 'EOF'
[Unit]
Description=Run ClickHouse Health Check every 5 minutes
Requires=clickhouse-health.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=clickhouse-health.service

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
systemctl daemon-reload
systemctl enable --now clickhouse-health.timer
