#!/bin/sh

# Set a custom shell prompt based on the GOVUK_ENVIRONMENT variable.
# This script is sourced by login shells, like when using `kubectl exec`.

# Check if we are in an interactive bash shell
if [ -n "$BASH_VERSION" ]; then
  case "${GOVUK_ENVIRONMENT}" in
    "production")
      # Red for production
      COLOUR="\[\033[0;31m\]"
      ;;
    "staging")
      # Yellow for staging
      COLOUR="\[\033[0;33m\]"
      ;;
    "integration")
      # Green for integration
      COLOUR="\[\033[0;32m\]"
      ;;
    *)
      # Blue for all other environments (development, default)
      COLOUR="\[\033[0;36m\]"
      ;;
  esac

  # Reset COLOUR
  NO_COLOUR="\[\033[0m\]"

  # Export the new prompt setting
  # Format: [environment] user@hostname:working_directory$
  export PS1="${COLOUR}[${GOVUK_ENVIRONMENT}]${NO_COLOUR} \u@\h:\w\$ "
fi
