---
layout: post
title: "Threading in python"
date: 2024-01-19
desc: "A beginner-friendly guide to threading in Python. Understand how to run multiple threads, manage concurrency, and improve program performance with practical examples."
tags: [python, threading, concurrency, multithreading, tutorial]
---

Python's `threading` module is a powerful tool for running tasks concurrently, especially when dealing with I/O-bound operations. However, it comes with certain nuances—particularly the **Global Interpreter Lock (GIL)**—that every developer should understand.

This guide consolidates essential notes, examples, and tricks for working with threads in Python.

---

## 1. Understanding Threads in Python

Threads in Python are **lightweight processes** managed by the operating system. When a program spawns a thread, it hands control over to the OS to execute it.

### Key Points:
- **Global and Local Variables in Threads**
  - Global variables can be accessed from any thread.
  - To modify a global variable inside a thread, declare it with the `global` keyword; otherwise, Python treats it as a local variable.
- **Target Functions**
  - A callable function can be passed to a thread's `target` parameter.
  - The `run()` method is the default execution method of a thread. Overriding it allows custom thread behavior.

---

## 2. The GIL (Global Interpreter Lock)

### In CPython:
- The GIL ensures that only **one thread executes Python bytecode at a time**.
- **Implication**: True parallelism is not achieved for CPU-bound tasks, but I/O-bound operations still benefit from threading.
- Benefit: Reduced risk of data corruption without locks (since threads don’t truly run at the exact same time in CPU-bound tasks).
- Drawback: No real CPU-level parallelism for computational tasks.

### In Other Implementations:
- **Jython** (Java-based Python) and some others do not have a GIL, achieving true parallelism.
- **PyPy** is a faster implementation but still has a GIL.

---

## 3. When to Use Threading
- Ideal for **I/O-bound tasks** (e.g., network calls, file I/O).
- Not suitable for CPU-heavy computation—use `multiprocessing` for those.

---

## 4. How `threading` Works

The `threading.Thread` class handles thread creation and management.

- **Constructor (`__init__`)**:
  - Accepts a callable via `target`.
  - `args` can be used to pass parameters to the callable.
- **`start()` method**:
  - Invokes the `run()` method in a new thread.
- **Overriding `run()`**:
  - Lets you define custom behavior for the thread.
- **Access to Global Namespace**:
  - Threads share the main namespace, so functions/variables from the main thread are accessible.

---

## 5. Thread Creation Methods

### **Method 1**: Using `target` with a function
```python
import threading

def thread_fun(value):
    print("Thread called with value:", value)

t1 = threading.Thread(target=thread_fun, args=(123,))
t1.start()
```

---

### **Method 2**: Inheriting `Thread` and Overriding `run()`
```python
import threading

class MyThread(threading.Thread):
    def run(self):
        result = 1 + 1
        print("Running custom logic. Result:", result)

t1 = MyThread()
t1.start()
```

---

### **Method 3**: Overriding both `__init__` and `run()`
```python
import threading

class MyThread(threading.Thread):
    def __init__(self, value):
        super().__init__()
        self.value = value
    
    def run(self):
        print("Value passed to thread:", self.value)

t1 = MyThread(1234)
t1.start()
```

---

## 6. Useful Threading Patterns & Tricks

### **Thread Pooling with a List**
```python
import threading

def worker():
    print("Working...")

threads = []
for _ in range(5):
    t = threading.Thread(target=worker)
    t.start()
    threads.append(t)

for t in threads:
    t.join()
```

---

### **Thread Synchronization with Locks**
When multiple threads modify a shared resource, **use locks** to prevent race conditions.
```python
import threading

lock = threading.Lock()
shared_value = 0

def increment():
    global shared_value
    with lock:
        shared_value += 1

threads = [threading.Thread(target=increment) for _ in range(10)]
for t in threads: t.start()
for t in threads: t.join()

print("Final value:", shared_value)
```

---

### **Using Events for Coordination**
```python
import threading
import time

event = threading.Event()

def waiter():
    print("Waiting for event...")
    event.wait()
    print("Event received!")

t = threading.Thread(target=waiter)
t.start()

time.sleep(2)
event.set()
```

---

### **Alarm Thread Example**
```python
import os, time, threading

class Alarm(threading.Thread):
    def __init__(self, timeout):
        super().__init__()
        self.timeout = timeout

    def run(self):
        time.sleep(self.timeout)
        os._exit(0)  # Force exit

alarm = Alarm(4)
alarm.start()

time.sleep(3)
print("Main process still running...")
```

---

## 7. Threading vs Multiprocessing

| Feature            | Threading                      | Multiprocessing                  |
|--------------------|--------------------------------|-----------------------------------|
| **Parallelism**    | Limited by GIL in CPython       | True parallelism                  |
| **Best for**       | I/O-bound tasks                 | CPU-bound tasks                   |
| **Memory Usage**   | Lightweight                     | Heavier (separate processes)      |
| **Communication**  | Shared memory (care with locks) | IPC mechanisms (queues, pipes)    |

---

## 8. Final Tips
- Use `threading` for **network I/O, file I/O, and waiting tasks**.
- Use `multiprocessing` for **number crunching and CPU-intensive tasks**.
- Always remember: **`start()`** runs the thread, **`run()`** contains the logic, and **`join()`** waits for completion.
- Avoid unnecessary complexity—keep threaded code simple to prevent hard-to-debug issues.

---

**References:**
- Python Docs: [threading](https://docs.python.org/3/library/threading.html)
- Python Docs: [multiprocessing](https://docs.python.org/3/library/multiprocessing.html)
