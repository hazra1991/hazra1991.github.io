---
layout: post  
title: "Introduction to NETCONF and YANG"  
date: 2024-06-24
desc: "Explore how NETCONF and YANG work together to simplify and standardize network configuration and management. Ideal for network engineers and developers new to these technologies"  
tags: [netconf, yang, networking, tutorial]
---

Network automation is moving beyond traditional CLI-based approaches.  
Two of the most important building blocks enabling structured, machine-readable network configuration are **NETCONF** and **YANG**.  

In this article, we’ll explore:

- What NETCONF is and how it works  
- The role of YANG data models  
- XML tags and operations used in NETCONF  
- Real-world examples and usage tips  

---

## 1. What is NETCONF?

NETCONF (Network Configuration Protocol) is a **network management protocol** designed for installing, manipulating, and deleting the configuration of network devices.  

Unlike older protocols like **SNMP** (which uses its own transport and security models), NETCONF operates **over SSH** for both secure transport and authentication.  
This design choice meant the protocol could rely on SSH's proven mechanisms rather than reinventing connection and encryption from scratch.

**Key points about NETCONF:**
- **Transport:** SSH (default port **830**)  
- **Encoding:** XML (all messages are XML-based)  
- **Model-driven:** Uses YANG models to describe device capabilities and configuration  
- **Supported operations:** Retrieve state, push configuration, validate changes, commit/discard changes, lock resources, and more  

> **Note:** The NETCONF port can be NATed to a different value in some environments.  

---

## 2. Enabling NETCONF on Cisco Devices

Before a NETCONF client can communicate with a device, the NETCONF service must be enabled.

**Example (Cisco IOS-XE):**
```shell
# 1. Enable SSH by generating RSA keys
crypto key generate rsa

# 2. Restrict VTY transport to SSH
line vty 0 4
 transport input ssh

# 3. Enable NETCONF over SSH
netconf-yang
```

---

## 3. Connecting to NETCONF

You can test a NETCONF connection directly over SSH:

```bash
ssh developer@ios-xe-mgmt-latest.cisco.com -p 10000
```

Once connected, the first step is the **Hello exchange**.

---

## 4. The Hello Message Exchange

Just like other network protocols, NETCONF starts with a **capabilities exchange**.

### Example: Hello from the server (device)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
    <capabilities>
        <capability>urn:ietf:params:netconf:base:1.0</capability>
    </capabilities>
    <session-id>2597</session-id>
</hello>]]>]]>
```

### Example: Hello from the client
```xml
<?xml version="1.0" encoding="UTF-8"?>
<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
    <capabilities>
        <capability>urn:ietf:params:netconf:base:1.0</capability>
    </capabilities>
</hello>]]>]]>
```

> The namespace (`xmlns`) must match the server’s, or the hello process will fail.

---

## 5. NETCONF Message Structure

All NETCONF communication uses **XML tags** with a special sequence:

- `]]>]]>` marks the **end of an XML message**.  
- `<rpc>` wraps a request; `message-id` is mandatory.  
- `<rpc-reply>` wraps the server's response.

### Common XML Tags
| Tag              | Purpose |
|------------------|---------|
| `<hello>`        | Capability exchange during connection setup |
| `<rpc>`          | Encapsulates an operation request (requires `message-id`) |
| `<rpc-reply>`    | Contains the server’s reply |
| `<ok/>`          | Indicates successful operation |
| `<data>`         | Holds configuration or state data in a `<rpc-reply>` |
| `<target>`       | Specifies the datastore being modified (e.g., `<running/>`, `<candidate/>`) |
| `<error-info>`   | Provides additional error details |

---

## 6. NETCONF Operational Tags

Operational tags are **wrapped inside `<rpc>`** and define the actual request:

| Operation          | Description | Example |
|--------------------|-------------|---------|
| `<close-session/>` | Close the NETCONF session | `<rpc><close-session/></rpc>` |
| `<commit/>`        | Commit candidate changes to running config | `<rpc><commit/></rpc>` |
| `<copy-config>`    | Replace a datastore with new config | `<rpc><copy-config>...</copy-config></rpc>` |
| `<delete-config>`  | Delete an entire datastore | |
| `<discard-config>` | Discard uncommitted candidate changes | |
| `<edit-config>`    | Modify configuration in a datastore | `<rpc><edit-config>...</edit-config></rpc>` |
| `<get>`            | Retrieve operational state (optional `<filter>` to limit output) | |
| `<get-config>`     | Retrieve config from a specific source datastore | `<rpc><get-config><source><running/></source></get-config></rpc>` |
| `<kill-session>`   | Terminate a session by ID | |
| `<lock>`           | Lock a datastore to prevent edits by others | |
| `<unlock>`         | Unlock a previously locked datastore | |
| `<validate>`       | Check if a candidate config is syntactically correct | |

---

## 7. Example: Closing a NETCONF Session

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rpc message-id="1212434" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
    <close-session/>
</rpc>]]>]]>
```

---

## 8. What is a Data Model?

Think of a **data model** as a blueprint for describing objects.  
For example, to describe a *person*, you might define:
- Name
- Height
- Skin color
- Eye color
- Hair type

The actual values are **not** part of the model—just the **attributes**.

In networking, a data model for an interface might specify:
- A unique name
- A description
- Its operational state (up/down)
- Allowed read/write operations

---

## 9. YANG – The Data Modeling Language

YANG is a **data modeling language** used to define:
- The structure of configuration and state data
- The rules for accessing and modifying that data

> If **MIB** is the data model for SNMP,  
> **YANG** is the data model for NETCONF (SSH) and RESTCONF (HTTP).

**Important:**
- YANG is **not** transferred over the wire—only data **conforming** to the YANG schema is.
- The data itself is typically serialized as XML or JSON.

---

## 10. Standard vs Vendor YANG Models

YANG models come from two main sources:
- **Standards bodies** (e.g., IETF, OpenConfig)
- **Vendors** (e.g., Cisco, Juniper)

Example:
- `ietf-interfaces.yang` (standardized by IETF)
- `Cisco-IOS-XE-interfaces.yang` (Cisco-specific)

---

## 11. Working with YANG in Python

A popular tool for exploring YANG files is **pyang**.

**Install:**
```bash
pip install pyang
```

**Example usage:**
```bash
pyang -f tree ietf-interfaces.yang
```

This produces a tree view of the data model.

---

## 12. Programmatic Access to NETCONF

Libraries like **ncclient** in Python provide an abstraction over the XML exchange.

Example: The `manager.connect()` function (from `ssh.py` in ncclient) accepts parameters like:
```python
def connect(
    host,
    port=830,
    timeout=None,
    username=None,
    password=None,
    key_filename=None,
    hostkey_verify=True,
    look_for_keys=True
):
    ...
```
Once connected, you can send `<get-config>`, `<edit-config>`, and other RPCs directly from Python.

---

## 13. Final Thoughts

NETCONF and YANG together form a **powerful, standards-based foundation** for modern network automation.  
They enable:
- **Structured configuration management**
- **Machine-readable device capabilities**
- **Safe, transactional changes**

If you’re moving toward automation, understanding these concepts—and practicing with real devices or sandboxes—will set you up for success.

---

**References:**
- [RFC 6241 – Network Configuration Protocol (NETCONF)](https://datatracker.ietf.org/doc/html/rfc6241)  
- [Juniper NETCONF Tag Summary](https://www.juniper.net/documentation/en_US/junos/topics/reference/tag-summary/netconf-target.html)  
