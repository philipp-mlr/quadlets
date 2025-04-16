#!/usr/bin/env bash

systemctl --user daemon-reload && journalctl -n 100 | grep quadlet-generator