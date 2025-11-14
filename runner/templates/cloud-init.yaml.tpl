#cloud-config
# Copyright (c) 2025 Daytona
# Licensed under the MIT License - see LICENSE file for details

package_update: true
package_upgrade: true

packages:
  - curl
  - ca-certificates

write_files:
  - path: /etc/daytona/runner.env
    permissions: '0600'
    content: |
      # Daytona Runner Configuration
      DAYTONA_API_URL=${daytona_api_url}
      DAYTONA_RUNNER_TOKEN=${daytona_runner_token}

      # Job Polling Configuration
      POLL_TIMEOUT=${poll_timeout}
      POLL_LIMIT=${poll_limit}
runcmd:
  # Download and install Daytona runner
  - curl -L -o /tmp/daytona-runner.deb "https://download.daytona.io/daytona-ai/runner/daytona-runner_${runner_version}_amd64.deb"
  - dpkg -i /tmp/daytona-runner.deb || true

  # Enable and start the service
  - systemctl enable --now daytona-runner

  # Clean up
  - rm -f /tmp/daytona-runner.deb

  # Verify installation
  - systemctl status daytona-runner --no-pager

final_message: "Daytona Runner installation completed after $UPTIME seconds"
