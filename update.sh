#!/usr/bin/env bash

# 🚀 Function to start services in a given directory
start_services() {
  local service_dir="$1"

  find "$service_dir" -name "*.container" -print0 | while IFS= read -r -d $'\0' service_file; do
    local service_name=$(basename "$service_file" .container)
    local status
    
    if [[ "$service_dir" == "/etc/containers/systemd/rootful" ]]; then
      status=$(sudo systemctl is-active "$service_name")
    else
      status=$(systemctl --user is-active "$service_name")
    fi

    if [[ "$status" != "active" ]]; then
      echo -e "\n  ▶️ Starting service: $service_name"
      
      if [[ "$service_dir" == "/etc/containers/systemd/rootful" ]]; then
        sudo systemctl start "$service_name"
      else
        systemctl --user start "$service_name"
      fi

      if [[ $? -eq 0 ]]; then
        echo -e "  ✅ Service $service_name started successfully.\n"
      else
        echo -e "  ❌ Failed to start service $service_name.\n"
      fi
    fi
  done
}

# 🛠️ Function to update systemd configuration
update_config() {
  local config_dir="$1"
  local source_dir="./$(basename "$config_dir")"
  local sudo_prefix=""
  local systemctl_reload="systemctl --user daemon-reload"
  local is_rootful=false

  if [[ "$config_dir" == "/etc/containers/systemd/rootful" ]]; then
    sudo_prefix="sudo"
    systemctl_reload="sudo systemctl daemon-reload"
    is_rootful=true
  fi

  echo -e "\n🔄 Updating systemd $(basename "$config_dir") configuration..."

  echo -e "\n  🗑️ Removing old configuration..."
  ${sudo_prefix} rm -rf "$config_dir" || true

  if [[ "$is_rootful" == true ]]; then
      echo -e "\n  📂 Creating new rootful configuration directory..."
      ${sudo_prefix} mkdir -p "$config_dir"
  fi

  echo -e "\n  📂 Copying new configuration..."
  ${sudo_prefix} cp -r "$source_dir/." "$config_dir/"

  if [[ $? -eq 0 ]]; then
    echo -e "  ✅ Configuration copied successfully.\n"
  else
    echo -e "  ❌ Failed to copy configuration!\n"
  fi

  # Check for empty environment variables in the container files
  ${sudo_prefix} find "$config_dir" -name "*.env" -exec sh -c '
    for env_file in "$@"; do
      while IFS= read -r line; do
        if [[ "$line" =~ ^[^#]*=([[:space:]]*)$ ]]; then
          echo "❌ Error: Empty environment variable detected in $env_file: $line"
          exit 1
        fi
      done < "$env_file"
    done
  ' sh {} +

  if [[ $? -ne 0 ]]; then
    echo -e "  ❌ Exiting due to empty environment variables.\n"
    exit 1
  fi

  # Replace environment variables in the container files
  ${sudo_prefix} find "$config_dir" -name "*.env" -exec sh -c '
    for env_file in "$@"; do
      set -o allexport
      source "$env_file"
      set +o allexport
      envsubst < ${env_file%.env}.container > ${env_file%.env}.container.new && mv ${env_file%.env}.container.new ${env_file%.env}.container
    done
  ' sh {} +

  echo -e "\n  🔄 Reloading systemd..."
  $systemctl_reload

  if [[ $? -eq 0 ]]; then
    echo -e "  ✅ Systemd reloaded successfully.\n"
  else
    echo -e "  ❌ Failed to reload systemd!\n"
  fi

  echo -e "✅ $(basename "$config_dir") configuration updated.\n"

  # Start services in the directory
  start_services "$config_dir"
}

# 🚀 Main script execution
update_config ~/.config/containers/systemd/rootless
update_config /etc/containers/systemd/rootful

echo -e "\n🎉 All systemd configurations updated.\n"