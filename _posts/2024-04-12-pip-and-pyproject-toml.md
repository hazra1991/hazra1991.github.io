---
layout: post
title: "Inside pip and pyproject.toml"
date: 2024-04-12
desc: "Learn how pip and pyproject.toml work together in modern Python packaging. Understand installation flow, build systems, and best practices."
tags: [python, pip, pyproject.toml, packaging, build-system, tutorial]
---

## How `pip` Works, the Role of `pyproject.toml`.

- [Key Components of the Python Build System before we start](#key-components-of-the-python-build-system-before-we-start)
- [What Happens When You Run pip install?](#what-happens-when-you-run-pip-install)
- [What is `pyproject.toml` and Why Was It Introduced?](#what-is-pyprojecttoml-and-why-was-it-introduced)
- [Under the Hood: How pip Uses pyproject.toml (The flow we were waiting)](#under-the-hood-how-pip-uses-pyprojecttoml-the-flow-we-were-waiting)
- Final Word

---
#### Key Components of the Python Build System before we start

| Component        | Role                                                                 |
|------------------|----------------------------------------------------------------------|
| **pip**          | Installer that uses the build system to install packages (frontend)  |
| **build backend**| Tool that knows how to build the project (e.g. `setuptools`, `flit`, `poetry`) |
| **pyproject.toml** | Declares which build backend to use and its requirements           |
| **wheel**        | Built distribution format (binary) – like `.whl`, similar to `.deb` or `.rpm` |
| **sdist**        | Source distribution (e.g., `.tar.gz`) containing raw source code     |

>  **Note:** `pip` is *not* a build tool.  
> It **calls the build backend** (via `pyproject.toml`) to build your project into `wheel` or `sdist`.

---
#### In this article, we explore:

- How pip resolves packages and installs them  
- The purpose and structure of pyproject.toml  
- Legacy vs modern build systems  
- Under-the-hood details: [editable installs]({{ site.posts | where: "slug", "pip-and-editable-install" | first.url | relative_url }}), build dependencies, and backend systems  

Let’s demystify what really happens when you run `pip install <something>`.

### What Happens When You Run pip install?

When you execute:

```bash
pip install <input>
```
pip attempts to interpret the input and resolve it using a strict resolution order:

| Priority | Input Type         | Behavior                              |
|----------|--------------------|-------------------------------------|
| 1        | VCS or Direct URL  | Clone/download and install           |
| 2        | Local Directory    | Must contain `pyproject.toml` or `setup.py` |
| 3        | Local Archive      | Install from `.whl`, `.tar.gz`, `.zip`        |
| 4        | Package Name (PyPI)| Fetch from PyPI (or configured index)          |

Let’s break this down

1. **VCS or Direct URL**  
Example:
```bash
pip install git+https://github.com/user/repo.git
```
- `pip` recognizes `git+` as a VCS prefix.  
- Clones the repo and installs the package using its build system.  
- ✅ Verified: pip supports VCS schemes like `git+`, `hg+`, `svn+`, etc.

2. **Local Directory**  
Example:
```bash
pip install ./myproject
```
If the directory contains a valid project (i.e., has a `pyproject.toml` or `setup.py`), pip treats it as a local install.
For editable installs (`-e`), pip requires a local path or VCS URL .
it has also been seen that pip will work if there is not local path provided but he package is present on the current directory like `pip install -e <pkgname>` .  Here if we provide a name that is not present pip will complain. 
- Note: pip does not guess — it only uses the local directory if explicitly passed as a valid path.

3. **Local Archive**  
Example:
```bash
pip install dist_or_py_pth/mypkg-0.1-py3-none-any.whl
pip install some_package-0.1.tar.gz
```
pip treats .whl, .tar.gz, or .zip as installable archives.

4. **PyPI Package Name**
```bash
pip install requests
```
Finally if not a URL, path, or archive, `pip` assumes it’s a package name and queries the configured package index (usually PyPI).

---

###  What is `pyproject.toml` and Why Was It Introduced?

Before 2018, Python packages were typically built and installed using a `setup.py` script — a Python file that mixed together both **project metadata** and **build logic**.

####  The Problem with Legacy `setup.py`

- `setup.py` contained both metadata (e.g., name, version) and executable code for building the package.
- There was **no standardized way** to declare build dependencies (e.g., `setuptools`, `wheel`), so they had to be pre-installed manually.
- Builds occurred in the **global environment**, often leading to version conflicts and unpredictable behavior.
- **Editable installs** were implemented via `.egg-link` and `.pth` files, which were non-standard and fragile.

####  Introduction of `pyproject.toml` (PEP 518)

[PEP 518](https://peps.python.org/pep-0518/) introduced `pyproject.toml` as a **standard file** to declare build system requirements and decouple build logic from project code.

Key improvements:

- **Standardized Configuration**: Uses TOML syntax to declare build settings.
- **Isolated Builds**: `pip` can now install build dependencies in a **temporary environment** before building the package.
- **Build Backend Support**: Projects can now declare which **build backend** to use (e.g., `setuptools`, `flit`, `poetry`), making the packaging ecosystem more flexible.
- **Decoupled Build Logic**: Build steps are now handled by the backend, not hardcoded Python scripts.

Example `pyproject.toml`:

```toml
# ✅ Required for defining how the package should be built
[build-system]
requires = ["setuptools>=64", "wheel"]  # Build dependencies (installed in isolated env)
build-backend = "setuptools.build_meta"  # Build backend that pip will call

# ✅ Optional but recommended: project metadata as per PEP 621
[project]
name = "mypackage"                  # Name of your package
version = "0.1.0"                   # Version of the package
description = "A sample package"   # Short description
readme = "README.md"               # Path to README file (used on PyPI)
requires-python = ">=3.8"          # Minimum supported Python version
license = {text = "MIT"}           # License info

authors = [
  { name = "Jane Doe", email = "jane@example.com" }  # Author info
]

dependencies = [
  "requests>=2.25",                # Runtime dependencies
  "pydantic>=2.0"
]

# ✅ Optional: URLs for documentation, source, bug tracker, etc.
[project.urls]
"Homepage" = "https://example.com"
"Source" = "https://github.com/user/mypackage"
"Issues" = "https://github.com/user/mypackage/issues"
```
####  What Are Build Tools or build-system (Backends), and Why Do They Matter?

Build tools — also known as **build backends** — are responsible for:

- Building source distributions (`sdist`) and wheels (`.whl`)
- Handling metadata and packaging logic
- Supporting features like [editable installs]({{ site.posts | where: "slug", "pip-and-editable-install" | first.url | relative_url }})

They follow a **standard interface** defined in [PEP 517](https://peps.python.org/pep-0517/), which was introduced alongside `pyproject.toml` (PEP 518) to enable clean separation between **frontend tools** (like `pip`) and **build backends**.

#### 📦 Backend Interface Hooks

Backends expose a small set of standardized hooks or API that the frontend (like `pip`)calls :

- **Mandatory:**
  - `build_wheel`
  - `build_sdist`
- **Optional:**
  - `get_requires_for_build_wheel`
  - `prepare_metadata_for_build_wheel`
  - `get_requires_for_build_sdist`

These hooks allow `pip` and other tools to build and install packages **without needing to understand backend internals** — ensuring consistency and flexibility.

This PEP-defined interface is what makes tools like `flit`, `poetry`, and modern `setuptools` compatible with Python’s standardized build system — a major improvement over the tightly coupled `setup.py` workflows.

### Under the Hood: How pip Uses pyproject.toml (The flow we were waiting)
When you run:

```bash
pip install ./myproject
# or
pip install git+https://github.com/user/myproject.git
pip install requests
```
And the source contains a pyproject.toml (or setup.py in legacy builds), pip doesn't just "install" the package — it triggers a standardized build process defined by PEPs 517 and 518. **(these PEPs dont get applicable for setup.py hence we will continew with pyproject.toml the new way)*

Here’s how it unfolds:

1. **pip Reads `pyproject.toml`**  
   Looks for the `[build-system]` section:

   ```toml
   [build-system]
   requires = ["setuptools>=64", "wheel"]
   build-backend = "setuptools.build_meta"
   ```
This tells pip:
Which backend to use (e.g., setuptools, flit, poetry)
Which build dependencies to install first(in this case, setuptools and wheel)

2. **pip Creates an Isolated Build Environment**  
Per PEP 517, pip must isolate the build environment. This means:
- pip spins up a temporary environment (not your main virtualenv).  
- Installs the required build dependencies from `[build-system].requires` into that temp environment.  
- This ensures no interference from packages in your global or virtual environment.

    **(Real Output Example):**
    ```text
    Downloading setuptools-80.9.0-py3-none-any.whl.metadata (6.6 kB)
    Downloading setuptools-80.9.0-py3-none-any.whl (1.2 MB)
    Installing collected packages: setuptools
    Successfully installed setuptools-80.9.0
    ```

3. **pip Calls the Backend to Build the Package**  
Once the build dependencies are ready, pip:
- Calls the build backend APIs defined by `build-backend` using the [PEP 517 API](https://peps.python.org/pep-0517/).  
- The backend is expected to implement:
```python
# these are standardized interfaces
build_sdist() # These are called in the background by pip (or UV) to build the package
build_wheel() # These are called in the background by pip (or UV) to build the package
optional: build_editable()  # for editable installs (PEP 660)
```
So, for example, if `setuptools.build_meta` is the backend:
It builds the wheel (.whl) using **build_wheel()**
Or, **if editable install (-e), it calls build_editable() (if supported by backend)**

4. **pip Installs the Built Wheel**  
Once the wheel is successfully built:
- pip copies it into the current environment.  
- Installs it like any other `.whl` file using its internal installer.  
- At this point, the actual package is installed and usable.

5. ✅ **Bonus** If this is an editable install (`pip install -e .`), and the backend supports PEP 660, pip installs:
- `__editable__<project>_finder.py`  
- `__editable__<project>.pth`
    This points your environment to the live source code, not a copied package.

**Package Installation Flow**

```plaintext
pip install ./myproject
     ↓
Check for pyproject.toml
     ↓
[build-system]
requires = [...], backend = ...
     ↓
Create isolated build environment
     ↓
Install build dependencies from PyPI (ignores local)
     ↓
Call backend (e.g., setuptools.build_meta)
 → build_wheel() or build_editable()
     ↓
Install the built wheel into active environment
```
⚠️ **Important Notes**

- **`pyproject.toml`** **is mandatory** for modern builds.
- If **`pyproject.toml`** is missing, **pip may fallback** to legacy **`setup.py`** behavior (if still present).
- **pip never "randomly" installs from local directories** — it only does so if:
  - You explicitly provide a path like **`./mypkg`**, **and**
  - The directory contains a valid **`pyproject.toml`** or **`setup.py`**.


✨ **Final Word**

So under the hood, **pip is not a build tool**. It's an installer that delegates the actual build logic to whatever backend you've defined in **`pyproject.toml`**. That’s why your backend (e.g., **setuptools**) must be properly configured and up-to-date.
