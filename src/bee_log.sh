#!/usr/bin/env bash

log() {
  echo "🐝 $*"
}

log_error() {
  echo "❌ ERROR: $*" >&2
}

log_strong() {
  echo ""
  echo "################################################################################"
  echo "# 🐝 $*"
  echo "################################################################################"
}

log_func() {
  log_strong "${FUNCNAME[1]} $*"
}