# quadlets 
A cozy home for my Podman Quadlets.

I originally managed my containers like everyone else with docker. But I have decided to migrate my container stack to podman.
The docker version of this isn't getting any more updates but if you are interested you can check it out [here](https://github.com/philipp-mlr/docker-services).

## Overview 🗂️

This repository contains a collection of **Quadlet files** I use to define containers as **systemd services** on my homelab.  
Quadlets are a neat way to manage Podman containers — they let you configure everything declaratively using `.container` unit files.

## Getting Started 🚀

Wanna use these Quadlets? Here's how:

### 1. Clone the Repo 📥

```sh
git clone https://github.com/philipp-mlr/quadlets
cd quadlets
```

### 2. Set Up Environment Variables

There are two types of `.env` files:

#### 🔹 Global `.env` file

Located in the root directory ([.env.example](https://github.com/philipp-mlr/quadlets/blob/main/.env.example)), this file defines environment variables used across multiple containers.  
I use this mostly to work around the fact that systemd labels don't support env vars — adjust it to your needs (e.g., domains and paths).

Copy and edit the example:

```sh
mv .env.example .env
nano .env
```

#### 🔹 Container-specific `.env` files

Each container can have its own environment file in its directory.  
These files define container-specific variables.

Example for Portainer:

```sh
cd ./rootless/portainer
mv portainer.env.example portainer.env
nano portainer.env
```

### 3. Update Systemd & Start Everything 🔁

Use the `update.sh` script in the root folder — it handles everything for you:

- Copies `rootless` files → `~/.config/containers/systemd/rootless`
- Copies `rootful` files → `/etc/containers/systemd/rootful` (🔒 root required)
- Substitutes all env vars in `.container` files using your global `.env`
- Reloads systemd
- Starts all services 💨

Run it like this:

```sh
chmod +x ./update.sh
./update.sh
```

## Contact 💬

Found a bug? Got a cool idea?  
Open an [issue](https://github.com/philipp-mlr/quadlets/issues) or reach out — happy to connect!
