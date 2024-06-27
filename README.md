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

Use the two images in your app's Dockerfile.

Specify the image tag that corresponds to the `<major>.<minor>` Ruby version that your application needs.


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


## Supported tags

Our version maintenance policy is similar to [upstream](https://www.ruby-lang.org/en/downloads/branches/) except that we drop support for a (major.minor) version series once it's no longer in use in GOV.UK.

See [build-matrix.json](build-matrix.json#L2) for the list of Ruby versions we currently support.

> [!IMPORTANT]
> Please do not attempt to specify the Ruby patch version. See [below](#if-you-suspect-a-bug) for alternatives.


### If you suspect a bug

If you encounter a bug in govuk-ruby-images that breaks your application or your build:

- if absolutely necessary, you **may** *temporarily* pin a known-good [base](https://github.com/alphagov/govuk-ruby-images/pkgs/container/govuk-ruby-base) and/or [builder](https://github.com/alphagov/govuk-ruby-images/pkgs/container/govuk-ruby-builder) image by SHA or SHA prefix, for example:

    ```Dockerfile
    # TODO(https://github.com/alphagov/govuk-ruby-images/issues/96): remove pinned image once bug is fixed.
    ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:3.3-acecafe
    ```

- if you pin a base/builder image SHA, you **must**:

  - [file an issue](https://github.com/alphagov/govuk-ruby-images/issues/new) so that the maintainers know there is a problem that needs to be addressed
  - add a TODO containing a link to the issue, so that the workaround can be cleaned up once the issue is fixed

If you are unsure, ask [Platform Engineering team](#team) for advice.


## Common problems and resolutions

`ERROR: failed to solve: cannot copy to non-directory: /var/lib/docker/overlay2/.../merged/app/tmp`

Add `tmp/` to your `.dockerignore`. This is necessary because we symlink
`$APP_HOME/tmp` to `/tmp` as a workaround for some badly-behaved gems that
assume they can write to `Path.join(Rails.root, 'tmp')` so that we can run with
`readOnlyRootFilesystem`.


## Maintenance


### Add or update a Ruby version

The file [build-matrix.json](/build-matrix.json) defines the Ruby versions and image tags that we build.

The `checksum` field is currently the SHA-256 hash of the Ruby source tarball. We verify this in the build.

See [Ruby Releases](https://www.ruby-lang.org/en/downloads/releases/) for the list of available Ruby tarballs and their SHA digests.


### Team

[GOV.UK Platform Engineering team](https://github.com/orgs/alphagov/teams/gov-uk-platform-engineering) looks after this repo. If you're inside GDS, you can find us in [#govuk-platform-engineering](https://gds.slack.com/channels/govuk-platform-engineering) or view our [project board](https://github.com/orgs/alphagov/projects/71).
