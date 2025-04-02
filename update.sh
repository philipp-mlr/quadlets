#!/usr/bin/env bash

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

update_config() {
  local config_dir="$1"
  local source_dir="./$(basename "$config_dir")"
  local sudo_prefix=""
  local systemctl_reload="systemctl --user daemon-reload"
  local is_rootful=false
  local env_vars=()

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

  echo -e "\n  🔃 Load global environment file"
  if [[ -f "./.env" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^([^#=]+)=(.*)$ ]]; then
        export "${BASH_REMATCH[1]}"="${BASH_REMATCH[2]}"
        env_vars+=("${BASH_REMATCH[1]}=${BASH_REMATCH[2]}")
      fi
    done < "./.env"
  fi

  echo -e "\n  🔄 Checking for empty environment variables..."
  ${sudo_prefix} find "$config_dir" -name "*.env" -exec bash -c '
    for env_file in "$@"; do
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([^#=]+)=[[:space:]]*$ ]]; then
          echo "❌ Error: Empty environment variable detected in $env_file: $line"
          exit 1
        fi
      done < "$env_file"
    done
  ' bash {} +

  if [[ $? -ne 0 ]]; then
    echo -e "  ❌ Exiting due to empty environment variables.\n"
    exit 1
  fi

  echo -e "\n  🔄 Replacing environment variables in container files"
  ${sudo_prefix} find "$config_dir" -name "*.container" -exec bash -c '
    for container_file in "$@"; do
      env_file="${container_file%.container}.env"
      if [[ -f "$env_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
          if [[ "$line" =~ ^([^#=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"

            # Escape Sonderzeichen für sicheres Exportieren
            value=$(printf "%q" "$value")

            export "$key"="$value"
          fi
        done < "$env_file"
      fi
      envsubst < "$container_file" > "$container_file.new" && mv "$container_file.new" "$container_file"
    done
  ' bash {} +

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

update_config ~/.config/containers/systemd/rootless
update_config /etc/containers/systemd/rootful

echo -e "\n🎉 All systemd configurations updated.\n"