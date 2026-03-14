---
layout: post
title: "UV: Python Project & Environment Manager"
date: 2026-03-14
desc: "Discover UV, a lightweight Python tool that simplifies project and environment management."
tags: [python, uv, tutorial]
---

<details>
<summary><strong>📑 Table of Contents</strong></summary>

<div markdown="1">
1. [Why use `UV`](#why-use-uv)
2. [Installation Methods](#installation-methods)
3. [Upgrading `uv`](#upgrading-uv)
4. [`uv` Behavior with `.venv`](#uv-behavior-with-venv)
5. [`uv` and `.venv`: Pip vs `uv` Behavior](#uv-and-venv-pip-vs-uv-behavior)
    - [Rule of Thumb](#rule-of-thumb)
6. [Key Commands](#key-commands)
7. [Important notes about `.venv` & `pyproject.toml`](#important-notes-about-venv--pyprojecttoml)
8. [Example Python interpreter behavior](#example-python-interpreter-behavior)
9. [Flow for creating a project with `uv`](#flow-for-creating-a-project-with-uv)
10. [Summary of `uv` behavior](#summary-of-uv-behavior)
</div>
</details>

---

`uv` is a modern CLI tool written in Rust, designed to manage Python projects, virtual environments, dependencies, and project scripts in a unified way. Even though it’s written in Rust, it interacts seamlessly with Python because it manages .venv environments, Python interpreters, and dependencies directly.
### Why use UV
- Provides automatic virtual environment management.
- Handles dependency installation (`uv add`) without manual activation of `.venv`.
- Supports running commands in the project environment (`uv run`).
- Manages Python versions (`uv python install <version>` / `uv python pin`).
- Acts as a unified tool for project scaffolding, dependency management, and running scripts.

### Installation Methods

| Method                                                                         | What it does                                         |
| ------------------------------------------------------------------------------ | --------------------------------------------------- |
| `curl -LsSf https://astral.sh/uv/install.sh | sh`                                                 | Installs UV globally via Rust binary             |
| `pip install uv`                                                               | Installs UV in the current Python environment       |
| `pipx install uv`                                                              | Installs UV globally in an isolated environment    |


### Upgrading `uv`

- if installed Using curl
    * Rerun the install script to replace the binary.

- Using pip/pipx

    ```bash
    # if installed via pip
    pip install --upgrade uv

    # if installed via pipx
    pipx upgrade uv
    ```

### `uv` Behavior with `.venv`

If a `.venv` folder exists in the same directory as `pyproject.toml`, `uv` will:

- Use that `.venv` for Python interpreter and dependencies.
- Run commands and install libraries in that environment automatically.

If `.venv` does not exist, `uv` will create it when you run:

```bash
uv venv
```

No explicit activation is needed for `uv add` or `uv run` commands, though activating `.venv` is best practice.

---

### `uv` and `.venv`: Pip vs `uv` Behavior

> **CAUTION**  
> If you use `uv venv` to create a `.venv`, do not use pip directly, even if you activate the environment with:  
> `source .venv/bin/activate`  
> Using pip may install packages into the system Python, not the `.venv`.
{: .prompt-info}

---

#### 1️⃣ `.venv` created by `uv venv`

```bash
uv venv
```

`uv` creates a virtual environment under `.venv` using Python.  

It sets up Python interpreter binaries and a standard venv folder structure, but it does **not** install or link a system pip automatically in the same way Python does.  

`uv` then expects you to use `uv` commands (`uv add <package>`) to install packages.  

✅ `uv add requests` → works inside `.venv`  
❌ `pip install requests` → might fail or install into system Python, because `uv`'s `.venv` is intended to be managed via `uv` and may not have pip properly bootstrapped for direct use.

> In short: uv created venv is “uv-controlled”, not a standard Python-managed venv for pip.
{: .prompt-tip}

If you want to use pip safely, create the environment via:  

```bash
python -m venv .venv
```

In a pip-created `.venv`, both `uv` and pip work seamlessly.

---

#### 2️⃣ `.venv` created by `python -m venv .venv`

```bash
source .venv/bin/activate
```

This is a standard Python virtual environment.  

It includes its own pip inside `.venv/bin/pip`.  

You can now freely do:

```bash
pip install requests
python -m pip install fastapi
```

`uv` can also use this `.venv`:

```bash
uv add some_package
uv run python script.py
```

Both `uv` and pip install into the same `.venv`, because pip exists in that environment.

---

##### Rule of Thumb

- **uv created venv** → use `uv` commands only  
- **pip-created venv** → use pip or `uv` commands  

Activating the environment with `source .venv/bin/activate` does **not** magically fix `uv venv` for pip if pip wasn’t installed.  

If you want pip in a `uv` venv, you would need to bootstrap pip manually:

```bash
uv venv
.venv/bin/python -m ensurepip --upgrade
pip install <package>
```

---

### Key Commands

| Command                    | Description                                                                 |
|----------------------------|-----------------------------------------------------------------------------|
| `uv init`                  | Initializes the entire project structure including `pyproject.toml`        |
| `uv venv`                  | Creates a `.venv` folder at the current directory level; optionally: `uv venv --python python3.13` to choose a Python version |
| `uv add <package>`         | Installs a dependency into `.venv`                                         |
| `uv run <command>`         | Runs a command inside the `.venv` environment                               |
| `uv python install <version>` | Installs a specific Python version                                       |
| `uv python pin <version>`  | Pins the project to use a specific Python version                           |
| `uv tool install <tool>`   | Installs CLI tools like `ruff` without polluting the environment            |

---

### Important notes about `.venv` & `pyproject.toml`

- `.venv` must exist at the same level as `pyproject.toml`.  
- Activating `.venv` ensures that `uv` uses the correct Python interpreter.  
- Running `uv add <package>` outside the directory containing `pyproject.toml` will not work.  

Example directory:

```md
/home/project/
├── .venv
└── pyproject.toml

# Inside project directory:

uv add requests   # Works fine
uv run python main.py

# Outside project directory:

cd ..
uv run python main.py   # Won’t work, as pyproject.toml is not found

# Activating `.venv`:

source .venv/bin/activate
uv run python --version   # Ensures correct Python from `.venv` is used
```

---

## Example Python interpreter behavior

```bash
# Inside project without activating
uv run which python --version
# /home/user/workspace/project/.venv/bin/python

# Outside project
uv run which python --version
# Returns system Python (uv can’t find pyproject.toml/.venv)

# After activating .venv
source .venv/bin/activate
uv run which python --version
# /home/user/workspace/project/.venv/bin/python
```

Takeaway: Activation ensures `uv` picks the correct Python version, but `uv` can work without activation if `.venv` exists in the same folder as `pyproject.toml`.

---

## Flow for creating a project with `uv`

1. Create a project:

```bash
uv init myproject
cd myproject
```

2. Create virtual environment:

```bash
uv venv --python python3.13
```

3. Add dependencies:

```bash
uv add requests fastapi
```

4. Run Python scripts inside the environment:

```bash
uv run python main.py
```

5. Upgrade `uv` if needed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # curl installer
pipx upgrade uv                                     # if pipx-installed
```

---

## Summary of `uv` behavior

- `.venv` must be in the same folder as `pyproject.toml`.  
- `uv` will automatically use `.venv` for running commands and installing dependencies.  
- No manual activation is strictly required, but recommended for safety.  
- Avoid using system pip directly — always use `uv add` inside the project.