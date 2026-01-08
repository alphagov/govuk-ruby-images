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

## Build Process

Images are automatically built and pushed to GitHub Container Registry in these scenarios:

- **Nightly builds**: Runs daily at 03:34 UTC via scheduled cron job
- **On changes**: Automatically triggered when changes are pushed to `main` affecting:
  - Dockerfiles (`*.Dockerfile`)
  - Build configuration (`build-matrix.json`)
  - Shell scripts (`*.sh`)
  - The build workflow itself
- **Manual triggers**: Can be triggered manually via GitHub Actions workflow_dispatch

Failed builds trigger Slack notifications to `#govuk-platform-support`.

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

### ERROR: failed to solve: cannot copy to non-directory: /var/lib/docker/overlay2/.../merged/app/tmp

Add `tmp/` to your `.dockerignore`. This is necessary because we symlink
`$APP_HOME/tmp` to `/tmp` as a workaround for some badly-behaved gems that
assume they can write to `Path.join(Rails.root, 'tmp')` so that we can run with
`readOnlyRootFilesystem`.

### Build failures with "429 Too Many Requests" or rate limiting errors

If you see registry rate limiting errors during builds, this is typically due to
pulling base images from public registries. The build workflow authenticates to DockerHub using 
[governmentdigitalservice](https://hub.docker.com/u/governmentdigitalservice) and uses DockerHub's 
official Ubuntu images which have generous rate limits for parallel builds. If rate limiting persists, 
the base image can be mirrored to GHCR to eliminate external dependencies.

## Maintenance

### Add or update a Ruby version

The file [build-matrix.json](/build-matrix.json) defines the Ruby versions and image tags that we build.

The `checksum` field is currently the SHA-256 hash of the Ruby source tarball. We verify this in the build.

See [Ruby Releases](https://www.ruby-lang.org/en/downloads/releases/) for the list of available Ruby tarballs and their SHA digests.

### Build workflow maintenance

The build workflow (`.github/workflows/build-multiarch.yaml`) includes several features to ensure reliable image builds:

- **Dependency chain**: Manifest combination and garbage collection only run after successful builds, preventing deletion of working images when new builds fail
- **Path filtering**: Builds are skipped when only non-Docker files change (e.g., documentation updates), reducing unnecessary CI/CD resource usage
- **Failure notifications**: Failed builds automatically notify `#govuk-platform-support` via Slack
- **Manual control**: Workflow can be dispatched manually with option to skip registry push for testing
- **Multi-architecture**: Builds images for multiple Ruby versions across amd64 and arm64 architectures in parallel

### Slack notifications

Build failure notifications are sent to `#govuk-platform-support` using a Slack webhook application. The webhook URL is stored as the `GOVUK_PLATFORM_SUPPORT_SLACK_WEBHOOK_URL` repository secret.

If notifications stop working or need to be reconfigured:

1. GOV.UK Platform Engineers should have access to the Slack application configuration
2. The webhook URL secret can be regenerated from the Slack app settings
3. Update the repository secret manually in [GitHub Settings > Secrets and variables > Actions](https://github.com/alphagov/govuk-ruby-images/settings/secrets/actions)

Contact the [Platform Engineering team](#team) if you need assistance with Slack webhook configuration.

### Team

[GOV.UK Platform Engineering team](https://github.com/orgs/alphagov/teams/gov-uk-platform-engineering) looks after this repo. If you're inside GDS, you can find us in [#govuk-platform-engineering](https://gds.slack.com/channels/govuk-platform-engineering) or view our [project board](https://github.com/orgs/alphagov/projects/71).
