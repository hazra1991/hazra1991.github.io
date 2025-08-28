---
layout: post  
title: "Langfuse Self-Hosting Startup Guide (Local Deployment)"
date: 2025-08-25
categories: ['Tutorial', 'Observability']
tags: ['langfuse', 'telemetry', 'LLM observability', 'setup']
slug: langfuse-intro-local-setup
---

Easily deploy Langfuse locally with Docker, configure users and projects, and connect via the SDK.

---

## 🚀 Step 1: Clone the Langfuse Repository

Start by cloning the Langfuse GitHub repository:

```bash
git clone https://github.com/langfuse/langfuse
cd langfuse
```

---

## ⚙️ Step 2: Create and Configure the .env File

Langfuse requires a `.env` file in the root directory for configuration.

**Copy the content of file `.env.prod.example` in the project to a `.env` file**

<p style="text-align: center; font-weight: bold;">🔸 OR 🔹</p>

📁 **Create a `.env` file: with the below** 

Add the following content (customized for your setup) to `.env`

```bash
# --- PostgreSQL Database Configuration ---
DATABASE_URL="postgresql://postgres:postgres@db:5432/postgres"

# --- Application URLs ---
NEXTAUTH_URL="http://localhost:3000"

# --- Secrets and Security ---
NEXTAUTH_SECRET="X2v42emRGCtcYobj3ZWwTJkLIOHkUuxl1bLcZkuEG20="
SALT="salt"
ENCRYPTION_KEY="0000000000000000000000000000000000000000000000000000000000000000"

# --- OpenTelemetry (Optional Observability) ---
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
OTEL_SERVICE_NAME="langfuse"

# --- Default Resource Provisioning (Automated Setup) ---
LANGFUSE_INIT_ORG_ID=org-id
LANGFUSE_INIT_ORG_NAME=org-name
LANGFUSE_INIT_PROJECT_ID=project-id
LANGFUSE_INIT_PROJECT_NAME=project-name
LANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-1234567890
LANGFUSE_INIT_PROJECT_SECRET_KEY=sk-1234567890
LANGFUSE_INIT_USER_EMAIL=user@example.com
LANGFUSE_INIT_USER_NAME=abhishek
LANGFUSE_INIT_USER_PASSWORD=password@1234
```

✅ This automates the setup of your default organization, project, and admin user.  

>You may also copy content from `.env.prod.example` as a reference and adjust as needed.
{: .prompt-info}

---

## 🐳 Step 3: Start Langfuse with Docker

Ensure Docker and Docker Compose are installed.

🧱 Run services using Docker Compose:

```bash
docker-compose up -d --build
```

> IT should run the `docker-compose.yml` file in the project
{: .prompt-info}

This starts the entire Langfuse stack, including the database.

---

## 🌐 Step 4: Access the Langfuse Dashboard

Once Docker is running:

🔗 Visit: [http://localhost:3000](http://localhost:3000)  

🔐 Login credentials:

- Email: `user@example.com`  
- Password: `password@1234`  

Set via `.env` using `LANGFUSE_INIT_USER_*` variables.

---

## 📦 Services Started by Docker Compose

The `docker-compose.yml` starts the following services:

| Service     | Description                     |
|-------------|---------------------------------|
| langfuse    | Main Langfuse application       |
| db          | PostgreSQL database             |
| clickhouse  | (Optional) Analytics storage    |
| otel        | OpenTelemetry collector (opt.)  |

👉 Make sure the `.env` matches the same values for db and services.

---

## 🧠 Step 5: Use Langfuse SDK (Optional)

Once running, you can connect your app to Langfuse via SDK.

🧪 Export SDK keys in your terminal session:

```bash
export LANGFUSE_PUBLIC_KEY=pk-1234567890
export LANGFUSE_SECRET_KEY=sk-1234567890
export LANGFUSE_HOST=http://localhost:3000
```

Replace values if you use different ones in your `.env`.

This allows the Langfuse SDK (in Python, Node, etc.) to authenticate and send traces to your local Langfuse instance.

---

## 🧩 Tips

To regenerate secrets, use:

```bash
openssl rand -base64 32    # For NEXTAUTH_SECRET
openssl rand -hex 32       # For ENCRYPTION_KEY
```

- You can customize services or add extras like Redis or S3 later.  
- All default resources (org, project, user) are automatically created via the `LANGFUSE_INIT_*` variables on first run.


## How to Verify All Components Are Running Properly

Your self-hosted Langfuse consists of several interconnected services:

- langfuse-web (frontend/API)  
- langfuse-worker (event ingestion/background processing)  
- PostgreSQL (primary transactional store)  
- ClickHouse (analytics/OLAP store)  
- Redis (queue & cache)  
- MinIO or S3 (object/event storage)  

---

**Steps to Check Service Health**

### A. Health & Readiness Endpoints

Langfuse provides built-in HTTP endpoints for basic health checks:

**Frontend (langfuse-web):**

```bash
curl http://localhost:3000/api/public/health
curl http://localhost:3000/api/public/ready
```

- `200 OK` → healthy and connected to DB.  
- `503` → unhealthy, e.g. DB not connected.  

Optionally add `?failIfDatabaseUnavailable=true` to include DB connectivity in the check.

---

**Worker (langfuse-worker):**

```bash
curl http://localhost:3030/api/health
```

- Returns **200 OK** if the worker can access its dependencies successfully.  

These are ideal for monitoring tools (e.g., Prometheus, uptime checks).  
**Note:** Cloud setup may use an extended flag like `failIfNoRecentEvents`, but this isn't default for self-hosted.

---

### B. Inspect Docker Container Status

Use Docker commands to ensure all services are up:

```bash
docker ps
docker-compose logs -f
```

Look for:
- Containers running without restarts  
- No crashes or repeated failures in logs  

---

### C. Confirm Each Component's Connectivity

**PostgreSQL:**  
Try connecting inside the container:

```bash
docker exec -it <postgres_container> psql -U <user> -d <db>
```

Check tables and schema.

---

**ClickHouse:**  
Similar approach; you can use `curl` to test TCP (9000) or HTTP (8123) endpoints.

---

**Redis:**  
Use a Redis client:

```bash
redis-cli ping
```

Or check keys.

---

**MinIO / S3:**  
- Access its console (usually at [http://localhost:9091](http://localhost:9091))  
- Verify bucket(s) exist and can be written to.
