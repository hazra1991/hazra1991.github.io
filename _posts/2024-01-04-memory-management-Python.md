---
layout: post
title: "Memory Management in C and Python: A Comparative Overview"
date: 2024-01-04
desc: "A clear comparison of memory management concepts in C and Python, covering stack vs heap, reference counting, garbage collection, and weak references."
tags: [python, c, memory-management, tutorial, comparison, programming, guide, beginner]
---

- Memory Management in C
- Memory Management in Python
- Reference Counting and Garbage Collection (GC) in Python
- Weak References in Python
- Sources and Further Reading


## 1. Memory Management in C

In C programming, memory is conceptually divided into three main sections:

### a) Code/Text Segment
- Stores the compiled program code (instructions).
- This is read-only and contains the executable code.

### b) Stack Memory
- Used for static memory allocation.
- Stores:
  - Function call frames (activation records).
  - Local variables.
  - Return addresses.
- Grows and shrinks automatically as functions are called and return.
- Managed by the system (compiler/runtime).
- Limited in size.
- **Stack Overflow** occurs when too many nested function calls or large local variables exceed stack size.

### c) Heap Memory
- Used for dynamic memory allocation.
- Memory allocated at runtime using `malloc()`, `calloc()`, `realloc()`.
- Needs to be explicitly freed with `free()` to avoid memory leaks.
- Memory is borrowed from the OS.
- Larger but slower than stack.
- Memory fragmentation can occur.

Example in C:
```c
int main() {
    int a = 10;       // 'a' allocated on stack
    int *ptr = malloc(sizeof(int));  // dynamic allocation on heap
    *ptr = 20;
    free(ptr);        // free heap memory
    return 0;
}
```

## 2. Memory Management in Python

Python abstracts memory management but conceptually it also uses stack and heap memory:

### Key Points:
- Everything in Python is an object.
- Objects are always stored in **heap memory**.
- Variables/names/references are stored on the **stack** (or within the function/local/global scopes).
- Python variables are references (or pointers) to heap objects.
- When you write `x = 10`, the integer object `10` exists in the heap; `x` is a reference to that object, stored in the current namespace (stack).
- Functions, classes, and their frames (local variables) are managed on the stack.

### Stack vs Heap in Python

| Stack                             | Heap                                  |
|----------------------------------|-------------------------------------|
| Stores references (variable names) | Stores actual objects                |
| Manages function calls, local variables | Dynamic memory allocation for objects |
| Limited in size, managed automatically | Larger, managed by Python's memory allocator and garbage collector |

Example in Python:
```python
a = 10           # 'x' refers to int object 10 in heap
def fun():
    b = 20       # 'y' refers to int object 20 in heap (inside function stack frame)
    return y

class Car:
    def __init__(self):
        self.z = 10  # self.z refers to int object 10 in heap

cobj = Car()     # cobj refers to Car object in heap
```
**A Visual undersanding of the internals**
![diagram1](/assets/images/snaps/mem_manage_2.png)
![diagram1](/assets/images/snaps/mem_manage_1.png)

---
### Reference Counting and Garbage Collection (GC)

Python uses **reference counting** as its primary memory management mechanism:

- Each object has a counter tracking how many references point to it.
- When references drop to zero, the object is immediately deallocated.
- Python also uses a **cyclic garbage collector** to clean up reference cycles (objects referencing each other).

### Different Python Interpreters and GC:
- **CPython** uses reference counting + cyclic GC.
- **PyPy** uses a tracing garbage collector.
- **Jython** and **IronPython** use Java/.NET GCs respectively.

### Reference Table Example

| Object | Number of References |
|--------|----------------------|
| car    | 2                    |
| 100    | 1                    |
| 10     | 1                    |

When an assignment like `cobj = None` happens, the reference to the original `car` object is removed. If no other references exist, it becomes eligible for garbage collection.

---

## 3. Weak References in Python

- The `weakref` module allows the creation of **weak references**.
- Weak references **do not increase** the reference count of the object.
- Useful for caching and observing objects **without preventing their garbage collection**.
- You can check if an object still exists through a weak reference before it gets collected.

```python
import weakref

class C:
    def __init__(self):
        print("Hi")

obj = C()            # strong reference
print(obj)

r = weakref.ref(obj) # weak reference
print(r)             # prints weakref object

del obj              # deletes strong reference

print(r())           # None, as object is garbage collected

```

**Sources**

- Python Documentation: Memory Management  
- Python’s `weakref` module docs: [https://docs.python.org/3/library/weakref.html](https://docs.python.org/3/library/weakref.html)  
- *Understanding and Using C Pointers* by Richard Reese  
- Real Python articles on memory management and garbage collection  