#!/usr/bin/env bash

# Function to update rootless configuration
update_rootless() {
  echo "Updating systemd rootless configuration..."

  echo "  Removing old rootless configuration..."
  rm -rf ~/.config/containers/systemd/rootless || true

  echo "  Copying new rootless configuration..."
  cp -r ./rootless ~/.config/containers/systemd/rootless

  if [ $? -eq 0 ]; then
    echo "  Rootless configuration copied successfully."
  else
    echo "  Failed to copy rootless configuration!"
  fi

  echo "  Reloading user systemd..."
  systemctl --user daemon-reload

  if [ $? -eq 0 ]; then
    echo "  User systemd reloaded successfully."
  else
    echo "  Failed to reload user systemd!"
  fi

  echo "Rootless configuration updated."
}

# Function to update rootful configuration
update_rootful() {
  echo "Updating systemd rootful configuration..."

  echo "  Removing old rootful configuration..."
  sudo rm -rf /etc/containers/systemd/rootful || true

  echo "  Creating new rootful configuration directory..."
  sudo mkdir -p /etc/containers/systemd/rootful

  echo "  Copying new rootful configuration..."
  sudo cp -r ./rootful /etc/containers/systemd/rootful

  if [ $? -eq 0 ]; then
    echo "  Rootful configuration copied successfully."
  else
    echo "  Failed to copy rootful configuration!"
  fi

  echo "  Reloading systemd..."
  sudo systemctl daemon-reload

  if [ $? -eq 0 ]; then
    echo "  Systemd reloaded successfully."
  else
    echo "  Failed to reload systemd!"
  fi

  echo "Rootful configuration updated."

  # Function to start services that aren't running
  start_services() {
    find /etc/containers/systemd/rootful/rootful/ -name "*.container" -print0 | while IFS= read -r -d $'\0' service_file; do
      service_name=$(basename "$service_file" .container)
      status=$(sudo systemctl is-active "$service_name")

      if [ "$status" != "active" ]; then
        echo "  Starting service: $service_name"
        sudo systemctl start "$service_name"
        if [ $? -eq 0 ]; then
          echo "  Service $service_name started successfully."
        else
          echo "  Failed to start service $service_name."
        fi
      fi
    done
  }

  start_services # Call the function to start services
}

# Main script execution
update_rootless
update_rootful

echo "All systemd configurations updated."