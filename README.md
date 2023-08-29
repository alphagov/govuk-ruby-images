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

## Common problems and resolutions

`ERROR: failed to solve: cannot copy to non-directory: /var/lib/docker/overlay2/.../merged/app/tmp`

Add `tmp/` to your `.dockerignore`. This is necessary because we symlink
`$APP_HOME/tmp` to `/tmp` as a workaround for some badly-behaved gems that
assume they can write to `Path.join(Rails.root, 'tmp')` so that we can run with
`readOnlyRootFilesystem`.


## Managing Ruby versions

Ruby version information is kept in the [versions](versions/) directory. Each file in this directory is a shell script containing three variables that define a Ruby version:

* `RUBY_MAJOR`: The major and minor Ruby version, excluding the patch version. For example, `3.2`. The image will be tagged with this version number (with `.` instead of `_`) unless `RUBY_IS_PATCH` is equal to the string `true`.
* `RUBY_VERSION`: The full Ruby version, including patch version. This is used to download the Ruby source distribution. The image will be tagged with this version number, regardless of the value of `RUBY_IS_PATCH`.
* `RUBY_IS_PATCH`: If equal to the string `true` then this version will **not** be tagged with the major.minor version number. (It will be tagged only with the full version number that includes the patch version.)


### Hashes of source tarballs for verification

The file [SHA256SUMS](SHA256SUMS) contains the SHA-256 hashes of the Ruby and OpenSSL source tarballs. These are verified at build-time.

To add hashes for new Ruby/OpenSSL versions:

1. Download the new source tarball(s).

1. Run `sha256sum *gz >>SHA256SUMS`. If your system doesn't have `sha256sum`, try `shasum -a256`.

1. Compare the new hashes with those listed on the [Ruby downloads page](https://www.ruby-lang.org/en/downloads/) and [OpenSSL downloads page](https://www.openssl.org/source/).


## Team

[GOV.UK Platform Engineering team](https://github.com/orgs/alphagov/teams/gov-uk-platform-engineering) looks after this repo. If you're inside GDS, you can find us in [#govuk-platform-engineering](https://gds.slack.com/channels/govuk-platform-engineering) or view our [kanban board](https://trello.com/b/u4FCzm53/).
