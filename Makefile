# Makefile for Jekyll + HTMLProofer

# Default Jekyll build directory
SITE_DIR = _site

# HTMLProofer flags
HTMLPROOFER_FLAGS = --disable-external \
                    --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"

# Default target
.PHONY: all
all: build

# Build the site
.PHONY: build
build:
	bundle exec jekyll build

# Serve the site locally
.PHONY: serve
serve:
	bundle exec jekyll serve

# Run HTMLProofer to check for broken internal links
.PHONY: check
check:
	bundle exec htmlproofer $(SITE_DIR) $(HTMLPROOFER_FLAGS)

# Clean the _site directory
.PHONY: clean
clean:
	rm -rf $(SITE_DIR)

# Build and then check
.PHONY: test
test: build check