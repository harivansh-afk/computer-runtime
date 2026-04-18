set dotenv-load := true

default:
  @just --list

# Apply the flake to a computer
switch handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/bootstrap.sh "$h"

# Clone gh repos onto a computer (fzf multi-select)
repos handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/pick-repos.sh "$h"

# Render bitwarden secrets onto a computer (fzf multi-select)
secrets handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/pick-secrets.sh "$h"

# Copy agent credentials onto a computer
agent handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/pick-agent.sh "$h"

# Create a new computer using COMPUTER_SIZE from .env
create handle:
  computer create --size ${COMPUTER_SIZE} {{ handle }}
