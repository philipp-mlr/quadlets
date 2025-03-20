#!/usr/bin/env bash

# --- Rootless Configuration ---
echo "🚀 Updating systemd rootless configuration 🚀"

echo "🧹 Cleaning up old rootless configuration..."
rm -rf ~/.config/containers/systemd/rootless || true # '|| true' ignores errors if the folder doesn't exist

echo "✨ Copying new rootless configuration..."
cp -r ./rootless ~/.config/containers/systemd/rootless

if [ $? -eq 0 ]; then
  echo "✅ Rootless configuration copied successfully!"
else
  echo "❌ Failed to copy rootless configuration!"
fi

echo "🔄 Reloading user systemd..."
systemctl --user daemon-reload

if [ $? -eq 0 ]; then
  echo "✅ User systemd reloaded successfully!"
else
  echo "❌ Failed to reload user systemd!"
fi

echo "🎉 Rootless configuration updated! 🎉"

# --- Rootful Configuration ---
echo "👑 Updating systemd rootful configuration 👑"

echo "🧹 Cleaning up old rootful configuration..."
sudo rm -rf /etc/containers/systemd/rootful || true

echo "✨ Copying new rootful configuration..."
sudo cp -r ./rootful /etc/containers/systemd/rootful

if [ $? -eq 0 ]; then
  echo "✅ Rootful configuration copied successfully!"
else
  echo "❌ Failed to copy rootful configuration!"
fi

echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

if [ $? -eq 0 ]; then
  echo "✅ Systemd reloaded successfully!"
else
  echo "❌ Failed to reload systemd!"
fi

echo "👑 Rootful configuration updated! 👑"

echo "✨ All systemd configurations updated! ✨"