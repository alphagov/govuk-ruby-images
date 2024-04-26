# GOV.UK Ruby Images


## What's in this repo

The govuk-ruby-images repository defines [OCI] container images for building and running production Ruby applications on Kubernetes.

- `govuk-ruby-base` is a base image for production application containers; it provides:
  - a Ruby runtime that can run as an unprivileged user with a read-only filesystem
  - database client libraries
  - a Node.js runtime

- `govuk-ruby-builder` is for building application container images; it provides the same as `govuk-ruby-base` plus:
  - a C/C++ toolchain and various build tools and utilities
  - Yarn, for building/installing Node.js package dependencies
  - configuration to speed up and optimise building Ruby applications

[OCI]: https://opencontainers.org/


## Usage

Use the two images in your app's Dockerfile:

```dockerfile
ARG ruby_version=3.3
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version

FROM $builder_image AS builder

# your build steps here

FROM $base_image

# your app image steps here
```

See [alphagov/frontend/Dockerfile](https://github.com/alphagov/frontend/blob/-/Dockerfile) for a full, real-world example.


## Common problems and resolutions

`ERROR: failed to solve: cannot copy to non-directory: /var/lib/docker/overlay2/.../merged/app/tmp`

Add `tmp/` to your `.dockerignore`. This is necessary because we symlink
`$APP_HOME/tmp` to `/tmp` as a workaround for some badly-behaved gems that
assume they can write to `Path.join(Rails.root, 'tmp')` so that we can run with
`readOnlyRootFilesystem`.


## Add or update a Ruby version

The file [build-matrix.json](/build-matrix.json) defines the Ruby versions and image tags that we build.

The `checksum` field is currently the SHA-256 hash of the Ruby source tarball. We verify this in the build.

See [Ruby Releases](https://www.ruby-lang.org/en/downloads/releases/) for the list of available Ruby tarballs and their SHA digests.


## Team

[GOV.UK Platform Engineering team](https://github.com/orgs/alphagov/teams/gov-uk-platform-engineering) looks after this repo. If you're inside GDS, you can find us in [#govuk-platform-engineering](https://gds.slack.com/channels/govuk-platform-engineering) or view our [kanban board](https://github.com/orgs/alphagov/projects/71).
