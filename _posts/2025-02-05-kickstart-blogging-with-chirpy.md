---
layout: post  
title: Kickstart Blogging with Chirpy
date: 2025-02-05
categories: ['blog','chirpy-guide']
tags: ['jekyll','chirpy-guide']
image:
  path: assets/images/covers/chirpy_2.jpg
  alt: Kickstart Blogging with Chirpy
---

- [How Chirpy Is Structured: Starter Project + Core Theme](#how-chirpy-is-structured-starter-project--core-theme)
- [Getting Started with the chirpy starter and Deploying Using GitHub Actions](#getting-started-with-the-chirpy-starter-and-deploying-using-github-actions)
- [Styling and Typography Tips to Improve Your Blog](#styling-and-typography-tips-to-improve-your-blog)
  - [Basic Markdown Elements (Standard)](#basic-markdown-elements-standard)
  - [Advanced Styling and Syntax with Markdown, Kramdown, and Chirpy](#advanced-styling-and-syntax-with-markdown-kramdown-and-chirpy)
    - [Code blocks](#code-blocks)
      - <details>
        <summary>Click to expand</summary>
        <div markdown="1">
      
        - [Specifying Language inside code block](#specifying-language-inside-code-block)
        - [Remove Line Number inside Code Block](#remove-line-number-inside-code-block)
        - [Specifying the Filename or Text in Code Block](#specifying-the-filename-or-text-in-code-block)
        - [Liquid Codes](#liquid-codes)
        
        </div>  
        </details>

    - [Creating Expand/Collapse Sections with Markdown](#creating-expandcollapse-sections-with-markdown)
    - [Attribute Lists](#attribute-lists)
    - [Highlight Blocks or Prompt Boxes (Chirpy-Specific)](#highlight-blocks-or-prompt-boxes-chirpy-specific)
    - [Listing](#lists)
    - [Working with Images](#working-with-images)
      - <details>
        <summary>Click to expand</summary>
        <div markdown="1">
      
        - [Default (with caption)](#default-with-caption)
        - [Left aligned](#left-aligned)
        - [Float to left](#float-to-left)
        - [Float to right](#float-to-right)

        </div>
        </details>
    - [Adding Videos](#adding-videos)
      - [Social Media Platform](#social-media-platform)
      - [Video Files](#video-files)
    - [Audios](#audios)
    - [Linking url and sections in Jekyll](#linking-url-and-sections-in-jekyll)
      - <details>
        <summary>Click to expand</summary>
        <div markdown="1">
      
        - [Linking direct urls](#linking-direct-urls)
        - [Linking sections and url dynamically](#linking-sections-urls-dynamically)
        - [Linking sections in same file](#linking-sections-samefile)

        </div>
        </details>
    - [Bonus: Manually add a custom anchor](#bonus-manually-add-custom-anchor-if-heading-is-weird)
      - [Weird heading](#weird-heading)
      - [Linking to a Non-Heading](#non-heading)

- [Special thanks to **Cotes** and all the contributors](#inspiration)
  - <details>
    <summary>Click to expand</summary>
    <div markdown="1">
  
    - [Text and Typography](https://chirpy.cotes.page/posts/text-and-typography/)
    - [Getting Started](https://chirpy.cotes.page/posts/getting-started/)
    - [Write a New Post](https://chirpy.cotes.page/posts/write-a-new-post/)
    - [Customize the Favicon](https://chirpy.cotes.page/posts/customize-the-favicon/)

    </div>
    </details>



## How Chirpy Is Structured: Starter Project + Core Theme
{: data-toc-skip='' .mt-0.mb-0 }

>Chirpy is a modern, feature-rich Jekyll theme designed for blogging and documentation. It’s split into **two main repositories** that work together seamlessly:  `chirpy-starter` and `jekyll-theme-chirpy` 
{: .prompt-info}

---

### 🔸 [The Core Theme — `jekyll-theme-chirpy`](https://github.com/cotes2020/jekyll-theme-chirpy/tree/master)

This is the **core theme repository**, which contains all the actual theme logic data and assets:

- Layouts (`_layouts/`)
- Includes (`_includes/`)
- Styles and scripts (`assets/`)
- Page templates
- Core logic of the Chirpy theme
- Config defaults and helper functions

**Internal Structure of Chirpy Core Theme**. 
Inside `jekyll-theme-chirpy`, you’ll find:

```bash
Folder/File     Purpose  

`_layouts/`     HTML templates defining page structure (default, post, page, home, categories, etc.)  
`_includes/`    Reusable components (headers, footers, sidebar widgets, post metadata)  
`_sass/`        Sass partials and variables for styling  
`assets/`       Static files: CSS, JS, images, fonts  
`_data/`        YAML data files for menus, socials, assets config  
`_config.yml`   Default theme config, overwritten by starter’s config  
```

### 🔹 [Starter Project -- **`chirpy-starter`**](https://github.com/cotes2020/chirpy-starter)

This is the **starter project** — a ready-to-use Jekyll site with Chirpy already configured.
>This is usually the best way to go for almost all of your work.
{: .prompt-tip}

It includes:

- Example posts
- `Gemfile` with theme dependency
- `_config.yml` with pre-set configurations
- GitHub Actions workflow for Pages deployment (`.github/workflows/pages-deploy.yml`)
- A folder structure suitable for customization and development

This acts as a **boilerplate blueprint** to help you kick off a new blog quickly and efficiently.

####  Key Features

- **Integrated Theme Setup**:  
  The `Gemfile` already includes the `jekyll-theme-chirpy` gem. Running `bundle install` will fetch and install the core theme.

- **Pre-configured Deployment Workflow**:  
  The GitHub Actions workflow (`pages-deploy.yml`) is already set up. No manual deployment script is needed — just push and publish!

- **Theme Included via `_config.yml`**:  
  The `_config.yml` file already references the core theme and provides all necessary flags and options you can easily customize.

- **Customizable via Overrides**:  
  You can override any core theme file by creating your own versions in:
  
  - `_data/` — override default site data (e.g., navigation, authors)
  - `_layouts/` — override layout templates
  - `_includes/`, `assets/`, and other folders as needed

> You don’t see these theme files (except limited files in `_data/` and `assets/`) directly in the starter repo because they’re loaded from the theme gem (`jekyll-theme-chirpy`). But they are overrideable. and also can containyou custome files and folders as well
- example the `assets/` can have `assets/my_asset_files_or_folders/filessscd.png`
{: .prompt-tip}

---


####  How It Works

When you use the starter repo and run `bundle install`, the core theme is installed and pulled into your project. It is referenced in your `_config.yml` and `Gemfile` like this (this is already provided no need to do anytng):

```
gem "jekyll-theme-chirpy", "~> 7.3", ">= 7.3.1"
```
{: file="Gemfile"}

```yaml
theme: jekyll-theme-chirpy

```
{: file="_config.yml"}

This tells Jekyll to use theme’s layouts (installed in this case), includes, CSS, and other assets from the core repo at build time.

The starter project then adds:

Site-specific content: posts, pages, custom config, and data files.

Customization or overrides: any local files in _layouts, _includes, or assets in the starter repo override those from the theme.

>**Note:** You can use the following to pull the remote theme directly from the GitHub repo:
>However, this is **not required** and generally **not advised**.  
>Stick to the [**boilerplate method** (`chirpy-starter`)](https://chirpy.cotes.page/posts/getting-started/#option-1-using-the-starter-recommended), which is simpler, more reliable, and comes **pre-configured** without any compromises.
>
>```yaml
>remote_theme: jekyll-theme-chirpy
>
>```
>{: file="_config.yml"}
{: .prompt-warning}

## Getting Started with the chirpy starter and Deploying Using GitHub Actions

- [Follow this link for **Getting Started**, click](https://chirpy.cotes.page/posts/getting-started/#option-1-using-the-starter-recommended)

- [Deployment using **GitHub Actions** , click](https://chirpy.cotes.page/posts/getting-started/#deploy-using-github-actions)

## **Styling and Typography Tips to Improve Your Blog**
Chirpy supports all standard Markdown syntax and provides additional typographic enhancements to make your content more readable, highlighted, and visually appealing.


## Basic Markdown Elements (Standard)

These are universal Markdown features, and they work out of the box with **Chirpy**.

**Feature** | **Markdown Syntax** | **Rendered Output in Chirpy**
------------|---------------------|-------------------------------
Heading | `#` to `######` | Section titles (h1–h6)
Bold | `**bold**` | **bold**
Italic | `*italic*` or | *italic*
Bold Italic | `***text***` | ***text***
Inline Code | `` `code` `` | `code`
Blockquote | `> This is a quote` | Styled blockquote
Lists | `- Item` or `1. Item` or `* Item` | Bulleted or numbered list
Horizontal Line | `---`, `***`, or `___` | Divider line (horizontal rule)
Links | `[OpenAI](https://openai.com)` | OpenAI
Images | `![alt text](image_url)` | Embedded image

***Block Quote***
```
> This line shows the _block quote_.
```
> This line shows the _block quote_.

## **Advanced Styling and Syntax with Markdown, Kramdown, and Chirpy**

---

### **Code blocks**

Markdown symbols ```` ``` ```` can easily create a code block as follows:

````md
```
This is a plaintext code snippet.
```
````
#### Specifying Language inside code block

Using ```` ```{language} ``` ```` you will get a code block with syntax highlight:

````markdown

```python
print("hello")

```
```yaml
key: value
```
```shell
ls -al ,or any text you like
```
````
---

>use    ````markdown  to wrape the code blocks to display the raw blocks itself
{: .prompt-tip}

The above are code blocks produces similar output as below

```python
print("hello")

```

#### remove Line Number inside code block

By default, all languages except `plaintext`, `console`, and `terminal` will display line numbers. When you want to hide the line number of a code block, add the class `nolineno` to it:

````markdown
```shell
echo 'No more line numbers!'
```
{: .nolineno }
````

#### Specifying the Filename or text in code block

You may have noticed that the code language will be displayed at the top of the code block. If you want to replace it with the file name, you can add the attribute `file` to achieve this:

````markdown
```shell
# content
```
{: file="path/to/file" }
````
output:
```shell
# content
```
{: file="path/to/file" }

#### Liquid Codes
In **Chirpy**, which is built on **Jekyll**, *Liquid code* refers to the use of the **Liquid templating language**, used to process dynamic content inside `.html`, `.md`, and `.yml` files.

It uses a syntax like:

{% raw %}
```liquid
{{ variable }}            → output content
{% tag %}                 → logic or commands (e.g., if, for, include)
{% if page.author %}
  Author: {{ page.author }}
{% endif %}
```
{% endraw %}

If you want to display the **Liquid** snippet, surround the liquid code with `{% raw %}` and `{% endraw %}`:

````markdown
{% raw %}
```liquid
{% if product.title contains 'Pack' %}
  This product's title contains the word Pack.
{% endif %}
```
{% endraw %}
````
---
### **Creating Expand/Collapse Sections with Markdown**
You can use the `<details>` and `<summary>` tags to create expandable sections.
>If want to renderd markdown formats like list ,codeblocks etc use the `<div>` or `<article>` tags inside `<summary>` to wrape the content. all examples shown below. 
{: .prompt-info}

**Normal text Expand/Collapse syntax** 

```markdown
<details>
  <summary>Click to expand plain summary</summary>
  This is a normal summary to create expandable blocks
  if doesnot supports markdown special formats like list or code blocks
</details>
```
*Example*
<details>
  <summary>Click to expand plain summary</summary>
  This is a normal summary to create expandable blocks
  if doesnot supports markdown special formats like list or code blocks
</details>


**Expand/Collapse syntax with markdown formatting**

````markdown
<details>
  <summary>Click to expand markdown formatting</summary>

  <div markdown="1">

  - List item 1  
  - List item 2

  ```python
    print("Hello, world!")
  ```
  </div> 
</details>

````

*Example*

<details>
  <summary>Click to expand markdown formatting</summary>

  <div markdown="1">

  - List item 1  
  - List item 2

  ```python
    print("Hello, world!")
  ```
  </div> 
</details>


>- Note: `<div markdown="1">` can be replaced with `<article markdown="1">` as well 
>- You can put Expand/Collapse block at any level and can make it a part of a list as well
{: .prompt-tip}

### **Attribute Lists**

You can add attributes like CSS classes, IDs, or `data-` attributes to elements using `{}`:

```markdown
## This Won’t Show in the TOC
{: data-toc-skip="" .mt-4 .mb-0 }

# H1 — heading
{: .mt-4 .mb-0 }

## H2 — heading
{: data-toc-skip='' .mt-4 .mb-0 }

### H3 — heading
{: data-toc-skip='' .mt-4 .mb-0 }

#### H4 — heading
{: data-toc-skip='' .mt-4 }

```

| Attribute       | Effect                                             |
|-----------------|----------------------------------------------------|
| `data-toc-skip` | (optional) Skips this heading from the sidebar TOC           |
| `.mt-4`         | (optional) Adds top margin (Chirpy spacing class)            |
| `.mb-0`         | (optional) Removes bottom margin                             |


### **Highlight Blocks or prompt boxes (Chirpy-Specific)**
Chirpy supports custom prompt boxes using Kramdown attribute classes .These are custome defined.

**note here and char `>` (blockquote) is nedded for the .prompt-* to work**
>Chirpy does support **blockquotes** styled as prompts by using the **prompt-{type} CSS class—specifically** for ``tip, info, warning``, and `danger`

```markdown
> **info** This is a info remember
{: .prompt-info }

> **Tip:** Always use version control!
{: .prompt-tip }

> **Warning:** Don’t push secrets to GitHub.
{: .prompt-warning }

> **Danger:** This will delete all your data.
{: .prompt-danger }

```
**The above are translated in to:**

> **info** This is a info remember
{: .prompt-info }

> **Tip:** Always use version control!
{: .prompt-tip }

> **Warning:** Don’t push secrets to GitHub.
{: .prompt-warning }

> **Danger:** This will delete all your data.
{: .prompt-danger }

### **Lists**

***Ordered list***
```
1. Firstly
2. Secondly
3. Thirdly

```
1. Firstly
2. Secondly
3. Thirdly

***Unordered list***
```
- Chapter
  - Section
    - Paragraph
```
- Chapter
  - Section
    - Paragraph

***ToDo list***
```
- [ ] Job
  - [x] Step 1
  - [x] Step 2
  - [ ] Step 3
```
- [ ] Job
  - [x] Step 1
  - [x] Step 2
  - [ ] Step 3

***Description list***
```
Sun
: the star around which the earth orbits

Moon
: the natural satellite of the earth, visible by reflected light from the sun
```
---

## **Working with Images**

[For working with image covers click here]({{ site.posts | where: "slug", "chirpy-jekyll-front-matter" | first.url | relative_url }}#bonus-full-image-block-in-front-matter)

Images in Chirpy can be embedded using standard Markdown syntax, but Chirpy also provides additional **CSS utility classes** and attributes to fine-tune how images are displayed.

These can be applied using **attribute lists** `{}` directly after the image syntax.
like `{: width="972" height="589" .w-75 .normal }`

**Basic Usage**

```markdown
![Alt Text](path/to/image.ext){: width="972" height="589" .w-75 .normal }

### Default (with caption)

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" }
_Full screen width and center alignment this is caption_

### Left aligned

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" .w-75 .normal}

### Float to left

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" .w-50 .left}

### Float to right

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" .w-50 .right}
```

***Parts Explained***

| Part             | Meaning                                                                 |
|------------------|-------------------------------------------------------------------------|
| `width="972"`    | Sets the explicit width of the image in **pixels**                      |
| `height="589"`   | Sets the explicit height of the image in **pixels**                     |
| `.w-50`          | Applies **Chirpy’s utility class** to set width to **50%** of container |
| `.left`          | Floats the image **left** using Chirpy’s utility class                  |

---
#### Default (with caption)
```
![Alt Text](path/to/image.ext){: width="972" height="589" }
full captino
```

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" }
_Full screen width and center alignment this is caption_

#### Left aligned
`![Alt Text](path/to/image.ext){: width="972" height="589" .w-75 .normal}`
![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" .w-75 .normal}

#### Float to left
`![Alt Text](path/to/image.ext){: width="972" height="589" .w-50 .left}`

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" .w-50 .left}
This helps the image float to the **left side** while allowing text to wrap around it, creating visually engaging layouts.

For example:

- Place **diagrams**, **charts**, or **screenshots** on one side  
- Perfect for **tutorials** and **documentation**

Chirpy’s utility classes like `.left` and `.w-50`:

- Control **alignment and sizing** easily  
- Remove the need for custom CSS  
- Keep content clean and **user-friendly**

This improves readability and makes posts more polished using simple Markdown and Chirpy’s utilities.

#### Float to right
`![Alt Text](path/to/image.ext){: width="972" height="589" .w-50 .right}`

![Desktop View](assets/images/snaps/chirpy_tution/flying_chirpy.avif){: width="972" height="589" .w-50 .right}
This helps the image float to the **right side** while allowing text to wrap around it, creating a balanced and dynamic layout.
You can mix paragraphs and bullet points seamlessly around floated images to enhance clarity and flow.
This improves readability and makes posts more polished using simple Markdown and Chirpy’s utilities.

For example:

- Place **diagrams**, **charts**, or **screenshots** on one side  
- Perfect for **tutorials** and **documentation**

Chirpy’s utility classes like `.right` and `.w-50`:

- Control **alignment and sizing** easily  
- Remove the need for custom CSS  
- Keep content clean and **user-friendly**

---

## **Adding Videos**
There are predefined layouts for rendering video files which are present in the `_includes/embed/`  in the core-theme
we can use those to render videos from social media and 

| File / Folder                      | Purpose                                                |
|------------------------------------|--------------------------------------------------------|
| `_includes/embed/youtube.html`     | Embeds YouTube videos using their video ID             |
| `_includes/embed/twitch.html`      | Embeds Twitch videos using their video ID              |
| `_includes/embed/bilibili.html`    | Embeds Bilibili videos using their video ID            |
| `_includes/embed/video.html`       | Embeds self-hosted video files with advanced options   |
| `_includes/embed/audio.html`       | Embeds audio files (e.g., MP3) with metadata support   |

#### Social Media Platform

You can embed videos from social media platforms with the following syntax:

{% raw %}
```liquid
{% include embed/{Platform}.html id='{ID}' %}
```
{% endraw %}

Where `Platform` is the lowercase of the platform name, and `ID` is the video ID.

The following table shows how to get the two parameters we need in a given video URL, and you can also know the currently supported video platforms.

| Video URL                                                                                          | Platform   | ID             |
| -------------------------------------------------------------------------------------------------- | ---------- | :------------- |
| [https://www.**youtube**.com/watch?v=**H-B46URT4mg**](https://www.youtube.com/watch?v=H-B46URT4mg) | `youtube`  | `H-B46URT4mg`  |
| [https://www.**twitch**.tv/videos/**1634779211**](https://www.twitch.tv/videos/1634779211)         | `twitch`   | `1634779211`   |
| [https://www.**bilibili**.com/video/**BV1Q44y1B7Wf**](https://www.bilibili.com/video/BV1Q44y1B7Wf) | `bilibili` | `BV1Q44y1B7Wf` |

#### Video Files

If you want to embed a video file directly, use the following syntax:

{% raw %}
```liquid
{% include embed/video.html src='{URL}' %}
```
{% endraw %}

Where `URL` is a URL to a video file e.g. `/path/to/sample/video.mp4`.

You can also specify additional attributes for the embedded video file. Here is a full list of attributes allowed.

- `poster='/path/to/poster.png'` — poster image for a video that is shown while video is downloading
- `title='Text'` — title for a video that appears below the video and looks same as for images
- `autoplay=true` — video automatically begins to play back as soon as it can
- `loop=true` — automatically seek back to the start upon reaching the end of the video
- `muted=true` — audio will be initially silenced
- `types` — specify the extensions of additional video formats separated by `|`. Ensure these files exist in the same directory as your primary video file.

Consider an example using all of the above:

{% raw %}
```liquid
{%
  include embed/video.html
  src='/path/to/video.mp4'
  types='ogg|mov'
  poster='poster.png'
  title='Demo video'
  autoplay=true
  loop=true
  muted=true
%}
```
{% endraw %}

---

## **Audios**
there is a predefined audio template that renders ours audio 

| File / Folder                      | Purpose                                                |
|------------------------------------|--------------------------------------------------------|
| `_includes/embed/audio.html`       | Embeds audio files (e.g., MP3) with metadata support   |

If you want to embed an audio file directly, use the following syntax:

{% raw %}
```liquid
{% include embed/audio.html src='{URL}' %}
```
{% endraw %}

Where `URL` is a URL to an audio file e.g. `/path/to/audio.mp3`.

You can also specify additional attributes for the embedded audio file. Here is a full list of attributes allowed.

- `title='Text'` — title for an audio that appears below the audio and looks same as for images
- `types` — specify the extensions of additional audio formats separated by `|`. Ensure these files exist in the same directory as your primary audio file.

Consider an example using all of the above:

{% raw %}
```liquid
{%
  include embed/audio.html
  src='/path/to/audio.mp3'
  types='ogg|wav|aac'
  title='Demo audio'
%}
```
{% endraw %}

---

## **Linking url and sections in Jekyll**

<span id="linking-sections-samefile"></span>
**Linking sections in same file**

```markdown
[any text name to show](#section-name-separated-by-hypen-all-in-small) 
```
or any special name is forced ::-  check -- [Bonus: Manually add a custom anchor](#bonus-manually-add-custom-anchor-if-heading-is-weird)

<span id="linking-sections-urls-dynamically"></span>
**Linking sections and url dynamically from other files**
{% raw %}
```markdown
# POST URL (different)
[any name you like]({{ site.posts | where: "slug", "typing-in-python" | first.url | relative_url }})  # {{}} <--  this is a liquid language used by jekyll templeting engine

# POST URL SECTIONS (different)
[Go to Installation]({{ site.posts | where: "slug", "my-post" | first.url | relative_url }}#installation)

```
{% endraw %}

> Note : you can force a `slug` to the [front matter]({{ site.posts | where: "slug", "chirpy-jekyll-front-matter" | first.url | relative_url }}) like this 
>```markdown
>---
>title: My Post
>slug: my-post
>---
>```
{: .prompt-tip}

**Breakdown of Each Part (Additional Explanation)**

> `|` is called a filter pipe
> It takes the output of the left-hand side and passes it through a filter on the right-hand side.
> just like unix pipe

1. `site.posts`  
Built-in Jekyll variable containing all posts in `_posts/`.
- 🔹 Example:
  ```json
  [
    { "title": "Post A", "slug": "post-a", "url": "/blog/2023/06/01/post-a/" },
    { "title": "Post B", "slug": "chirpy-jekyll-front-matter", "url": "/blog/2023/06/25/chirpy-jekyll-front-matter/" }
  ]
  ```

2. `| where: "slug", "chirpy-jekyll-front-matter"`  
Filters posts by `slug` value.
  - 🔹 Result:
  ```json
  [
    { "title": "...", "slug": "chirpy-jekyll-front-matter", "url": "/blog/2023/06/25/chirpy-jekyll-front-matter/" }
  ]
  ```

3. `| first`  
Gets the first (and likely only) matching post.

4. `.url`  
Extracts the URL of that post.  
- 🔹 Example: `/blog/2023/06/25/chirpy-jekyll-front-matter/`

5. `| relative_url`  
Prepends `baseurl` if set in `_config.yml`.

🧾 Final Output Example
With:
- A post slug: `chirpy-jekyll-front-matter`  
- `baseurl: ""`  

This line:
```liquid
{{ site.posts | where: "slug", "chirpy-jekyll-front-matter" | first.url | relative_url }}
```
➡️ renders as:  
`/blog/2023/06/25/chirpy-jekyll-front-matter/`

<span id="linking-direct-urls"></span>
**Linking direct urls**

```markdown
[any name like click me](https://www.myurl.com)
```

## **Bonus: Manually add a custom anchor** {#bonus-manually-add-custom-anchor-if-heading-is-weird}

<span id="weird-heading"></span>
**weird heading**
>Note you can anchor all the headings exactly the same way. This applies to headings of any level — `#`, `##`, `###`, etc.When you write this in Markdown `# Some Heading` Jekyll (via Kramdown) automatically turns it into `<h1 id="some-heading">Some Heading</h1>`,the tag `<h1>` or `<h2>` etc depends on the level
{: .prompt-info}

If your heading is like `## Step 1: Setup 🚀`: It might produce a messy ID.
So you can force an ID like this `## Step 1: Setup 🚀 {#setup}`:

examples::
```markdown
## Step 1: Setup 🚀 {#setup}
```
Then link to:
```markdown
[some name]({{ site.posts | where: "slug", "my-post" | first.url | relative_url }}#setup)
```

<span id="non-heading"></span>
**Linking to a Non-Heading**

You’ll need to manually insert an HTML ID like:

```md
<span id="my-anchor"></span>
Some **custom** section here.

Then link with:

[Jump here](#my-anchor)
```
---

Please follow the link to learn more about writing a blog from the official site:  
[Write a New Post – Chirpy Official Guide](https://chirpy.cotes.page/posts/write-a-new-post/)

---

## Inspiration

The **Chirpy theme** has been an incredible foundation for building this blog. Huge appreciation to **Cotes** and the open-source contributors behind [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) for their continuous work on making Jekyll blogging modern, minimal, and developer-friendly.

My blog setup, layout decisions, and customizations were strongly influenced by their excellent documentation and examples, including:

- [Text and Typography](https://chirpy.cotes.page/posts/text-and-typography/)
- [Getting Started](https://chirpy.cotes.page/posts/getting-started/)
- [Write a New Post](https://chirpy.cotes.page/posts/write-a-new-post/)
- [Customize the Favicon](https://chirpy.cotes.page/posts/customize-the-favicon/)

Thanks to their efforts, creating a beautiful and functional static blog has never been easier.
