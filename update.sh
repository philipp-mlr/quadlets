#!/usr/bin/env bash

# 🚀 Function to start services in a given directory
start_services() {
  local service_dir="$1" # Get the directory from the function's input

  find "$service_dir" -name "*.container" -print0 | while IFS= read -r -d $'\0' service_file; do
    service_name=$(basename "$service_file" .container)
    
    if [ "$service_dir" == "/etc/containers/systemd/rootful" ]; then
      status=$(sudo systemctl is-active "$service_name")
    else
      status=$(systemctl --user is-active "$service_name")
    fi

    if [ "$status" != "active" ]; then
      echo -e "\n  ▶️ Starting service: $service_name"
      
      if [ "$service_dir" == "/etc/containers/systemd/rootful" ]; then
        sudo systemctl start "$service_name"
      else
        systemctl --user start "$service_name"
      fi

      if [ $? -eq 0 ]; then
        echo -e "  ✅ Service $service_name started successfully.\n"
      else
        echo -e "  ❌ Failed to start service $service_name.\n"
      fi
    fi
  done
}

# 🛠️ Function to update rootless configuration
update_rootless() {
  echo -e "\n🔄 Updating systemd rootless configuration..."

  echo -e "\n  🗑️ Removing old rootless configuration..."
  rm -rf ~/.config/containers/systemd/rootless || true

  echo -e "\n  📂 Copying new rootless configuration..."
  cp -r ./rootless/. ~/.config/containers/systemd/rootless/

  if [ $? -eq 0 ]; then
    echo -e "  ✅ Rootless configuration copied successfully.\n"
  else
    echo -e "  ❌ Failed to copy rootless configuration!\n"
  fi

  # Replace environment variables in the rootless container files
  find ~/.config/containers/systemd/rootless -name "*.env" -exec sh -c '
    env $(cat {}) envsubst < ${1%.env}.container > ${1%.env}.container.new && mv ${1%.env}.container.new ${1%.env}.container
  ' sh {} \;

  echo -e "\n  🔄 Reloading user systemd..."
  systemctl --user daemon-reload

  if [ $? -eq 0 ]; then
    echo -e "  ✅ User systemd reloaded successfully.\n"
  else
    echo -e "  ❌ Failed to reload user systemd!\n"
  fi

  echo -e "✅ Rootless configuration updated.\n"

  # Start services in the rootless directory
  start_services ~/.config/containers/systemd/rootless
}

# 🔧 Function to update rootful configuration
update_rootful() {
  echo -e "\n🔄 Updating systemd rootful configuration..."

  echo -e "\n  🗑️ Removing old rootful configuration..."
  sudo rm -rf /etc/containers/systemd/rootful || true

  echo -e "\n  📂 Creating new rootful configuration directory..."
  sudo mkdir -p /etc/containers/systemd/rootful

  echo -e "\n  📂 Copying new rootful configuration..."
  sudo cp -r ./rootful/. /etc/containers/systemd/rootful/

  if [ $? -eq 0 ]; then
    echo -e "  ✅ Rootful configuration copied successfully.\n"
  else
    echo -e "  ❌ Failed to copy rootful configuration!\n"
  fi

  # Replace environment variables in the rootful container files
  sudo find /etc/containers/systemd/rootful -name "*.env" -exec sh -c '
    env $(cat {}) envsubst < ${1%.env}.container > ${1%.env}.container.new && mv ${1%.env}.container.new ${1%.env}.container
  ' sh {} \;

  echo -e "\n  🔄 Reloading systemd..."
  sudo systemctl daemon-reload

  if [ $? -eq 0 ]; then
    echo -e "  ✅ Systemd reloaded successfully.\n"
  else
    echo -e "  ❌ Failed to reload systemd!\n"
  fi

  echo -e "✅ Rootful configuration updated.\n"

  # Start services in the rootful directory
  start_services /etc/containers/systemd/rootful
}

# 🚀 Main script execution
update_rootless

update_rootful

echo -e "\n🎉 All systemd configurations updated.\n"
