---
layout: post
title: "Python Closures and Decorators: How They Actually Work"
date: 2026-10-12
description: "How can an inner function still use a variable from a function that already returned? Closures and cells explained with small examples, the traps they set, and how decorators turn out to be just closures with nicer syntax."
categories: [Python, Language]
tags: [python, closures, decorators, scoping]
---

A function finishes and returns. Its local variables should be gone. Yet a function it handed back can still *use* one of them. How?

That one doubt is this whole post. We'll answer it, and then notice that **decorators are the same trick with nicer syntax**.

> **What we'll cover**
> 1. The doubt: how does the inner function still see the variable?
> 2. The answer: Python decides at *compile time*, and keeps the variable in a **cell**.
> 3. Three traps: late binding, `nonlocal`, class bodies.
> 4. Decorators: what they are, with arguments, stacking, and when they run.
> 5. A real use: a registry decorator.
{: .prompt-info}

---

## **The doubt** {#doubt}

```python
def fun(f):
    def inner(val):
        print(f)
        print(val)
    return inner

g = fun(1)
g(2)
```

```
1
2
```

`fun(1)` has finished. Its `f` should be gone. And `inner` never ran while `fun` was running, so how did it know it would need `f`?

The hidden assumption is *"Python only works out what `inner` needs when `inner` runs."* That's the wrong part.

---

## **The answer: decided before anything runs** {#compile}

Python works in two steps:

| Step | When | What happens |
|---|---|---|
| **Compile** | the file is loaded | Python reads the *text* of every function, nested ones too, and decides for every name: local, enclosing, global or builtin. |
| **Run** | the function is called | It executes, using the decisions already made. |

While compiling `fun`, Python looks inside `inner` and thinks: *"`f` is not a parameter of `inner` and not assigned there, but `fun` has it. `inner` needs `f` from `fun`."*

That decision is written into the compiled code, and you can read it:

```python
fun.__code__.co_cellvars        # ('f',)  fun's variable that an inner function needs
fun(1).__code__.co_freevars     # ('f',)  the name inner borrows from outside
```

Same variable, seen from both sides. The outer one is a **cell variable**, the inner one a **free variable**.

---

## **What happens when `fun(1)` runs** {#steps}

Because `f` was marked as needed by an inner function, Python doesn't keep it as a plain local. It puts it in a small box called a **cell**.

```
1. fun(1) starts            f ──► [ cell ] ──► 1

2. "def inner" executes     inner (new function object)
                              ├─ __code__    → the body
                              └─ __closure__ → ( [ cell ] ──► 1 )

3. fun returns              fun's frame is thrown away.
                            The cell survives: inner still points at it.

4. g(2) runs                val → 2 (normal local)
                            f   → read through the cell → 1
```

Two things worth noticing:

- `def` is a statement that **runs**. Every call to `fun` builds a brand-new `inner`, and attaches the cell *at that moment*, not when `inner` is called.
- Nothing is magic. The cell is kept alive simply because something still references it.

You can look inside:

```python
g = fun(1)
g.__closure__                      # (<cell at 0x...: int object at 0x...>,)
g.__closure__[0].cell_contents     # 1
```

And every call makes its own cell:

```python
a, b = fun(1), fun(99)
a.__closure__[0] is b.__closure__[0]     # False: each one remembers its own f
```

> A **closure** is a function plus the cells for the outside variables it uses.
{: .prompt-tip}

### **Why `fun(1)()` failed** {#why-failed}

It wasn't about `f`. `fun(1)` worked and returned `inner`; the `()` then called `inner` with no argument, and `inner` needs `val`:

```
TypeError: fun.<locals>.inner() missing 1 required positional argument: 'val'
```

### **A peek at the bytecode** {#bytecode}

`dis.dis(fun)` shows it. The names to recognise (they shift slightly between Python versions):

| Instruction | Meaning |
|---|---|
| `MAKE_CELL f` | turn local `f` into a cell at the start of `fun` |
| `MAKE_FUNCTION` + closure | build `inner` and attach the cells |
| `LOAD_DEREF f` | inside `inner`: read `f` *through* the cell |
| `LOAD_FAST val` | a normal local read |
| `LOAD_GLOBAL print` | a global/builtin lookup, no closure involved |

---

## **Where Python looks for a name** {#legb}

For any name, Python checks in this order: **L**ocal → **E**nclosing function → **G**lobal → **B**uiltin. Closures are the "E".

The *category* of each name is fixed at compile time. Only the *value* is fetched at run time. Module-level variables are not closures: a function reading a global just looks it up each time, and nothing is captured.

---

## **Three traps** {#traps}

### **1. A cell holds the variable, not a snapshot** {#late-binding}

```python
def outer():
    x = 1
    def inner():
        return x
    x = 2              # changes what the cell holds
    return inner

outer()()              # 2, not 1
```

This is why the classic loop surprise happens:

```python
funcs = [lambda: i for i in range(3)]
[f() for f in funcs]                    # [2, 2, 2]   all share one i
```

Fix it by capturing the value now, with a default argument, or by creating a fresh cell per call:

```python
funcs = [lambda i=i: i for i in range(3)]       # [0, 1, 2]
```

### **2. Assigning needs `nonlocal`** {#nonlocal}

```python
def counter():
    count = 0
    def inc():
        count += 1          # UnboundLocalError
        return count
    return inc
```

Python sees an *assignment* to `count` inside `inc` and decides, at compile time, that `count` is local to `inc`. Then `count += 1` reads it before it has a value. The error itself proves scoping is decided before running.

Tell Python it belongs to the enclosing function:

```python
def counter():
    count = 0
    def inc():
        nonlocal count
        count += 1
        return count
    return inc

c = counter()
c(), c(), c()               # (1, 2, 3)
```

### **3. Class bodies are skipped** {#class-body}

```python
class A:
    y = 10
    def method(self):
        return y            # NameError
```

A class body is a temporary namespace, not an enclosing function, so LEGB skips it. Use `self.y` or `A.y`.

---

## **Decorators: closures with a nicer syntax** {#decorators}

A decorator is a function that receives a function and returns something to replace it. This:

```python
@deco
def f(): ...
```

means exactly this:

```python
def f(): ...
f = deco(f)
```

A first useful one, which logs every call:

```python
import functools

def log_calls(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        print(f"calling {func.__name__}")
        return func(*args, **kwargs)
    return wrapper              # wrapper closes over func

@log_calls
def add(a, b):
    return a + b

add(2, 3)
```

```
calling add
```

(and the call returns `5`). Look familiar? `wrapper` is `inner`, and `func` is `f`. It's the same closure.

`functools.wraps` copies the original's name and docstring onto `wrapper`. Without it, `add.__name__` would say `wrapper`, which confuses logs and debuggers.

### **Decorators with arguments: one more layer** {#with-args}

```python
@repeat(times=3)
def hello(): print("hi")
```

is two steps:

```python
deco = repeat(times=3)      # 1. call the factory, get the real decorator
hello = deco(hello)         # 2. apply it
```

So there are three levels, each closing over what's above it:

```python
def repeat(*, times):                     # level 1: takes the decorator's arguments
    def decorator(func):                  # level 2: takes the function
        @functools.wraps(func)
        def wrapper(*args, **kwargs):     # level 3: replaces the function
            for _ in range(times):
                result = func(*args, **kwargs)
            return result
        return wrapper
    return decorator
```

### **Stacking and classes** {#stacking}

```python
@a
@b
def f(): ...
```

is `f = a(b(f))`. The decorator **closest to the function runs first**. (With prints in each, `b` appears before `a`.)

Class decorators are the same idea with a class passed in: `C = deco(C)`. They usually register or tweak the class and return it unchanged.

### **They run at import time** {#import-time}

The decorator runs when the `def` or `class` statement executes, which is when the module is **imported**, not when the function is called. If a module is never imported, its decorators never run.

---

## **Putting it together: a registry decorator** {#registry}

A common pattern: classes register themselves under a name.

```python
HANDLERS = {}

def register(*, name):                       # level 1: like `fun`
    def deco(cls):                           # level 2: like `inner`
        if name in HANDLERS:
            raise ValueError(f"'{name}' is already registered")
        HANDLERS[name] = cls
        return cls                           # hand the class back unchanged
    return deco

@register(name="csv")
class CsvHandler: ...

@register(name="json")
class JsonHandler: ...
```

| Small example | Registry |
|---|---|
| `fun` | `register` |
| `f` (captured) | `name` (captured) |
| `inner` | `deco` |
| `val` (given later) | `cls` (the decorated class) |

What happens at `@register(name="csv")`:

1. `register(name="csv")` runs, makes a cell for `name`, and returns `deco`.
2. Python calls `deco(CsvHandler)`. `name` is read through the cell, and the class is stored.
3. `deco` returns the class, so `CsvHandler` still means the original class.

Because decorators run at import time, a registry only fills up if every handler module is imported somewhere, often in the package's `__init__.py`.

---

## **Debugging toolbox** {#toolbox}

```python
f.__code__.co_freevars          # names f borrows from outside
outer.__code__.co_cellvars      # outer's variables used by inner functions
f.__closure__                   # tuple of cells (None if no closure)
f.__closure__[0].cell_contents  # the value inside a cell
f.__wrapped__                   # the original, if functools.wraps was used

import inspect
inspect.getclosurevars(f)       # the most readable view of everything f depends on
```

```
ClosureVars(nonlocals={'f': 1}, globals={}, builtins={'print': <built-in function print>}, unbound=set())
```

---

## **Summary** {#summary}

- Python decides at **compile time** which names an inner function needs from outside.
- Those variables live in **cells**. Each time the outer function runs, `def inner` builds a new function and attaches the cells to its `__closure__`.
- The outer frame dies, the cells live on, because the inner function still points at them.
- A cell holds the **variable**, not a copy. That explains late binding and why assigning needs `nonlocal`.
- A **decorator** is a function that takes a function (or class) and returns its replacement. One with arguments is a function that returns a decorator, one extra closure layer.
