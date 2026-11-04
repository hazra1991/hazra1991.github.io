---
layout: post  
title: "Django Database Connections: Behind the Scenes"
date: 2025-09-23
categories: [Backend, Database Access]
tags: [django, database, python]
slug: django-database-connections
---

<details>
<summary><strong>📑 Table of Contents</strong></summary>
    
<div markdown="1">

</div>
</details>

---

Django comes out of the box with support for multiple databases and works seamlessly with them. One of the lesser-talked-about conveniences of Django is how it abstracts away the need to manually install or manage low-level database drivers in many cases.

Built-in Database Support Django officially supports the following databases: **PostgreSQL**, **MariaDB**, **MySQL**, **Oracle**, and **SQLite**.
you can install the recomended drivers that is supported by Django only chceck the Django docs for the same 

> 🔍 **For example**: When using PostgreSQL with Django, you can or don't install `psycopg[binary]` . 

<a href="https://docs.djangoproject.com/en/5.2/ref/databases" target="_blank">Databases with Django official docs. Details on all settings</a>

---

## Defining and Configuring Databases in Django

All database configuration in Django is done inside the `settings.py` file under the `DATABASES` dictionary.

This dictionary has:

- **Keys**: Alias names representing each database.  
- **Values**: A dictionary of configuration parameters for that database.

> 💡 Every Django project must have a `'default'` alias. This is the database Django uses by default whenever you access the ORM or connections layer unless you specify otherwise.

To interact with a non-default DB, Django provides the `.using()` method.

**Example:**
```python
Model.objects.using("my_second_DB").all()
```

---

## Example: `settings.py` Database Configurations

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'Name_pf_the_DB_for_our_reference',
        'USER': 'db_username',
        'PASSWORD': 'db_password',
        'HOST': '10.12.30.89',
        'PORT': 5432,
        'CONN_MAX_AGE': 60
    },
    'my_second_DB': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'Name_pf_the_DB_for_our_reference',
        'USER': 'db_username',
        'PASSWORD': 'db_password',
        'HOST': 'localhost',
        'PORT': 5432,
    },
    'my_third_DB': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
```

---

## Note on Default Behavior

These settings are DB-specific and the fields required may vary depending on the database engine.

If you only provide the `ENGINE`, Django fills the rest with sensible defaults. If nothing is configured, Django falls back to using a dummy database engine. All of this happens during Django’s settings loading phase.

---

## Parsed Example from `settings.DATABASES`

Here’s how Django internally populates database settings after parsing:

```python
{
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'Name_pf_the_DB_for_our_reference',
        'USER': 'db_username',
        'PASSWORD': 'db_password',
        'HOST': '10.12.30.89',
        'PORT': 5432,
        'CONN_MAX_AGE': 60,
        'ATOMIC_REQUESTS': False,
        'AUTOCOMMIT': True,
        'CONN_HEALTH_CHECKS': False,
        'OPTIONS': {
            'fallback_application_name': 'django_shell'
        },
        'TIME_ZONE': None,
        'TEST': {
            'CHARSET': None,
            'COLLATION': None,
            'MIGRATE': True,
            'MIRROR': None,
            'NAME': None
        }
    }
}
```

As you can see, Django augments the provided settings with several defaults for connection management, health checks, testing, and more.

---

## TL;DR Recap:

- ✅ Django supports multiple DBs out of the box.  
- ⚙️ Configuration is done via the `DATABASES` dictionary in `settings.py`.  
- 📌 A `'default'` alias is required.  
- 🔄 Use `.using()` for non-default DBs.  
- 🧠 Django fills in a lot of defaults behind the scenes — fewer headaches for developers.

---

Would you like to add a section on how connection pooling or connection closing works in Django, or keep this focused just on configuration?

Also let me know if you'd like this exported as a markdown file for easy publishing to your blog.
