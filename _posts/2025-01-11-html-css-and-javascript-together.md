---
layout: post  
title: "HTML, CSS, and JavaScript — A Practical Overview"
date: 2025-01-11
categories: ['Tutorial', 'Frontend']
tags: ['Html','css','js']
slug: html-css-and-javascript-overview
image:
  path: assets/images/covers/html-js-css-website-coding.jpg
  alt: A Practical Overview
---

<details>
  <summary><strong>Table of Contents</strong></summary>

  <div markdown="1">

  - [🧱 What is HTML?](#what-is-html)
    - [Common HTML Tags (Elements)](#common-html-tags-elements)
    - [Attributes in HTML](#attributes-in-html)

  - [🎨 CSS: Styling](#css-styling)
    - [Ways to Use CSS](#ways-to-use-css)
    - [CSS Selectors](#css-selectors)

  - [⚙️ What is JavaScript (JS)?](#js-javascript)
    - [What is the DOM?](#what-is-the-dom)
    - [How the DOM is Accessed](#dom-accessed)
    - [Common `document` Methods](#dom-method)

  - [🔄 How They All Connect](#how-they-all-connect)

  - [🔗 Linking relationship `<link rel=...>` in HTML](#link-ref)
    - [Is `<link rel="stylesheet" href="style.css" />` Needed?](#link-ref-needed)
    - [Is `<link>` Only for CSS?](#link-ref-css)

  </div>
</details>

## 🧱 What is HTML?  {#what-is-html}
🔹 HTML = HyperText Markup Language

HTML is the skeleton of a web page. It defines the structure and content—what elements appear on the page like text, images, buttons, links, etc.
An HTML page is entirely made of:

- **HTML Tags (elements)** → like `<div>`, `<h1>`, `<a>`, etc.
- **Attributes** → like `class`, `id`, `href`, `src`, etc.
- **Text or content** inside the tags

Basic Structure of HTML

```html
<!DOCTYPE html>
<html>
  <head>
    <title>My First Page</title>
  </head>
  <body>
    <h1>Hello, World!</h1>
    <p>This is a paragraph.</p>
  </body>
</html>
```
**Explanation**:

- `<!DOCTYPE html>` → Declares that this is an HTML5 document  
- `<html>` → Root of the HTML document  
- `<head>` → Metadata (not visible content), includes title, links to CSS/JS (optional but recommended)  
- `<title>` → Title shown in browser tab  
- `<body>` → Visible content of the webpage

**What is `<!DOCTYPE html>` and Why Should You Use It?**

- `<!DOCTYPE html>` is a declaration, **not** an HTML tag.It tells the browser the document is written in HTML5.  
- Ensures the browser uses **standards mode** (modern rendering) else **quirks mode** (legacy behavior).  
- Quirks mode can break layouts and CSS, especially box sizing so include `<!DOCTYPE html>` for consistent rendering.

### Common HTML Tags (Elements) {#common-html-tags-elements}

| Tag            | Description              | Example                          |
|----------------|--------------------------|---------------------------------|
| `<html>`       | Root element             | `<html></html>`                 |
| `<head>`       | Metadata (CSS, JS, title)| `<head></head>`                 |
| `<body>`       | Page content             | `<body></body>`                 |
| `<h1>` – `<h6>`| Headings                 | `<h1>Main Title</h1>`           |
| `<p>`          | Paragraph                | `<p>Hello world</p>`             |
| `<a>`          | Link                     | `<a href="https://google.com">Visit</a>` |
| `<img>`        | Image                    | `<img src="img.jpg" alt="desc" />` |
| `<ul>`, `<ol>`, `<li>` | Lists              | `<ul><li>Item</li></ul>`        |
| `<div>`        | Container/block          | `<div>Box</div>`                |
| `<span>`       | Inline text container    | `<span>Text</span>`             |
| `<input>`      | Input field              | `<input type="text" />`         |
| `<button>`     | Button                   | `<button>Click</button>`        |
| `<form>`       | Wraps inputs             | `<form>...</form>`              |
| `<script>`     | JS inside HTML           | `<script>code</script>`         |
| `<link>`       | Link CSS file (mostly)          | `<link rel="stylesheet" href="style.css" />` |


### Attributes in HTML

Attributes go inside tags to give extra information.

Example:

```html
<a href="https://openai.com" target="_blank">Visit OpenAI</a>
```

**Common Attributes**:

| Attribute                  | Description                            | Example                              |
|----------------------------|------------------------------------|------------------------------------|
| `class`                    | Used for styling (CSS), can be reused | `<div class="container">...</div>`  |
| `id`                       | Unique identifier (CSS or JS)         | `<h1 id="main-title">Title</h1>`    |
| `href`                     | URL in links                         | `<a href="https://openai.com">OpenAI</a>` |
| `src`                      | Source for images or scripts         | `<img src="image.jpg" alt="desc" />` |
| `alt`                      | Image description (SEO, accessibility) | `<img alt="Logo">`                   |
| `type`                     | Type of input or button              | `<input type="text" />`              |
| `value`                    | Pre-filled value (input/button)      | `<input value="Hello" />`            |
| `placeholder`              | Hint text in input                   | `<input placeholder="Enter name" />` |
| `onclick`, `onchange`      | Trigger JS functions                 | `<button onclick="alert('Hi!')">Click</button>` |
| `target`                   | How link opens (`_blank` = open new tab) | `<a href="url" target="_blank">Link</a>` |


## 🎨 CSS: Styling {#css-styling}

CSS changes how HTML looks.

<span id="ways-to-use-css"></span>
✅ Ways to Use CSS

>**External (best method)** ✅ Recommended
>```html
><link rel="stylesheet" href="style.css" />
>```
>
>**In `style.css`:**
>```css
>h1 {
>  font-size: 40px;
>  color: purple;
>}
>```
{: .prompt-tip}


>**Internal (inside `<style>` in `<head>`)**  ⚠️ May be recommended
>```html
><head>
>  <meta charset="UTF-8">
>  <title>Text Block Example</title>
>   <style>
>     p {
>       color: blue;
>     }
>   </style>
></head>
>```
{: .prompt-warning}


>**Inline (inside an HTML tag)** ❌ Not recommended  
>```html
><p style="color: red;">Red text</p>
>```
{: .prompt-danger}

### CSS Selectors

| Selector | Targets                        | Example Usage                                                  |
|----------|--------------------------------|----------------------------------------------------------------|
| `tag`    | All elements of that type      | `p { color: red; }` → All `<p>` tags turn red                 |
| `.class` | All elements with that class   | `.box { padding: 10px; }` → Elements with `class="box"` get padding |
| `#id`    | One element with that id       | `#hero { background: black; }` → The element with `id="hero"` has a black background |
| `div p`  | All `<p>` inside `<div>`       | `div p { font-size: 14px; }` → Only `<p>` tags inside `<div>` are affected |
| `*`      | Everything                     | `* { margin: 0; }` → Removes default margin from all elements  |


<details>
  <summary style="color: #228B22;"><strong>Common CSS Properties</strong></summary>
  
  <div markdown="1">

  | Property                          | Description                              |
  |----------------------------------|------------------------------------------|
  | `color`                          | Text color                               |
  | `background-color`               | Background color                         |
  | `font-size`, `font-family`       | Text size and font                       |
  | `margin`, `padding`              | Space outside/inside elements            |
  | `border`                         | Border style                             |
  | `width`, `height`                | Size of elements                         |
  | `display`                        | Layout behavior (`block`, `flex`, `grid`)|
  | `position`                       | Positioning method (`static`, `absolute`, etc.) |
  | `text-align`                     | Aligns text (`left`, `center`, etc.)     |
  | `justify-content`, `align-items`| Alignment in flexbox containers          |

  </div>
</details>

**Example**

```html
<div class="card" id="firstCard">Card Content</div>
```

```css
.card {
  background-color: #f3f3f3;
  padding: 20px;
  border: 1px solid gray;
}

#firstCard {
  border-color: red;
}
```
---
output:
<div class="card" id="firstCard">Card Content</div>

<style>
  .card {
  background-color: #f3f3f3;
  padding: 20px;
  border: 1px solid gray;
  }

  #firstCard {
    border-color: red;
  }
</style>

---


## ⚙️ What is JavaScript (JS)? {#js-javascript}

**JS = Programming language of the web**

- `HTML` → Structure  
- `CSS` → Style  
- `JS` → Behavior  

JavaScript makes the page interactive (buttons, animations, forms, etc.)

>It uses the `document` objec if any html document object needes to be interacted with else built in functions or custome functions
{: .prompt-info}

JS Example in html

```html
<button onclick="changeText()">Click Me</button>
<p id="demo">Hello</p>

<script>
  function changeText() {
    document.getElementById("demo").innerText = "You clicked!";
  }
</script>
```

When the button is clicked, JS changes the text of the paragraph.

<span id="ways-to-use-js"></span>
✅ Ways to Use JS


>**External (best practice)** ✅  
>```html
><script src="script.js"></script>
>```
>
>**In `script.js`:**
>```javascript
>function sayHi() {
>  alert("Hello from external file!");
>}
>```
>{: file="script.js"}
{: .prompt-tip}

>**Internal (inside `<script>` in HTML)** can be used if needed 
>```html
><script>
>  function sayHi() {
>    alert("Hello!");
>  }
></script>
>```
{: .prompt-warning}

>**Inline (bad practice) but can be done**  
>```html
><button onclick="alert('Hi')">Click</button>
>```
{: .prompt-danger}


### What is the DOM? {#what-is-the-dom}

🔹 **DOM = Document Object Model**

The DOM is a virtual representation of your HTML page that JavaScript can read and modify.

Think of it like this:  
- HTML is the code of the page.  
- The DOM is a live, tree-like structure created by the browser from that HTML.

🔸 **Example:**

**HTML:**
```html
<body>
  <h1>Hello</h1>
  <p>This is a paragraph</p>
</body>
```

**In the DOM, this becomes a tree like:**
```
<body>
 ├── <h1>Hello</h1>
 └── <p>This is a paragraph</p>
```

JavaScript uses the DOM to access, change, or create elements on your page.

<span id="dom-accessed"></span>
**How DOM is acceed:- via `document`** 

🔹 `document` = JavaScript's way of accessing the DOM

It’s a built-in object in JS that represents your entire web page.You use it to interact with HTML elements.

<span id="dom-method"></span>
🔸 **Common `document` Methods:**

| JS Method / Property                  | What It Does                         | Example / Source of Element                        |
|-------------------------------------|------------------------------------|---------------------------------------------------|
| `document.getElementById("id")`     | Gets one element by its id          | `const element = document.getElementById("header");` |
| `document.getElementsByClassName("class")` | Gets multiple elements with a class | `const element = document.getElementsByClassName("item")[0];` |
| `document.querySelector("selector")`| Gets the first element matching a selector | `const element = document.querySelector(".my-class");` |
| `document.querySelectorAll("selector")` | Gets all elements matching a selector | `const element = document.querySelectorAll(".card")[0];` |
| `document.createElement("tag")`     | Creates a new HTML element          | `const element = document.createElement("div");`  |
| `appendChild(element)`               | Adds the element to the DOM         | `document.body.appendChild(element);`              |
| `element.innerText`                  | Gets/sets text content of the element | `element.innerText = "Hello!";`                    |
| `element.innerHTML`                  | Gets/sets HTML content of the element | `element.innerHTML = "<b>Hi</b>";`                 |
| `element.setAttribute("attr", "value")` | Sets/updates an attribute on the element | `element.setAttribute("href", "https://example.com");` |
| `element.classList.add("class")`    | Adds a CSS class to the element     | `element.classList.add("active");`                  |
| `element.addEventListener("event", fn)` | Adds an event listener to the element | `element.addEventListener("click", handleClick);`  |


🔸 **Example:**
```html
<p id="greet">Hello</p>
```

```javascript
let p = document.getElementById("greet");
p.innerText = "Hi there!";
```

>Every HTML page loaded in a browser automatically gets a DOM.The browser reads your HTML, parses it, and builds the DOM.  

---


### 🔄 11. How They All Connect {#how-they-all-connect}

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Full Web Example</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <h1 class="heading">Welcome!</h1>
    <button onclick="sayHi()">Click me</button>

    <script src="script.js"></script>
  </body>
</html>
```

Then in `style.css`:

```css
.heading {
  color: green;
  font-size: 40px;
}
```

And in `script.js`:

```javascript
function sayHi() {
  alert("Hello from JavaScript!");
}
```

## Linking relationship `<link rel=` in HTML {#link-ref}

<span id="link-ref-needed"></span>
1. Is `<link rel="stylesheet" href="style.css" />` Needed?

**Yes, it’s required.**  
Without `rel="stylesheet"`, the browser **won’t apply the CSS**.

```html
<link rel="stylesheet" href="style.css" />

```
rel means relationship, telling the browser this is a CSS stylesheet or some other relationship

>Normaly `<link rel=stylesheet` is use often for css linking from local or remote
> Example:
>   * Google Fonts or Bootstrap:
>      ```html
>      <link href="https://fonts.googleapis.com/css2?family=Roboto&display=swap" rel="stylesheet" />
>      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" />
>      ``` 
>   * local
>       `<link href="/assets/css/style.css" rel="stylesheet" />`
{: .prompt-tip}

<span id="link-ref-css"></span>
2. Is `<link>` Only for CSS?

No, `<link>` can link other resources too:

| Usage   | Example                                                    | Description          |
|---------|------------------------------------------------------------|----------------------|
| CSS     | `<link rel="stylesheet" href="style.css">`                 | CSS stylesheet       |
| Favicon | `<link rel="icon" href="favicon.ico">`                      | Website icon         |
| Preload | `<link rel="preload" href="font.woff2" as="font" ...>`     | Load fonts/images early |
| Manifest| `<link rel="manifest" href="manifest.json">`                | Web app settings     |

3. Can You Include Multiple CSS/JS Files?

**Yes!** It’s common practice.

**CSS:**

```html
<link rel="stylesheet" href="reset.css" />
<link rel="stylesheet" href="layout.css" />
<link rel="stylesheet" href="theme.css" />
```

> CSS loads top to bottom, so later styles override earlier ones.

**Javascript:**

```html
<script src="utils.js"></script>
<script src="app.js"></script>
<script src="main.js"></script>
```

>JS loads top to bottom, so earlier scripts are available to later ones.
