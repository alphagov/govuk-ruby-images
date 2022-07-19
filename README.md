# GOV.UK Ruby Images

## What's in this repo

This repo contains Docker images intented for use as a base for GOV.UK app containers.
The govuk-ruby-base image contains a Ruby installation, along with node.js and yarn.
The govuk-ruby-builder image contains environment variables and configuration for building Ruby applications.

## Usage

Use the two images in your app's Dockerfile:

```dockerfile
FROM ghcr.io/alphagov/govuk-ruby-builder:3.0 AS builder

# your build steps here

FROM ghcr.io/alphagov/govuk-ruby-base:3.0

# your app image steps here
```

## Managing Ruby versions

Ruby version information is kept in the [versions](versions/) directory. Each file in this directory is a shell script containing three variables that define a Ruby version:

* `RUBY_MAJOR`: The major Ruby version. This is used as the Docker image tag
* `RUBY_VERSION`: The full Ruby version, including patch version. This is used to download the Ruby source distribution. This should be the latest patch version available.
* `RUBY_DOWNLOAD_SHA256`: A SHA-256 hash for the Ruby source distribution. The hash can be found on the [Ruby releases page](https://www.ruby-lang.org/en/downloads/releases/) (take the .tar.xz hash)