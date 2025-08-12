---
layout: post
title: "Generics in Python: A Beginner's Guide"
date: 2025-08-10
desc: "Learn the fundamentals of generics in Python, how they enhance code flexibility and type safety, and practical examples to get you started."
tags: [python, generics, typing, tutorial, type-hints]
---
Before we jump into the world of **generics**, let’s first understand why **[typing is important in Python]({{ site.posts | where: "slug", "typing-in-python" | first.url | relative_url }})**.

- Introduction
- What Are Generics?
- How to Implement Generics in Python
- Why Was There a Need to Have Generics? What Problem Does It Solve?
- Two Ways to Instantiate Generic Classes in Python 3.12+
- Advanced Generics Unveiled (Python 3.12+)
- Conclusion

## Introduction
Have you ever written a Python function or a class that works for multiple types — like a list of numbers or strings? Generics let you tell Python: "This works for any type — but keep track of which one."
In this post, we’ll break down how that works in plain English.

---

#### 💡 Did You Know? Built-in Generics Aren’t Special

Type hints like `list[str]` and `dict[str, int]` are **generic types** — they accept type parameters.  
Behind the scenes, these are also defined as generic types.

#### 🧩 Here's the cool part:  
You can define your **own generics**` — just like Python’s built-ins.  
This allows for clean, reusable, and type-safe code.

Let’s continue the journey and see how this works in practice!

---

## What Are Generics?
Generics let you write one piece of code that can work with many different types — without losing track of what type it’s actually working with. Think of it like a “template” or a “blueprint” that adapts depending on the type you give it.

### Simple Analogy: Containers with Labels

Imagine you have many containers — **boxes**, **bags**, **jars**.

- Each container can hold **anything**: books, phones, clothes.
- But each container has a **label** that tells you what’s inside.

For example:

- A box labeled **“Books”** means it holds **books**.
- Another labeled **“Phones”** holds **phones**.

The container itself **doesn’t change** — same shape and size —  
only the **label** (the *type*) changes.

---

**Generics** are like those labeled containers:  
- The **code** (container) stays the same,  
- but the **type** (label) changes depending on what you want to store or work with.


## How to Implement Generics in Python

Python supports writing generic code in two main ways, depending on the version you're using.

### Old Way (Python < 3.12)

Before Python 3.12, to write generic classes, you needed to:

- Define a type variable using `TypeVar`. is like creating a placeholder or label
  - *This spot can be filled with any type you want, but once you pick a type, stay consistent with it throughout*
- Make your class inherit from `Generic` with that type variable.it is like telling a class
  -  *“I’m building a container that uses this labeled placeholder, so remember what type it holds and keep it consistent everywhere inside this container.”*

For example:

```python
from typing import TypeVar, Generic

T = TypeVar('T')  # Define a type variable (a placeholder for any type)

class Box(Generic[T]):
    def __init__(self, content: T):
        self.content = content

    def get_content(self) -> T:
        return self.content

def echo(item: T) -> T: # here `T` is typevar instance already defined 
    return item
```

### New Way (Python 3.12+)

Starting with **Python 3.12**, writing generics has become much cleaner and more intuitive thanks to **PEP 695**.

Instead of importing and defining `TypeVar`, and inheriting from `Generic`, you can now declare the type parameter **directly in the class or function definition**.

```python
# Python 3.12+
class Box[T]:
    def __init__(self, content: T):
        self.content = content

    def get_content(self) -> T:
        return self.content

def foo[A](value:A)->A:
    print("value accepted")
    return value
```
>Note : we can use any letter `T` or `A` or etc. but it should follow the proper syntax

ℹ️ **Info:** we will be continuing with python version 3.12+

## Why Was There a Need to Have Generics? What Problem Does It Solve?

Let’s take a simple example: **returning the first element of a list**.

At first, this looks easy — just write a function and return the first item.  
But once you bring in **type annotations** (especially when using tools like **MyPy**), a few important questions show up:

- What should be the return type of this function?
- What if the input list contains any type — an `int`, `str`, `float`, or even a custom object?
- How can we make sure the return type is accurate and flexible at the same time?

---

### The Problem Without Generics

Here’s a basic implementation:

```python
def return_first_element(input_ls: list) -> int | str | float:
    return input_ls[0]
```

### Problems with This Approach

- What if the list contains a custom object, a `bool`, or a `dict`?  
  The return type won’t be correct.

- You have to manually list all possible types in the return annotation.

- The function is not reusable, not fully type-safe, and hard to maintain as the codebase grows.

---

### The Generic-Based Solution

Here's the same function rewritten using generics:

```python
from typing import TypeVar, List

T = TypeVar('T')

def return_first_element(input_ls: List[T]) -> T:
    return input_ls[0]
```

### What Problem Does This Solve?
The function now works for any list: List[int], List[str], List[float], List[CustomType], etc.

- The return type matches whatever type the list contains.

- No need to hardcode all possible types.

- The code is now clean, type-safe, reusable, and future-proof.

- Type checkers like MyPy can now verify type correctness automatically.

```python
return_first_element([1, 2, 3])              # return type: int
return_first_element(["a", "b", "c"])        # return type: str
return_first_element([{"x": 1}, {"y": 2}])   # return type: dict[str, int]
```

#### ⚡ **Note:** Generics primarily shine in **classes**, where most of their power is used.

## Two Ways to Instantiate Generic Classes in Python 3.12+

With Python 3.12’s updated syntax, you can create generic class instances in two main ways.

### 1. Implicit Generic Instantiation (Type Inference from Constructor)

```python

class Box[T]:
    def __init__(self, value: T):
        self.value = value 

    def get_item(self) -> T:
        return self.value

    def change_item(self, value: T) -> None:
        self.value = value 

# Create an instance of Box, passing an integer 12
# Python infers T = int because 12 is an int
obj = Box(12)  # obj is treated as Box[int]

obj.change_item(12)      # ✅ Allowed: 12 matches inferred type int
obj.change_item("123")   # ❌ Type checker error: str is not compatible with int

```

### 🔍 How Does This Work?

-  When you call `Box(12)`, Python **infers the type** `T` as `int` because `12` is an integer.
-  Internally, the object behaves like a `Box[int]`.
-  **Type checkers** like MyPy use this inferred type to:
    - Ensure you're using the class consistently.
    - Catch any type mismatches during static analysis.

>💡 Key point:
- The constructor argument acts as a clue to Python and static analyzers to "fill in" the generic type automatically.
- If the constructor doesn't use `T` (*or any generic letter*), Python can't infer or enforce the type implicitly 

### 2.  Explicit Generic Instantiation (Manually Specify Type Parameter)

Sometimes, you might want to **explicitly specify** the type parameter when creating an instance:

```python
# Explicitly telling Python that T should be int
obj_int = Box[int](123)

# Explicitly telling Python that T should be str
obj_str = Box[str]("hello")
obj_bad = Box[str](123) # ❌ This will be caught by mypy 
```

##  Advanced Generics Unveiled (Python 3.12+)

### 1.  Bounded Type Variables — Ensuring Constraint Compliance

Rather than allowing any type, **bounded type variables** constrain generics to only those that meet specific criteria.  
This improves both **type safety** and **code clarity**.

```python
# Using classic (old-style) TypeVar constraints for context—verbose and less Pythonic:
# T = TypeVar("T", bound=int | float)  # <-- This is old style and more verbose

# New-style syntax (Python 3.12+): cleaner and built-in generic declaration
class Container[T: int | float]:
    def __init__(self, value: T):
        self.items = value

    def change_item(self, v: T) -> None:
        self.items = v

# Implicit inference: T inferred as int
obj = Container(12)
obj.change_item(100)        #  OK: both ints
obj.change_item(12.1)       #  MyPy ERROR: float not assignable to T (inferred as int)

# Explicit generic instantiation for float
obj_float = Container[float](10.29)  #  OK: float matches T

# Invalid: str not allowed by constraint
obj_str = Container[str]("12")      #  MyPy ERROR: "str" is not one of the allowed types for T

# Invalid: inference fails due to unsupported type
obj_mixed = Container("12")         #  MyPy ERROR: cannot infer T; "str" not allowed
```

> 🔍 **Example:**  
> `T: int | float` ensures that `T` is constrained to either `int` or `float`, allowing static type checkers like **MyPy** to catch incorrect usage.

This inline syntax is part of **[PEP 695](https://peps.python.org/pep-0695/)** — introduced in **Python 3.12+** — which brings **simpler and more powerful generics** to Python.

---

####  Why It's Useful

-  Ensures your generic class only works with **specific, compatible types**.
-  Catches misuse (like passing a `str`) **before runtime**.
-  Makes your code **cleaner, self-documenting, and future-proof**.
-  Encourages better design by making **type expectations explicit**.

### 2.  Multiple Type Parameters — Flexible Multi-Type Containers

In Python 3.12+, you can define classes that accept **multiple type parameters** directly.

```python
class Pair[K, V]:
    def __init__(self, first: K, second: V):
        self.first = first
        self.second = second

pair = Pair(1, "one")                # ✅ Type inferred: Pair[int, str]
pr_explicit = Pair[int, str](2, "two")  # ✅ Explicit type declaration

pr_invalid = Pair[int](2, "two")     # ❌ ERROR: Missing second type argument (V)
print(pair.first)    # Output: 1
print(pair.second)   # Output: one
```
####  How It Works

- `K` and `V` are **type placeholders**, introduced inline using the new generic syntax.
- They represent the types of `first` and `second`, respectively — allowing full control over multiple type parameters.



### 3.  Generics in Inheritance: Simplified and Typed (Python 3.12+)

#### a. Generic Base Classes

Define a base class that’s parameterized with a generic type, and then subclass it with a concrete type:

```python
class Repository[T]:
    def __init__(self, item: T):
        self.item = item

    def get(self) -> T:
        return self.item

class IntRepository(Repository[int]):
    pass

repo = IntRepository(123)
value: int = repo.get()  #  Type-safe: value is an int
```

Why this matters:

  - Less boilerplate and clearer inheritance.
  - The T placeholder makes the base class generic and flexible.

#### b. Enforcing Method Signatures in Subclasses

When overriding generic methods, re-declaring the specialized types ensures consistent static analysis:

```python
class A[T]:
    def process(self, item: T) -> str:
        return f"Processed {item}"

class B(A[int]):
    def process(self, item: int) -> str: # signature type mentioned
        return super().process(item)

result: str = B().process(42)  #  Correctly typed as str
```
### 4. Generic Protocols — Duck Typing Meets Type Safety

**Protocols** let you say:  
> “I don’t care what type you are, as long as you have these methods.”

Now combine that with **generics**, and you get flexible yet **type-safe interfaces**.

---

#### Example: `Saver[T]` Protocol

```python
from typing import Protocol, TypeVar

T = TypeVar("T")

class Saver(Protocol[T]):
    def save(self, item: T) -> None: ...
```
- Saver[T] is a generic protocol.

- Any class that implements a save(item: T) method will be treated as a Saver[T].

- No need for explicit inheritance — this is structural subtyping (aka duck typing).

```python
class FileSaver:
    def save(self, item: str) -> None:
        print(f"Saving text: {item}")

class DbSaver:
    def save(self, item: dict) -> None:
        print(f"Saving to DB: {item}")
```
These classes don’t inherit from Saver, but MyPy recognizes them as valid because they implement the expected save(item: T) method.

**Generic Function Using the Protocol**
```python
def store_item(saver: Saver[T], item: T):
    saver.save(item)

store_item(FileSaver(), "Hello")        #  Valid: item is str
store_item(DbSaver(), {"id": 1})        #  Valid: item is dict
```
#### Why It Matters
- Loose coupling: You don’t force classes to inherit — they just need the right shape.

- Strong typing: Static checkers still verify everything.

- Generic flexibility: Saver[T] works for any T.

>Protocols + Generics = The best of both dynamic and static typing worlds!

## Conclusion

Generics in Python — especially with the new Python 3.12+ syntax — bring **clarity, reusability, and type safety** to your code. Whether you're writing flexible data structures, reusable functions, or protocols that enforce interface contracts, generics help you express intent while catching bugs early.

They aren’t just for libraries or advanced use cases — they're for **anyone writing code that works with multiple types**.

> As Python evolves, mastering generics is a step toward writing cleaner, more maintainable, and future-proof code.

Happy typing!