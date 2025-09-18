#!/usr/bin/env bash

echo "Starting all Quadlet containers (systemd --user units)..."

# Directory where Quadlet definitions are stored
quadlet_dir="${HOME}/.config/containers/systemd"

# Find all .container files
container_files=$(find "$quadlet_dir" -name '*.container')

if [[ -z "$container_files" ]]; then
  echo "No Quadlet container files found in $quadlet_dir"
  exit 0
fi

for file in $container_files; do
  # Extract the service name from the filename (e.g., tika.container → tika.service)
  name=$(basename "$file" .container)
  service="${name}.service"

  echo "Starting $service..."
  systemctl --user start "$service"
done

echo "Done."

