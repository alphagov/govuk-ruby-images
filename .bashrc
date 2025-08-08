#!/usr/bin/env bash

# return early if the shell is not interactive
case $- in
  *i*) ;;
  *) return ;;
esac

case "$GOVUK_ENVIRONMENT" in
  integration|staging) PROMPT_ENV_COLOUR="$(tput setaf 3)" ;;   # yellow
  production)          PROMPT_ENV_COLOUR="$(tput setaf 1)" ;;   # red
  *)                   PROMPT_ENV_COLOUR="$(tput setaf 4)" ;;   # blue
esac
RESET=$(tput sgr0)

prompt_env() {
  printf '%s (%s%s%s)' \
    "${GOVUK_APP_NAME:-unknown app}" \
    "$PROMPT_ENV_COLOUR" \
    "${GOVUK_ENVIRONMENT:-unknown env}" \
    "$RESET"
}

export PS1='$(prompt_env) | \u@\h:\w\$ '
