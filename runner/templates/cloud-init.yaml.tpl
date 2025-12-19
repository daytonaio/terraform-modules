#cloud-config
# Copyright (c) 2025 Daytona
# Licensed under the MIT License - see LICENSE file for details

package_update: true
package_upgrade: true

packages:
  - curl
  - ca-certificates

write_files:
  - path: /etc/systemd/system/daytona-runner.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Daytona Runner Service
      Documentation=https://github.com/daytonaio/daytona
      After=network.target
      Wants=network-online.target

      [Service]
      Type=simple
      User=root
      Group=root
      WorkingDirectory=/opt/daytona

      # Binary location
      ExecStart=/opt/daytona/runner

      # Environment values
      Environment=DAYTONA_API_URL=${daytona_api_url}
      Environment=DAYTONA_RUNNER_TOKEN=${daytona_runner_token}
      Environment=DAYTONA_RUNNER_POLL_TIMEOUT=${poll_timeout}
      Environment=DAYTONA_RUNNER_POLL_LIMIT=${poll_limit}

      # Restart policy
      Restart=on-failure
      RestartSec=5s

      # Security hardening
      NoNewPrivileges=true
      PrivateTmp=true
      ProtectSystem=strict
      ProtectHome=true
      ReadWritePaths=/var/lib/daytona/runner /var/log/daytona /tmp

      # Resource limits
      LimitNOFILE=65536
      LimitNPROC=4096

      # Logging
      StandardOutput=journal
      StandardError=journal
      SyslogIdentifier=daytona-runner

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Create runner directory
  - mkdir -p /opt/daytona

  # Download runner binary from API
  - curl -L -f -o /opt/daytona/runner "${daytona_api_url}/runner-amd64"
  - chmod +x /opt/daytona/runner

  # Reload systemd and enable/start the service
  - systemctl daemon-reload
  - systemctl enable --now daytona-runner

  # Verify installation
  - systemctl status daytona-runner --no-pager

final_message: "Daytona Runner installation completed after $UPTIME seconds"
