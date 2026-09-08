#!/bin/bash
# Простое логирование в MAIN_LOG_FILE / ERROR_LOG_FILE

function log() {
    local message="$1"
    local tag="${2:-}"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -n "$tag" ]; then
        echo "[$ts] [$tag] $message" | tee -a "$MAIN_LOG_FILE"
    else
        echo "[$ts] $message" | tee -a "$MAIN_LOG_FILE"
    fi
}

function log_error() {
    local message="$1"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] [ERROR] $message" | tee -a "$MAIN_LOG_FILE" "$ERROR_LOG_FILE" >&2
}
