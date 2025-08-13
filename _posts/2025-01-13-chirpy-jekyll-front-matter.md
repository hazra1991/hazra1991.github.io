---
layout: post  
title: Chirpy Front Matter Key Settings for Your Blog
date: 2025-01-13
categories: ['blog','chirpy-guide']
tags: ['jekyll','chirpy-guide']
image:
  path: assets/images/covers/chirpy.webp
  alt: Chirpy theme front matter key settings illustrated cover image
---

- [What Is Front Matter?](#what-is-front-matter)
- [Why Is Front Matter Important in Chirpy?](#why-is-front-matter-important-in-chirpy)
- [Required & Optional Front Matter in Chirpy](#required--optional-front-matter-in-chirpy)
- [Author Information](#author-information)
- [Now what are `layout:` in Jekyll & Chirpy?](#now-what-are-layout-in-jekyll--chirpy)
- [How to Use These Layouts](#how-to-use-these-layouts)
- [Do You Need `layout: post` in Chirpy?](#do-you-need-layout-post-in-chirpy)
- [Bonus full image Block in Front Matter](#bonus-full-image-block-in-front-matter)
- [Recommended: Responsive Image Styling in Chirpy](#recommended-responsive-image-styling-in-chirpy)
- [Default Behavior in Chirpy When `image:` Is Used](#default-behavior-in-chirpy-when-image-is-used)
- [Image Size & Responsiveness Defaults](#image-size--responsiveness-defaults)
- [Best Practice Minimal Setup](#best-practice-minimal-setup)
- [Bonus includes Folder in Chirpy](#bonus-includes-folder-in-chirpy)
- [Summary: Best Practices for Auto-Adjusting Images in Chirpy](#summary-best-practices-for-auto-adjusting-images-in-chirpy)
- [Special thanks to **Cotes** and all the contributors](#acknowledgements)
    - [Text and Typography](https://chirpy.cotes.page/posts/text-and-typography/)
    - [Getting Started](https://chirpy.cotes.page/posts/getting-started/)
    - [Write a New Post](https://chirpy.cotes.page/posts/write-a-new-post/)
    - [Customize the Favicon](https://chirpy.cotes.page/posts/customize-the-favicon/)


###  What Is Front Matter?

**Front Matter** is a special block of YAML at the very top of a Markdown or HTML file in Jekyll-based sites (like Chirpy). It is enclosed between triple dashes `---` and is used to define metadata and configuration for that specific file.

Chirpy — being a Jekyll theme — heavily relies on front matter to control how pages and posts are displayed, styled, and rendered.

### Why Is Front Matter Important in Chirpy?

Chirpy uses front matter to:

- Control page/post **layout**
- Define **titles**, **dates**, and **authors**
- Show or hide components like **Table of Contents** or **comments**
- Enable features like **syntax highlighting**, **math rendering**, **pinned posts**, etc.
- Provide metadata for **SEO** and **social sharing** (e.g. descriptions, images)

---

Here’s an example of front matter in a Chirpy .md file (for post or page anytng):

```yaml
---
layout: post   #  this is correct,but subjective will cover this for chirpy latter
title: "Understanding Type Hints in Python"
date: 2025-08-13
categories: [programming, python]
tags: [python, type-hints, tutorial]
author: alex
image:
  path: /assets/img/type-hints.png
  alt: Type Hints Diagram
desc: "An easy guide to Python type hints and code quality."
toc: true
comments: true
pin: false
math: false
---
```
{: file="my_blog_front_matter.md"}


> Not all Front Matter is created equal.  
> Here's a breakdown of what's required — and what’s just nice to have.
{: .prompt-info}
---

###  Required & Optional Front Matter in Chirpy

Let’s break down what each Front Matter field does and whether it’s **required** or **optional** in Chirpy:

| Key       | Required? | Description                                                                 |
|-----------|-----------|-----------------------------------------------------------------------------|
| `title`   | ✅ Yes     | The title of the post. Appears in headers, SEO meta, and browser tabs.     |
| `date`    | ✅ Yes     | Sets the publication date and permalink (used in URLs). Format: `YYYY-MM-DD`. |
| `categories` | ⛔ Optional | Organizes posts into folders. Affects category pages and sidebar grouping. |
| `tags`    | ⛔ Optional | Helps with search and related post filtering. Not required, but useful.   |
| `author`  | ⛔ Optional | If present, shows author name in the post footer. Useful for multi-author blogs. |
| `image`   | ⛔ Optional | Used for post previews and social media cards.                            |
| `layout`  | ❌ Not needed | Chirpy auto-detects layout for posts in `_posts/`. Only needed for custom pages. |
| `desc`    | ⛔ Optional | Short description for meta tags and SEO. If missing, Chirpy auto-extracts from content. |
| `math`    | ⛔ Optional | Set to `true` to enable MathJax/KaTeX rendering.                         |
| `mermaid` | ⛔ Optional | Set to `true` to enable Mermaid diagrams.                                |
| `toc`     | ⛔ Optional | Enable/disable Table of Contents (`true` or `false`). Default is `true`. |
| `comments`| ⛔ Optional | Enable/disable comments for the post.                                    |
| `pin`     | ⛔ Optional | If `true`, post is pinned to top of the homepage.                        |

---

### 🛠️ Tips

- Keep `title` and `date` in every post — they’re essential for correct rendering and URLs.
- Use `categories` and `tags` for better organization and search.
- For a clean preview on social platforms, add an `image` and `desc`.

Need more customization options? Check out the [Chirpy documentation](https://chirpy.cotes.page/posts/write-a-new-post/) for advanced Front Matter usage.

### Author Information

The author information of the post usually does not need to be filled in the Front Matter, they will be obtained from variables `social.name` and the first entry of `social.links` of the configuration file by default. But you can also override it as follows:

>**Adding author information in `_data/authors.yml`**  
(If your website doesn’t have this file, don’t hesitate to create one).
{: .prompt-info}

```yaml
# -------------------------------------
# {author_id}:
#   name: {full name}
#   twitter: {twitter_of_author}
#   url: {homepage_of_author}
# -------------------------------------

# an example 
your_name:
  name: your_name sername
  twitter: your_twiter_id   # trye using linkedin or github
  url: https://github.com/your_id_username/  # try using any personal Url ID 
```
{: file="_data/authors.yml"}

And then use `author` to specify a single entry or `authors` to specify multiple entries:

```yaml
---
author: <author_id>                     # for single entry
# or
authors: [<author1_id>, <author2_id>]   # for multiple entries
---
```
Having said that, the key `author` can also identify multiple entries.

## Now what are `layout:` in Jekyll & Chirpy?

In Jekyll (and thus Chirpy), the layout: key in a page or post's front matter specifies which HTML layout template from the _layouts/ directory should be used to render that content.

* The layout file (e.g., post.html) acts as a wrapper or skeleton.

* Your Markdown content is injected into the layout where the bwlow is placed.
```markdown
{% raw %}{{ content }}{% endraw %}
```
{: .file="mypost.html"}

* This controls the overall structure, sidebar, header, footer, and styling.

> Note: whenever we have the front matter `layout: something`, Jekyll uses the `_layouts/` folder to find `_layouts/something.html` and wraps the Markdown content into it and then renders it. Basically, it uses that HTML file for the layouting the content of that Markdown file.
{: .prompt-tip}  

>**`layout:` in Chirpy**
- Chirpy uses several layout templates stored in the `_layouts/` folder.
- When you set `layout: something` in front matter, Jekyll uses `_layouts/something.html` to render the page.
- If you omit `layout:` in posts located under `_posts/`, Chirpy automatically uses `post.html` by default.
- For pages (e.g., in the root or `pages/` folder), you typically use `layout: page` or others as appropriate.
- some available layouts `post.html, page.html, home.html, categories.html, category.html, tags.html, tag.html, compressed.html`
{: .prompt-tip}

### How to Use These Layouts  
In your Markdown file’s front matter:

```yaml
---
layout: post       # Uses _layouts/post.html (default for blog posts)
title: "My Post"
date: 2025-08-13
---
```

or for a regular page:

```yaml
---
layout: page       # Uses _layouts/page.html for standalone pages
title: "About Me"
---
```

or for the homepage (if customized):

```yaml
---
layout: home       # Uses _layouts/home.html
---
```
another custome page:

```yaml
---
layout: mycutome_layout       # Uses _layouts/mycutome_layout.html
---
```

### Do You Need `layout: post` in Chirpy?

**Short answer:** No, not usually.

In **Chirpy**, the theme automatically assigns the correct layout for blog posts based on the file’s location (e.g., inside `_posts/`). So, unless you're doing something custom, you can safely omit:

```yaml
layout: post
```

---

⚠️ **Note:** In contrast, in plain **Jekyll** (without a theme like Chirpy), you typically **must specify** the layout so Jekyll knows how to render the file properly.

```yaml
layout: post
```

is required in standard Jekyll setups to apply the correct structure to your pages or posts.


## Bonus full image Block in Front Matter  
Example with most options and their Effects:

```yaml
image:
  path: /assets/img/type-hints.png           # Displays the image at the specified location in the post or page
  alt: Type Hints Diagram                    # Used for accessibility, SEO, and shown if image fails to load
  title: "Python Type Hints Flowchart"       # Shows a tooltip when users hover over the image
  caption: "Figure 1: Type hinting"          # Displays text below the image in a caption box
  link: https://exp.com/image.png            # Makes the image clickable to a larger or related version
  class: "rounded shadow-lg"                 # Adds custom CSS classes for styling (e.g., rounded corners, shadow)
  width: 600px                               # Controls the image’s width; useful for responsive design
  height: auto                               # Maintains aspect ratio or sets image height
  lazy: true                                 # Enables lazy loading to improve performance
```

Notes  
- If you only provide path and alt, Chirpy will handle sensible defaults for size and lazy loading.
- Adding caption is great for academic or tutorial-style posts with figures.
- Use link if you want readers to open a larger or original image version.
- class is useful for adding borders, shadows, or rounding via your CSS.

## Recommended: Responsive Image Styling in Chirpy

Option 1: Use `width: 100%` (Auto-adjust to container)

```yaml
image:
  path: /assets/img/your-image.png
  alt: Descriptive Alt Text
  width: 100%
```

This makes the image scale with the width of its container.

- Great for mobile responsiveness and dynamic layouts.
- You don’t need to set height — the browser will preserve the aspect ratio automatically.

---

Option 2: Add Custom CSS Classes via `class`

Chirpy allows you to apply custom CSS classes directly:

```yaml
image:
  path: /assets/img/example.png
  alt: Some Alt Text
  class: "img-fluid shadow rounded"
```

If you define these classes (or use Bootstrap or Tailwind-like ones), you get auto-resizing behavior:

- `img-fluid` = responsive image (scales to parent)
- `rounded` = rounded corners
- `shadow` = adds drop shadow

You can define these classes in your own custom stylesheet (`assets/css/style.scss`), like:

```scss
.img-fluid {
  max-width: 100%;
  height: auto;
}
```

---

Option 3: Inline Markdown or HTML for Full Control

If the front matter isn’t flexible enough for a specific case, write the image directly in the post using HTML:

```html
<img src="/assets/img/large-diagram.png" alt="Diagram" style="width:100%; height:auto;" />
```

Or in Markdown (less flexible, but simpler):

```markdown
![Alt Text](/assets/img/large-diagram.png)
```

---

🚫 Not Supported (As of Now)

- There is no built-in auto-scaling or compression setting in Chirpy’s front matter.
- Chirpy does **not** support setting image weight (file size) or responsive `srcset` formats directly.
- You’d need to handle image optimization **before uploading**, e.g. using tools like **TinyPNG** or an image CDN like **Cloudinary**.

---

Pro Tip: Use SVGs for Diagrams or Simple Graphics

SVGs:

- Scale automatically with perfect clarity
- Are usually lightweight
- Can be styled with CSS

Just reference them like this:

```yaml
image:
  path: /assets/img/my-graphic.svg
  alt: Vector diagram
  width: 100%
```

---

## Default Behavior in Chirpy When `image:` Is Used

If you add this:

```yaml
image:
  path: /assets/img/example.png
```

…and don’t provide anything else, here's what happens:

| Field    | Default Behavior                                                                 |
|----------|----------------------------------------------------------------------------------|
| `path`   | **Required.** If omitted, no image is rendered.                                 |
| `alt`    | Defaults to empty (`""`). Not shown visibly, but bad for SEO and accessibility. |
| `title`  | Not rendered. No tooltip is shown.                                              |
| `caption`| Not rendered. No visible caption below image.                                   |
| `link`   | Not wrapped in a clickable link.                                                |
| `width`  | No width attribute is added. The image renders at its natural width.            |
| `height` | No height attribute is added. Aspect ratio is preserved.                        |
| `class`  | No custom class is applied. Default browser or theme styles apply.              |
| `lazy`   | ✅ `true` by default (lazy loading is enabled unless you override it).           |

---

##  Image Size & Responsiveness Defaults

Without `width`, `height`, or `class`, the image will:

- Be rendered at its **original size** (intrinsic width)
- **Not** scale responsively
- **Not** exceed its container only if Chirpy’s post style limits image width (which it generally does via the post body wrapper)

So:

- **On desktop:** full-size images may overflow or look oversized.
- **On mobile:** browser might try to scale down, but not smoothly.

Example:

```yaml
image:
  path: /assets/img/big.png
```

---

## Best Practice Minimal Setup

If you just want it to work well and scale right:

```yaml
image:
  path: /assets/img/my-image.png
  alt: "Descriptive image"
  width: 100%
```

That will:

- Display the image **responsively**
- Provide `alt` text for SEO and accessibility
- Look good on **desktop and mobile**

## Summary: Best Practices for Auto-Adjusting Images in Chirpy

| Task                         | How to Do It                          |
|------------------------------|---------------------------------------|
| Auto-fit width               | `width: 100%` in front matter         |
| Preserve aspect ratio        | Use only `width`, let `height` be auto |
| Responsive image             | Add a custom class like `img-fluid`  |
| Add borders/shadow/styling  | Use `class:` with your CSS            |
| Full manual control          | Use `<img>` HTML directly in post     |

## Bonus includes Folder in Chirpy

The `_includes/` directory in Chirpy holds **reusable HTML snippets** used throughout the theme—including layout components, content blocks, widgets, and media embeds.

###  Purpose

You typically **don't need to override** these files—but knowing what's there helps if you intend to customize aspects such as video/audio embeds or sidebar behavior.

---

### Key Files in **`_includes/`**
```markdown
| File / Folder              | Purpose                                                |
|----------------------------|--------------------------------------------------------|
| `header.html`              | Sets up `<head>` section (meta tags, title, etc.)      |
| `footer.html`              | Defines the site’s footer                             |
| `sidebar.html`             | Renders the sidebar menu structure                     |
| `post-header.html`         | Renders the post’s header (title, date, categories)   |
| `post-content.html`        | Displays the main body of blog posts                   |
| `related-posts.html`       | Shows related posts at the end of a blog article       |
| `comments.html`            | Loads the chosen commenting system (e.g., Giscus)      |
| `analytics.html`           | Inserts analytics scripts (Google, Matomo, etc.)      |
| `toc.html`                 | Generates the Table of Contents for posts              |
| `embed/youtube.html`       | Embeds YouTube videos using their video ID            |
| `embed/twitch.html`        | Embeds Twitch videos using their video ID             |
| `embed/bilibili.html`      | Embeds Bilibili videos using their video ID           |
| `embed/video.html`         | Embeds self-hosted video files with advanced options  |
| `embed/audio.html`         | Embeds audio files (e.g., MP3) with metadata support  |
```
---

### [Media Embed Details ,click me to know more]({{ site.posts | where: "slug", "kickstart-blogging-with-chirpy" | first.url | relative_url }})

Chirpy supports multiple platforms via its embed includes:

- **Social Video Platforms**:  
![image](assets/images/snaps/chirpy_tution/embd_p.png){ .left }

  Supported platforms: `youtube`, `twitch`, `bilibili`.


### When Might You Override These?

You may override includes in your local `_includes/` folder to:

- Add support for additional embed platforms (e.g., Vimeo, Instagram)
- Modify how embedded media is styled or behaves
- Insert custom logic around sidebar, TOC, or comments
- Customize how videos or audio are rendered on your site

---

### Source Reference

You can explore all the embed files and their contents here:  
🔗 [`_includes/embed/` folder on GitHub](https://github.com/cotes2020/jekyll-theme-chirpy/tree/master/_includes/embed)


## Acknowledgements

Special thanks to **Cotes** and all the contributors of the [Chirpy theme](https://github.com/cotes2020/jekyll-theme-chirpy) for creating such a well-documented, thoughtfully designed blogging theme for Jekyll.

Much of my understanding and inspiration comes from reading and experimenting with Chirpy, especially from these official resources:

- [Text and Typography](https://chirpy.cotes.page/posts/text-and-typography/)
- [Getting Started](https://chirpy.cotes.page/posts/getting-started/)
- [Write a New Post](https://chirpy.cotes.page/posts/write-a-new-post/)
- [Customize the Favicon](https://chirpy.cotes.page/posts/customize-the-favicon/)

Their efforts have made technical blogging on Jekyll much easier and enjoyable. 