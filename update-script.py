#!/usr/bin/env python3

import argparse
import os
import sys
import logging
import shutil
from pathlib import Path

# --- Configuration ---
GLOBAL_ENV_PATH = Path("./.env")
ROOTFUL_SRC = Path("./rootful")
ROOTLESS_SRC = Path("./rootless")
ROOTFUL_TARGET = Path("/etc/containers/systemd/rootful")
ROOTLESS_TARGET = Path.home() / ".config/containers/systemd/rootless"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Manage podman systemd containers (rootful/rootless)"
    )
    parser.add_argument(
        "target", choices=["all", "rootful", "rootless"], help="Target containers"
    )
    parser.add_argument("--update", action="store_true", help="Update containers")
    parser.add_argument("--start", action="store_true", help="Start containers")
    parser.add_argument("--stop", action="store_true", help="Stop containers")
    parser.add_argument("--stats", action="store_true", help="Show stats")
    parser.add_argument(
        "--dry-run", action="store_true", help="Show actions without making changes"
    )
    parser.add_argument(
        "--service", type=str, help="Specify a single service to perform the action on"
    )
    return parser.parse_args()


def read_env(env_path):
    """Read KEY=VALUE pairs from an env file."""
    env = {}
    if env_path.exists():
        with env_path.open() as f:
            for line in f:
                if "=" in line and not line.strip().startswith("#"):
                    key, value = line.strip().split("=", 1)
                    env[key] = value
    return env


def replace_env_in_file(file_path, env):
    """Replace environment variables in a .container file."""
    try:
        with open(file_path, "r") as f:
            content = f.read()
        for key, value in env.items():
            content = content.replace(f"${{{key}}}", value)
            content = content.replace(f"${key}", value)
        with open(file_path, "w") as f:
            f.write(content)
    except (OSError, IOError) as e:
        logging.error(f"Error processing {file_path}: {e}")


def filter_service_items(items, service_filter=None):
    """Yield only items matching the service filter."""
    for item in items:
        if service_filter and item.name != service_filter:
            continue
        yield item


def copy_service_files(src_dir, tgt_dir, dry_run=False, service_filter=None):
    """Copy only .container and .env files from src_dir to tgt_dir."""
    if not tgt_dir.exists():
        if dry_run:
            logging.info(f"Would create directory: {tgt_dir}")
        else:
            tgt_dir.mkdir(parents=True, exist_ok=True)
    for item in filter_service_items(src_dir.iterdir(), service_filter):
        dest = tgt_dir / item.name
        if item.is_dir():
            if dry_run:
                logging.info(f"Would create directory: {dest}")
            else:
                dest.mkdir(parents=True, exist_ok=True)
            for subitem in item.iterdir():
                if subitem.suffix in [".container", ".env"]:
                    subdest = dest / subitem.name
                    if dry_run:
                        logging.info(f"Would copy file: {subitem} -> {subdest}")
                    else:
                        shutil.copy2(subitem, subdest)
        else:
            if item.suffix in [".container", ".env"]:
                if dry_run:
                    logging.info(f"Would copy file: {item} -> {dest}")
                else:
                    shutil.copy2(item, dest)


def clear_target_dir(tgt_dir, dry_run=False, service_filter=None):
    """Clear target directory before copying."""
    if tgt_dir.exists():
        logging.info(f"Clearing {tgt_dir} ...")
        for item in filter_service_items(tgt_dir.iterdir(), service_filter):
            try:
                if item.is_file() or item.is_symlink():
                    if dry_run:
                        logging.info(f"Would delete file: {item}")
                    else:
                        item.unlink()
                elif item.is_dir():
                    if dry_run:
                        logging.info(f"Would delete directory: {item}")
                    else:
                        shutil.rmtree(item)
            except Exception as e:
                logging.error(f"Error deleting {item}: {e}")


def update_services(src_dir, tgt_dir, dry_run=False, service_filter=None):
    """Update services: clear, copy, replace env, reload systemd."""
    try:
        clear_target_dir(tgt_dir, dry_run, service_filter)
        logging.info(f"Copying from {src_dir} to {tgt_dir} ...")
        copy_service_files(src_dir, tgt_dir, dry_run, service_filter)
    except Exception as e:
        logging.error(f"Failed to update {tgt_dir}: {e}")
        sys.exit(1)
    global_env = read_env(GLOBAL_ENV_PATH)
    for service_folder in filter_service_items(tgt_dir.iterdir(), service_filter):
        if service_folder.is_dir():
            service_env = global_env.copy()
            service_env_path = service_folder / f"{service_folder.name}.env"
            if service_env_path.exists():
                service_env.update(read_env(service_env_path))
            for file in service_folder.glob("*.container"):
                try:
                    if dry_run:
                        logging.info(f"Would replace env in: {file}")
                    else:
                        replace_env_in_file(file, service_env)
                except Exception as e:
                    logging.error(f"Error replacing env in {file}: {e}")


def reload_systemd(rootful, dry_run):
    if rootful:
        if dry_run:
            logging.info("Would reload systemd daemon (rootful)")
        else:
            logging.info("Reloading systemd daemon (rootful)...")
            os.system("sudo systemctl daemon-reload")
    else:
        if dry_run:
            logging.info("Would reload systemd daemon (rootless)")
        else:
            logging.info("Reloading systemd daemon (rootless)...")
            os.system("systemctl --user daemon-reload")


def update_containers(target, dry_run=False, service_filter=None):
    if target in ["all", "rootful"]:
        update_services(ROOTFUL_SRC, ROOTFUL_TARGET, dry_run, service_filter)
        reload_systemd(True, dry_run)
    if target in ["all", "rootless"]:
        update_services(ROOTLESS_SRC, ROOTLESS_TARGET, dry_run, service_filter)
        reload_systemd(False, dry_run)


def start_services(tgt_dir, rootful, dry_run=False, service_filter=None):
    for service_folder in filter_service_items(tgt_dir.iterdir(), service_filter):
        if service_folder.is_dir():
            service_name = service_folder.name
            service_unit = f"{service_name}.service"
            if dry_run:
                logging.info(
                    f"Would start {'rootful' if rootful else 'rootless'} service: {service_unit}"
                )
            else:
                logging.info(
                    f"Starting {'rootful' if rootful else 'rootless'} service: {service_unit}"
                )
                cmd = (
                    f"sudo systemctl start {service_unit}"
                    if rootful
                    else f"systemctl --user start {service_unit}"
                )
                os.system(cmd)


def start_containers(target, dry_run=False, service_filter=None):
    if target in ["all", "rootful"]:
        start_services(ROOTFUL_TARGET, True, dry_run, service_filter)
    if target in ["all", "rootless"]:
        start_services(ROOTLESS_TARGET, False, dry_run, service_filter)


def stop_services(tgt_dir, rootful, dry_run=False, service_filter=None):
    for service_folder in filter_service_items(tgt_dir.iterdir(), service_filter):
        if service_folder.is_dir():
            service_name = service_folder.name
            service_unit = f"{service_name}.service"
            if dry_run:
                logging.info(
                    f"Would stop {'rootful' if rootful else 'rootless'} service: {service_unit}"
                )
            else:
                logging.info(
                    f"Stopping {'rootful' if rootful else 'rootless'} service: {service_unit}"
                )
                cmd = (
                    f"sudo systemctl stop {service_unit}"
                    if rootful
                    else f"systemctl --user stop {service_unit}"
                )
                os.system(cmd)


def stop_containers(target, dry_run=False, service_filter=None):
    if target in ["all", "rootful"]:
        stop_services(ROOTFUL_TARGET, True, dry_run, service_filter)
    if target in ["all", "rootless"]:
        stop_services(ROOTLESS_TARGET, False, dry_run, service_filter)


def show_stats():
    rootful_count = 0
    rootful_containers = 0
    if ROOTFUL_TARGET.exists():
        for service_folder in ROOTFUL_TARGET.iterdir():
            if service_folder.is_dir():
                rootful_count += 1
                rootful_containers += len(list(service_folder.glob("*.container")))

    rootless_count = 0
    rootless_containers = 0
    if ROOTLESS_TARGET.exists():
        for service_folder in ROOTLESS_TARGET.iterdir():
            if service_folder.is_dir():
                rootless_count += 1
                rootless_containers += len(list(service_folder.glob("*.container")))

    logging.info("Service Stats:")
    logging.info(
        f"  Rootful:   {rootful_count} services, {rootful_containers} .container files"
    )
    logging.info(
        f"  Rootless:  {rootless_count} services, {rootless_containers} .container files"
    )
    logging.info(
        f"  Total:     {rootful_count + rootless_count} services, {rootful_containers + rootless_containers} .container files"
    )


def main():
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    service_filter = getattr(args, "service", None)
    dry_run = args.dry_run

    # Special logic for 'all' target
    if args.target == "all" and (args.update or args.start or args.stop):
        if os.geteuid() == 0:
            logging.warning(
                "Running as root: only performing rootful actions. Rootless actions are skipped."
            )
            if args.update:
                update_containers("rootful", dry_run, service_filter)
            if args.start:
                start_containers("rootful", dry_run, service_filter)
            if args.stop:
                stop_containers("rootful", dry_run, service_filter)
        else:
            logging.warning(
                "Running as non-root: only performing rootless actions. Rootful actions are skipped."
            )
            if args.update:
                update_containers("rootless", dry_run, service_filter)
            if args.start:
                start_containers("rootless", dry_run, service_filter)
            if args.stop:
                stop_containers("rootless", dry_run, service_filter)
        if args.stats:
            show_stats()
        return

    # Check for root privileges if rootful actions are requested
    needs_root = args.target == "rootful" and (args.update or args.start or args.stop)
    if needs_root and os.geteuid() != 0 and not dry_run:
        logging.error("Rootful actions require root privileges. Please run with sudo.")
        sys.exit(1)

    if args.update:
        update_containers(args.target, dry_run, service_filter)
    if args.start:
        start_containers(args.target, dry_run, service_filter)
    if args.stop:
        stop_containers(args.target, dry_run, service_filter)
    if args.stats:
        show_stats()


if __name__ == "__main__":
    main()
