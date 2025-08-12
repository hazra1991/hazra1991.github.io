---
layout: post
title: "pip install -e and Editable Installs"
date: 2023-12-25
desc: "Learn how pip and pyproject.toml work together in modern Python packaging. Understand installation flow, build systems, and best practices."
tags: [python, pip, pyproject.toml, packaging, build-system, tutorial]
---

Editable installs (`pip install -e`) are essential for Python developers working on packages under active development. 

But the *how* of this feature has evolved significantly in recent years — moving from `setup.py develop` and `.egg-link` to modern **PEP 660-compliant editable wheels**.

#### What is an Editable Install?
When you run `pip install -e .`
You're telling pip:
"Install this package in editable (or development) mode."

This means:
- Python will import the code directly from your source directory,
- Not install it into site-packages,
- And reflect any source code changes instantly, without reinstalling.

***Perfect for package development or contribution workflows.***

####  Legacy vs  Modern Editable Installs

**Legacy Method: `setup.py develop`**
- Creates an `.egg-link` file in `site-packages`
- Adds a `.pth` file (if needed) to include your source directory in `sys.path`
- An `.egg-link ` file pointing to your source directory
- `.pth` files to add your source to sys.path

Used by `setuptools<=64` via:

```bash
python setup.py develop
```
Or by pip internally when a fallback is triggered.
Edits in source take effect immediately
Dependencies were sometimes installed via easy_install, which is now deprecated

**Modern (Post-PEP 660): Editable Wheels**

Starting with [PEP 660](https://peps.python.org/pep-0660/), editable installs are now **standardized** and **wheel-based**.

Backend Requirements
- Must implement the following hooks:
  - `build_editable`
  - `prepare_metadata_for_build_editable`

`pip` (Frontend) Behavior
- Builds a **virtual editable wheel**
- Writes files like:
  - `__editable__<pkg>.pth` – Adds source directory to `sys.path`
  - `__editable__<pkg>_finder.py` – Dynamic import hook
  - `direct_url.json` – Marks source + editable state in `.dist-info`

**Supported in:**  `pip >= 21.3`  ,`setuptools >= 64` (along with other that supports and implements the build interfaces **PEPs 517**)

**Understanding `__editable__*` Files**

| File                                 | Purpose                                                                 |
|--------------------------------------|-------------------------------------------------------------------------|
| `__editable__<pkg>.pth`              | Adds your source directory to `sys.path`                                |
| `__editable__<pkg>_finder.py`        | Dynamically routes imports using `sys.meta_path` hook                   |
| `direct_url.json` (in `.dist-info`)  | Records that the install came from a local source and is editable       |

These are `pip`’s **new, standardized way of performing editable installs** — completely replacing the old `.egg-link` mechanism.
These act as redirectors to your source tree, instead of copying files like a normal wheel.

```md
Example: What Files Are Created?
Assume you install a project with pip install -e . using setuptools 80.

You’ll see in your site-packages/:

markdown
Copy
Edit
__editable__my_pkg.pth
__editable__my_pkg_finder.py
my_pkg-0.1.dist-info/
  ├── METADATA
  ├── direct_url.json
```

#### Comparing Real Scenarios

Let’s compare what you might see when installing the same codebase across two different VMs:

| VM   | Build Backend     | Files Created in site-packages                          | Editable Mode         |
|------|--------------------|----------------------------------------------------------|------------------------|
| VM1  | `setuptools >= 64` | `__editable__*.pth`, `*_finder.py`, `direct_url.json`    | ✅ Modern (PEP 660)     |
| VM2  | `flit`             | `pkgname.pth`, `.dist-info/` only                        | 🟡 Legacy fallback      |

**Why the Difference?**

- Because **Flit doesn't support PEP 660** (as of today), `pip` can't use the modern editable mechanism and **falls back to simpler legacy `.pth` style**.

- Even if both systems use `pip 25.0` and `Python 3.13.5`, the behavior depends entirely on your **project’s build backend**.

---

**Why You Might See Different Install Artifacts**

| File                             | When Seen             | Role                                         |
|----------------------------------|------------------------|----------------------------------------------|
| `__editable__<pkg>.pth`          | PEP 660 mode           | Adds source dir to `sys.path`                |
| `__editable__<pkg>_finder.py`    | PEP 660 mode           | Routes imports using `sys.meta_path`         |
| `direct_url.json`                | Both modes             | Records source origin and editable flag      |
| `pkgname.pth`                    | Legacy mode / fallback | Adds source dir to `sys.path`                |
| `.egg-link`                      | Very legacy            | Adds source dir (used with `setup.py develop`) |

---


Force Modern Editable (PEP 660)

Make sure your `pyproject.toml` looks like this:

```toml
[build-system]
requires = ["setuptools>=64", "wheel"]  # using new setuptools or any backend that fits the PEPs built standard
build-backend = "setuptools.build_meta"
```

#### How to Debug Editable Installs

- Inspect your `site-packages/` directory  
  Look for `__editable__*.py`, `.pth`, or `.egg-link` files  
  These indicate how `pip` performed the install

- Check your `pyproject.toml`  
  Missing or invalid backend? Pip may fall back to legacy mode

- Check your backend version:

```bash
pip show setuptools
```
Check if the build_editable hook is defined

- Supported backends: setuptools, Poetry >= 1.2, hatchling

- Not supported: flit, older Poetry versions