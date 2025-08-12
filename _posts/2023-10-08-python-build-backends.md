---
layout: post
title: "Modern Python Build : Frontend, Backend, and Interfaces Explained"
date: 2023-10-08
desc: "Understand Python's modern build system architecture including pip (frontend), setuptools or poetry (backend), and pyproject.toml. Learn how they work together to build and install packages in a clean, standardized, and isolated way."
tags: [python, pip, pyproject.toml, packaging, build-system, tutorial]
---

- **[Read about pip and pyproject.toml]({{ site.posts | where: "slug", "pip-and-pyproject-toml" | first.url | relative_url }})**
- **[Detailed information on python build systems]({{ site.posts | where: "slug", "python-build-systems" | first.url | relative_url }})**

1. What is a build backend  
2. What is a build frontend  
3. How frontend and backend communicate  
4. Interface exposed by the backend  
5. Where do you define the backend  
6. What pip does with this information  
7. Build frontend tool – python -m build  
8. [Editable installs]({{ site.posts | where: "slug", "pip-and-editable-install" | first.url | relative_url }}) (PEP 660)  
9. How to choose a backend  
10. Final thoughts

###  What Is a Build Backend?

A **build backend** is the tool that actually **builds your Python package** — turning your source code into a wheel (`.whl`) or source distribution (`.tar.gz`).

####  Examples of Build Backends

| Backend     | Description                                     |
|-------------|-------------------------------------------------|
| **setuptools** | Most common, flexible traditional backend        |
| **flit**        | Simpler, minimal-config packaging backend       |
| **poetry**      | Full project management (build + dependencies)  |
| **hatchling**   | Modern backend focused on speed/flexibility     |

---

### What Is a Build Frontend?

A **build frontend** is the tool that **calls the backend** to perform the actual **build or install** process.

#### Popular Build Frontends

| Frontend     | Description                                |
|--------------|--------------------------------------------|
| **pip**      | The default Python package installer       |
| **build**    | CLI tool to build wheels/sdists            |
| **installer**| Used internally by `pip` to install wheels |


## How Frontend and Backend Communicate

This communication is defined by **[PEP 517](https://peps.python.org/pep-0517/)**.

---

###  Interface Exposed by the Backend (in Python)

All build backends **must** expose the following standard hooks:

```python
# Required build backend hooks
def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    pass

def build_sdist(sdist_directory, config_settings=None):
    pass
# optional build backend hooks
def get_requires_for_build_wheel(config_settings=None):
    pass

def prepare_metadata_for_build_wheel(metadata_directory, config_settings=None):
    pass
```
For Editable Installs (Optional, PEP 660)
Backends may implement this hook to support [editable installs]:

```python

def build_editable(wheel_directory, config_settings=None, metadata_directory=None):
    pass
```

### Where Do You Define the Backend?

You define the build backend in your `pyproject.toml` file under the `[build-system]` section:

```toml
[build-system]
requires = ["setuptools>=64", "wheel"]
build-backend = "setuptools.build_meta"
```
**Build-system Keys Explained**

`requires`  
Build dependencies that `pip` installs into an isolated build environment **before** building your project.

`build-backend`  
The Python import path of the build backend to use for building your package.

---

#### What `pip` Does with This Information

- Creates a **temporary isolated build environment**.

- Installs the specified **build dependencies** (e.g., `setuptools` and `wheel`).

- Imports the backend module (e.g., `setuptools.build_meta`).

- Calls backend hooks like `build_wheel()` or `build_sdist()` to build your project.

### Build Frontend Tool – **`python -m build`**

To explicitly test building your project, you can run:

```bash
python -m build
```

This command uses the build backend specified in your pyproject.toml and generates the following distribution files:

- **dist/projectname-version.whl — 📦 Wheel (binary distribution)**

- **dist/projectname-version.tar.gz — 📦 Source distribution (sdist)**


### [Editable Installs (PEP 660)]({{ site.posts | where: "slug", "pip-and-editable-install" | first.url | relative_url }})

Modern editable installs now use build backends.

```bash
pip install -e .
```
If your backend supports editable installs (e.g., setuptools>=64), it must expose the following hook `build_editable(...)`.

This allows `pip` to install a lightweight pointer (`__editable__project.pth`) instead of copying all files into the environment.

- 📝 Previously, editable installs involved **physically copying project files** or creating **complex symlinks**, which was not compliant with modern packaging standards (as defined in [PEP 660](https://peps.python.org/pep-0660/)).

- ⚠️ Note: Some IDEs and linters may still **not fully support** the new editable install mechanism. Compatibility is expected to improve as tooling catches up with the updated standards.


## How to Choose a Backend?

| You want to...                    | Recommended Backend  |
|----------------------------------|---------------------|
| Full control, traditional approach | `setuptools`         |
| Simplicity, minimal config         | `flit`               |
| All-in-one package management      | `poetry`             |
| Fast and modern builds             | `hatchling`          |

---

### Final Thoughts

- The build system separates concerns:  
  Frontend tools install/build, backend tools define how it’s done.

- `pyproject.toml` is the entrypoint for all modern builds.

- Backends must implement standard **PEP 517** hooks so `pip` (and others) can work with them.

- Stick with **PEP 517/518/621** for future-proof packaging.

- Avoid `setup.py` if you’re starting fresh — use `pyproject.toml` instead.