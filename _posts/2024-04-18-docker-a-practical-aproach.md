---
layout: post  
title: "Docker: A Practical Approach"  
date: 2024-04-18
desc: "Learn to build, deploy, and manage containerized applications with real-world examples and integration best practices."  
tags: [docker, containers, devops, tutorial]
---

- [What Is Docker?](#what-is-docker)
- [Docker Ecosystem Overview](#docker-ecosystem-overview)
- [Understanding the Basic Components](#understanding-the-basic-components)
- [Docker Engine vs Docker Desktop](#docker-engine-vs-docker-desktop)
- [Install Docker](#install)
  - [Windows Installation](#windows)
  - [Linux Installation](#linux)
- [Structure of a Docker Project](#structure-of-a-docker-project)
- [Dockerfile: Heart of Docker](#dockerfile-heart-of-docker)
- [How Docker Works (Simplified)](#how-docker-works-simplified)
- [Common Questions on Dockerfile](#common-questions-on-dockerfile)
  - [What is a Dockerfile?](#what-is-a-dockerfile)
  - [Does the Dockerfile have to be named Dockerfile?](#does-the-dockerfile-have-to-be-named-dockerfile)
  - [Can a project have multiple Dockerfiles?](#can-a-project-have-multiple-dockerfiles)
  - [Does the docker build name have to be special?](#does-the-docker-build-name-have-to-be-special)
- [Why Docker Compose?](#why-docker-compose)
- [Key Questions on Docker Compose](#key-questions-on-docker-compose)
- [Full Flow: Compose Build and Run](#full-flow-compose-build-and-run)
- [Common Docker Commands](#common-docker-commands)

---

## What Is Docker?

Docker is a platform that allows you to build, ship, and run applications in containers. Containers are lightweight, portable units that bundle your code along with all its dependencies so it runs reliably anywhere — on your machine, a server, or in the cloud.

## Docker Ecosystem Overview

Here's how everything fits together:

```
Building and Running a Single Container
+------------------+
|    Dockerfile    | (Contains instructions)
+------------------+
          |
          | docker build
          v
+------------------+
|   Docker Image   | (Read-only template)
+------------------+
          |
          | docker run
          v
+------------------+
| Docker Engine    | (Core runtime that runs containers)
+------------------+
          |
          | runs
          v
+------------------+
| Docker Container | (Running instance of the image)
+------------------+
          |
          | Accesses Storage Volumes
          v
+------------------+
|  Data Volumes    | (Persisted data)
+------------------+

```

- **Dockerfile**: Instructions to build an image.
- **Docker Image**: Built from a Dockerfile; a read-only template.
- **Docker Container**: A running instance of an image.
- **Docker Compose**: A tool for defining and running multi-container Docker applications.
- **Docker Hub**: A cloud registry for Docker images (like GitHub, but for containers).

## Understanding the basic components


| Component       | What It Does                                         | Do You Need It?                  | 
|-----------------|-----------------------------------------------------|---------------------------------|
| Docker Engine   | Core service that runs containers. CLI-based.       | ✅ Yes                          | 
| Docker Desktop  | GUI + VM wrapper around Docker Engine. Required on Windows/macOS. | ✅ Yes (if on Windows/macOS)    | 
| Docker Compose  | Tool to manage multi-container apps using a YAML file. | ✅ Yes (if using multiple containers) | 

### Docker Engine vs Docker Desktop
- Docker Engine is the actual backend service that runs containers. It includes:
  - dockerd (daemon)
  - docker CLI
  - REST API
- Docker Desktop is a wrapper around Docker Engine for Windows/macOS. It includes:
  - A Linux VM (via WSL2 or Hyper-V)
  - GUI dashboard
  - Docker Engine inside the VM
  - Docker Compose pre-installed
  
>On Linux, you can install Docker Engine directly. On Windows/macOS, Docker Desktop is required because Docker needs a Linux kernel to run.
{: .promt-info}

## Install

### Windows:
- [Install Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/)  
This includes Docker Engine, Docker CLI, and Docker Compose.  
- Verify Installation  
```
docker --version
docker compose version
```

### Linux

Update your system  
```shell
sudo apt update && sudo apt upgrade -y
```

Install required packages  
```shell
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
```
#### 🐳 Installing Docker: **Using Official Docker CE**  or  **Linux Distro Repositories**

- [x] **Official Docker CE** (*Recomended*) install via **`sudo apt install docker-ce docker-ce-cli containerd.io -y`**
  >- Using `docker-ce`, `docker-ce-cli`, and `containerd.io` (Official Docker Repo):
  >- **Source:** Docker’s official repository.
  >- **Pros:** Latest stable version, faster updates, better feature support.
  >- **Setup:** Requires adding Docker’s GPG key and repo.
  >- **Best for:** Production use and when you need the latest Docker features.
  >
  >```shell
  >curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  >```
  >Add Docker repository  
  >```shell
  >sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
  >```
  >Install Docker Engine  
  >```shell
  >sudo apt update
  >sudo apt install docker-ce docker-ce-cli containerd.io -y
  >```
  >Install Docker compose as a plugin **(Recomended)**
  >```shell
  >sudo apt install docker-compose-plugin
  >```
  {: .prompt-tip}

- [x] **Linux Distro Repositories** install via **`sudo apt install docker.io docker-compose -y`**
  >- Using `docker.io` and `docker-compose` (Linux Distro Repositories)
  >- **Source:** Your Linux distribution’s official repositories.
  >- **Pros:** Simple installation, no need to add external repos or keys.
  >- **Cons:** Typically older versions, updated less frequently.
  >- **Best for:** Quick setups, testing, or when stability with the distro is preferred.
  >
  > ```shell
  >sudo apt install docker.io docker-compose -y
  >```
  {: .prompt-warning}

Start and enable Docker  
```shell
sudo systemctl start docker
sudo systemctl enable docker
```

Verify installation  
```shell
docker --version
```
## Structure of a Docker Project

**Example**
```
my-app/
├── Dockerfile
├── app.py
├── requirements.txt
└── docker-compose.yml  (optional)
```

### Dockerfile: Heart of Docker

A Dockerfile is a set of instructions for building your image.

**Example (Python App)**

```dockerfile
# Base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy files into container
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Run the app
CMD ["python", "app.py"]
```

## How Docker Works (Simplified)

You write a Dockerfile

Build it into an image using:

```shell
docker build -t myapp .
```

Run the image in a container:

```shell
docker run -p 8080:5000 myapp
```
>Note the cmd `docker run -p 8080:5000 myapp` runs the myapp image  and `-p 8080:5000 ` maps the host port 8080 to container port 5000. means the app is accesble via `localhost:8080`
{: .prompt-tip}

  | Docker Command            | Host Port | Container Port | Access via      |
  |--------------------------|-----------|----------------|-----------------|
  | docker run -p 5000:5000  | 5000      | 5000           | localhost:5000  |
  | docker run -p 8080:5000  | 8080      | 5000           | localhost:8080  |


## Common questions on Dockerfile

### What is a Dockerfile?

Yes — the Dockerfile is the main configuration file that tells Docker how to build an image for your application.

It's like a recipe:

![docker imagae](assets/images/snaps/docker.png){: .w-50 .right}
- **Base OS** – The minimal operating system layer your app runs on.
- **Dependencies** – All the libraries, packages, or runtimes your app needs.
- **Code** – Your actual application source files and logic.
- **What to run** – The startup command that launches your app inside the container.

### Does the Dockerfile have to be named Dockerfile?

By default, yes.

When you run:

```
docker build .
```

Docker looks for a file named exactly `Dockerfile` in the current directory.

But you can name it anything if you specify it manually:

```
docker build -f MyDockerfile -t myimage .
```

### Can a project have multiple Dockerfiles?

YES — it’s common!

Examples:

- `Dockerfile`          -> For production
- `Dockerfile.dev`      -> For development
- `Dockerfile.test`     -> For running tests

Each one might use different base images or dependencies. You just build them separately:

```
docker build -f Dockerfile.dev -t myapp-dev .
```
### Does the docker build name have to be special?
You can name a Docker image almost anything, but there are some rules and best practices:

** most used format:**
```
[registry/]repository[:tag]
```
**Examples:**

- `myapp` — simple local image  
- `username/myapp` — often used on Docker Hub  
- `myregistry.com/myteam/myapp:1.0.2` — custom registry with version tag

>**Naming Rules:**
>- Lowercase letters only (`myapp`, not `MyApp`)
>- Digits and dashes (`-`) are allowed
>- Avoid spaces
>- Tags (like `:v1`, `:latest`) are optional but useful
>- **Invalid:**
  - `MyApp` ← uppercase not allowed
  - `myapp@v1` ← `@` not allowed

>**Best Practices:**
- Use tags for versions:  
  `myapp:1.0`, `myapp:latest`, `myapp:dev`
{: .prompt-info}


## Why Docker Compose?

Docker Compose is essential when:
- You want to run multiple containers (e.g., web + database)  
- You want to define services in a single YAML file  
- You want to manage containers as a group (up, down, restart)  

>In a `docker-compose.yml` file, you can define multiple services (containers) and can 
- Directly build from a Dockerfile
  - instruct Docker Compose to build an image from a `Dockerfile` using the `build:` directive.
  - `build: .` tells Docker Compose to look for a `Dockerfile` in the current directory
- Use a Prebuilt Image
  - You can also use an image that already exists on Docker Hub or another registry using the `image:` directive.
{: .prompt-info}

**Example `docker-compose.yml`**

```yaml
# example showing both the ways (Can Use Both in the Same Compose File)
version: '3.8'
services:
  web:
    build: .
    ports:
      - "5000:5000"
  db:
    image: postgres:15  # Could be local or from Docker Hub
    environment:
      POSTGRES_PASSWORD: mysecret
```

>note the `build: ` directive supports custome path and names a well as mentioned below 
```yml
version: '3.8'
services:
  web:
    build:
      context: .   # specify the folder or path in which the docker will search for the image and other files
      dockerfile: Dockerfile.dev  # Optional — default is 'Dockerfile'
    ports:
      - "5000:5000"
```
{: .prompt-info}


**Run it with:**

```shell
docker-compose up    #  if not installed as plugin
docker-compose down
# or 
docker compose up    #  if installed as plugin
docker compose down

```
> - Use **`docker compose`** if installed as a plugin (recomened and new way) else use **`docker-compose`** 

## Key questions on docker compose

### 1. What is `context:` in Docker Compose?

`context` specifies the folder sent to the Docker engine during the build. It tells Docker where to find the `Dockerfile` and all source files used in the build process.

Example:

```yaml
build:
  context: ./frontend
  dockerfile: Dockerfile.dev
```

- Docker uses the `./frontend` folder as context.  
- It looks for `Dockerfile.dev` inside this folder.  
- All files in `./frontend` are available during the build (e.g., for `COPY . .`).

**Note:** Paths in the `Dockerfile` are relative to the **context**, not the `Dockerfile` location.

---

## 2. Is `postgres:15` local or remote? How does Docker know?

Docker first checks if the image `postgres:15` exists locally. If not, it tries to pull it from a remote registry like Docker Hub.

- If you build locally with `docker build -t postgres:15 .`, Docker Compose uses this local image.  
- If not found locally, Docker attempts to pull it; failure occurs if the image does not exist remotely.

---

## 3. How does Docker know to use `Dockerfile.dev`?

You explicitly specify the Dockerfile in Compose:

```yaml
build:
  context: ./frontend
  dockerfile: Dockerfile.dev
```

Without `dockerfile:`, Docker defaults to `Dockerfile`. Custom filenames require explicit specification.

---

## Full Flow: Compose Build and Run

Running:

```shell
docker-compose up --build
```


- Compose reads `docker-compose.yml`.  
- For the `frontend` service:  
  - Uses `./frontend` as context, builds using `Dockerfile.dev`.  
- For the `backend` service:  
  - Looks locally for `postgres:15`.  
  - If absent, pulls from Docker Hub or fails.

```markdown
+--------------------+
| docker-compose.yml | (Defines multi-container applications)
+--------------------+
          |
          | docker-compose up
          v
+------------------------+
| Multiple Docker        | (Multiple containers running together)
| Containers             |
+------------------------+
          |
          | Managed by
          v
+------------------+
| Docker Engine    | (Core runtime that manages containers)
+------------------+
```

## Common Docker Commands

### Images
```
docker build -t myimage .          # Build image from Dockerfile
docker images                      # List all images
docker rmi <image_id>              # Remove an image
```

### Containers
```
docker run -d -p 80:80 myimage     # Run in detached mode
docker ps                          # List running containers
docker ps -a                       # List all containers (even stopped)
docker stop <container_id>         # Stop a container
docker rm <container_id>           # Remove a container
```

### Volumes & Bind Mounts (Persisting Data)
```
docker run -v myvolume:/data myimage
docker volume create myvolume
```
