#!/usr/bin/env bash

echo "Updating systemd rootless configuration"

echo "Removing old configuration"
rm -rdf ~/.config/containers/systemd/rootless

echo "Copying new configuration"
cp -fr ./rootless/ ~/.config/containers/systemd/

echo "Reloading systemd"
systemctl --user daemon-reload

echo "Done"