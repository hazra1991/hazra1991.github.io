---
layout: post
title: "Understanding Type Hints in Python"
date: 2025-08-10
desc: "A beginner-friendly guide to Python type hints: what they are, how to use them, and why they improve code readability and safety."
tags: [python, typing, type-hints, tutorial, mypy, code-quality]
---

Imagine you’re writing a simple Python script:

```python
a = 10
b = 20
c = a + b
print(c)   # output 30
```

Life is simple, right?  
Thanks to Python’s **dynamic typing system**, you don’t have to worry about what type of values `a`, `b`, or `c` are — Python figures it out **while the program runs**.

---

Now, imagine you write a simple function that adds two numbers:

```python
def add(a, b):
    return a + b
```

This works great! ✅

But what happens if someone calls this function with a **string** instead of a **number**?  
Like this:

```python
add("hello", "world")
```

Suddenly, the function behaves unexpectedly (string concatenation) or, in other cases, might throw an error.

---

### How Do We Tell Users What Types We Expect?

We want to clearly say:

- The function **expects inputs** of a certain type  
- The function **returns a value** of a certain type

This is where **typing in Python** comes in.

### Typing in Python

Typing lets us **add hints** about what types a function expects and what it returns.

These hints help:

1. **You and your team** understand what kind of data should be used  
2. **Tools like [Mypy](https://mypy-lang.org/)** (static type checkers) catch potential errors *before* running the code

Example with type hints:

```python
def add(a: int, b: int) -> int:
    return a + b
```
> **note** Python itself does not enforce these types at runtime — it just provides hints for humans and tools.

## Type Hints in Modern Python

Since **Python 3.9**, type hinting has become more intuitive and Pythonic thanks to support for **built-in generic types**. Instead of importing `List`, `Dict`, or `Tuple` from the `typing` module, you can now use the native `list`, `dict`, and `tuple` types with bracketed annotations.

---

> ⚠️ **Before Python 3.9**:  
> Developers relied on `typing.List`, `typing.Dict`, and `typing.Tuple` to annotate generic types.
>
> ✅ **From Python 3.9 onward**:  
> You can (and should) use `list`, `dict`, `tuple`, and other built-in types directly for type annotations, like `list[str]`, `dict[str, int]`, etc. This makes the code cleaner and avoids unnecessary imports.

---

### Common Type Hints (Python 3.9+)

| Type Hint               | Description                                                  |
|-------------------------|--------------------------------------------------------------|
| `list[str]`             | A list of strings                                            |
| `dict[str, int]`        | A dictionary with string keys and integer values            |
| `tuple[int, float]`     | A tuple where the first item is an int and the second a float |
| `str | None`             | Optional string — either a `str` or `None`                   |
| `int | float`           | Union — value can be an `int` or a `float`                   |
| `Any`                   | Any type (type checking is effectively disabled)             |

---

#### Examples (Python 3.9+ Style)

```python
def load_users(data: list[dict[str, str]]) -> None:
    ...

def get_price(tag: str) -> float | None:
    ...

def merge(a: int | float, b: int | float) -> float:
    ...

from typing import Any  # Still needed when using 'Any'

def debug(value: Any) -> None:
    ...
```

## What's New in Typing and Type Checking

Python’s typing ecosystem keeps evolving, making type annotations more powerful and easier to write. Here’s a quick dive into some of the best new features in Python 3.12 — plus some handy tips on type checking.

---

### 1. `type` Keyword for Type Aliases

Python 3.12 introduces the `type` keyword for defining type aliases, simplifying the old approach that required `TypeAlias` or `TypeVar` imports.

```python
type Point = tuple[float, float]

type Point[T] = tuple[T, T]  # these are generics 
```
### 2. Typed **kwargs with TypedDict & Unpack (PEP 692)

Previously, typing keyword arguments (**kwargs) required all values to be of the same type. Python 3.12 changes that with the combination of `TypedDict` and `Unpack`, enabling precise, structured typing for kwargs.

```python
from typing import TypedDict, Unpack

class Movie(TypedDict):
    name: str
    year: int

def print_movie_details(**kwargs: Unpack[Movie]) -> None:
    print(kwargs["name"], kwargs["year"])
```
- This allows functions to enforce exact keyword argument shapes and types, enhancing static analysis and reducing runtime errors.

### 3. The `@override` Decorator (PEP 698)

To improve safety and clarity in class inheritance, Python 3.12 adds an `@override` decorator for methods overriding a parent class method.

```python
from typing import override

class Base:
    def greet(self) -> str:
        return "Hello"

class Child(Base):
    @override
    def greet(self) -> str:
        return "Hi"

class BadChild(Base):
    @override  # This will raise a type checking error
    def greets(self) -> str:
        return "Oops"
```
- Type checkers will flag any methods marked with @override that don't actually override a base class method, helping catch bugs from misnamed overrides.

### 4. TypedDict: Structuring Dictionaries with Types

Python’s `TypedDict` (introduced in Python 3.8 via the `typing` module and improved in later versions) lets you define dictionaries with a fixed structure, specifying the expected keys and their value types.

This is super useful because normal dictionaries are untyped — meaning they can contain anything, anywhere, which can lead to bugs if you misspell keys or use wrong value types.

---

#### Why Use TypedDict?

- **Clear structure:** Explicitly define what keys your dictionary should have and what type of data each key stores.
- **Static checking:** Tools like Mypy will warn if you miss required keys or use wrong types.
- **Better autocompletion:** IDEs can suggest keys and expected types when you work with these dictionaries.

---

#### How to Define a TypedDict

```python
from typing import TypedDict

class Movie(TypedDict):
    name: str
    year: int
    rating: float
```
Here, a Movie dictionary must have:

"name": a string

"year": an integer

"rating": a float

Using TypedDict
```python
def print_movie(movie: Movie) -> None:
    print(f"{movie['name']} ({movie['year']}) has rating {movie['rating']}")

my_favorite = {"name": "Inception", "year": 2010, "rating": 8.8}
print_movie(my_favorite)
```
If you forget a key or use the wrong type:

```python

my_favorite = {"name": "Inception", "year": "2010", "rating": 8.8}  # year should be int, not str

# Mypy will catch this error during static analysis.
```
**Optional Keys in TypedDict**
- You can specify some keys as optional using NotRequired (introduced in Python 3.11):

```python
from typing import TypedDict, NotRequired

class Movie(TypedDict):
    name: str
    year: int
    rating: float
    director: NotRequired[str]  # Optional key
```
Now director can be omitted safely:

```python

movie1: Movie = {"name": "Inception", "year": 2010, "rating": 8.8}  # OK
movie2: Movie = {"name": "Dunkirk", "year": 2017, "rating": 7.9, "director": "Nolan"}  # OK
```
---

### Real-World Use Case example
```python

class UserProfile(TypedDict):
    username: str
    email: str
    age: NotRequired[int]

def create_profile(profile: UserProfile) -> None:
    print(f"User: {profile['username']}, Email: {profile['email']}")

profile_data = {"username": "johndoe", "email": "john@example.com"}
create_profile(profile_data)  # Works even without 'age'
```
Why TypedDict Matters in Python Development , When you want the flexibility of dictionaries but also want structure and safety, TypedDict strikes a perfect balance — improving code maintainability and developer confidence.

## Conclusion: Type Hints Make Python Better

Modern Python typing is no longer just “nice to have” — it’s a practical tool for writing clearer, safer, and more maintainable code.

With features like `TypedDict`, `@override`, and the new `type` keyword, Python now supports robust type annotations without sacrificing its dynamic nature.

Whether you're working solo or on a large team, adding type hints helps catch bugs early, improve IDE support, and make your codebase easier to understand.

*Start small, check often, and let type hints work for you — Python stays flexible, and your code becomes stronger.*