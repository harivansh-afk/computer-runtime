#!/usr/bin/env bash
# First-run picker that discovers secrets on the laptop and writes secrets.json.
# After the user commits the file, subsequent `just secrets` runs are declarative
# and do not re-open the picker.
set -euo pipefail

out="${1:-secrets.json}"

if [[ -f "$out" ]]; then
  echo "$out already exists — regenerating (old file will be overwritten)."
fi

if ! command -v gum >/dev/null; then
  echo "gum is required for the picker. install with: brew install gum" >&2
  exit 1
fi
if ! command -v jq >/dev/null; then
  echo "jq is required" >&2; exit 1
fi

# ------------------------------------------------------------------------------
# Discover candidates. Each candidate is a line "TYPE\tLABEL\tSPEC_JSON".
# ------------------------------------------------------------------------------
candidates_file="$(mktemp)"
trap 'rm -f "$candidates_file"' EXIT

# ---- Bitwarden folder items ----
bw_folder=""
if command -v bw >/dev/null; then
  echo "What Bitwarden folder holds your machine secrets? (leave blank to skip Bitwarden)"
  bw_folder="$(gum input --placeholder 'machine secrets' || true)"
  bw_folder="${bw_folder:-}"
fi

if [[ -n "$bw_folder" ]]; then
  case "$(bw status | jq -r '.status')" in
    unauthenticated) echo "bw: not logged in, skipping Bitwarden discovery" >&2; bw_folder="" ;;
    locked)
      BW_SESSION="$(bw unlock --raw)"
      export BW_SESSION
      ;;
    unlocked) : ;;
  esac
fi

if [[ -n "$bw_folder" ]]; then
  folder_id="$(bw list folders | jq -r --arg n "$bw_folder" '.[]|select(.name==$n)|.id')"
  if [[ -z "$folder_id" || "$folder_id" == "null" ]]; then
    echo "bw folder not found: $bw_folder (will still include env/file candidates)" >&2
  else
    while IFS= read -r name; do
      # Heuristic: if the item name looks like it contains a var name, propose that;
      # otherwise transform the name into a SCREAMING_SNAKE env var name.
      safe="$(echo "$name" | tr '[:lower:] -' '[:upper:]__' | tr -cd 'A-Z0-9_')"
      if [[ -z "$safe" ]]; then safe="BW_ITEM_$(echo "$name" | md5 | cut -c1-6 | tr '[:lower:]' '[:upper:]')"; fi
      printf 'bw\t%s  →  %s\t{"bw":%s}\n' "$name" "$safe" "$(jq -Rn --arg n "$name" '$n')" \
        >>"$candidates_file"
    done < <(bw list items --folderid "$folder_id" | jq -r '.[].name')
  fi
fi

# ---- Known config files ----
# Only offer files/dirs that actually exist on the laptop.
known_files=(
  "$HOME/.aws/credentials:0600"
  "$HOME/.aws/config:0600"
  "$HOME/.config/gh/hosts.yml:0600"
  "$HOME/.config/gcloud:0700:recursive"
  "$HOME/.docker/config.json:0600"
  "$HOME/.kube/config:0600"
  "$HOME/.config/vercel/auth.json:0600"
  "$HOME/.npmrc:0600"
  "$HOME/.pypirc:0600"
  "$HOME/.netrc:0600"
  "$HOME/.ssh/id_ed25519:0600"
  "$HOME/.ssh/id_ed25519.pub:0644"
  "$HOME/.ssh/id_rsa:0600"
  "$HOME/.ssh/id_rsa.pub:0644"
  "$HOME/.ssh/config:0600"
  "$HOME/.cargo/credentials.toml:0600"
)
for spec in "${known_files[@]}"; do
  IFS=':' read -r path mode flag <<<"$spec"
  [[ -e "$path" ]] || continue
  dest="${path/#$HOME/\~}"
  obj="$(jq -n --arg s "$dest" --arg d "$dest" --arg m "$mode" \
          '{src:$s,dest:$d,mode:$m}')"
  if [[ "$flag" == "recursive" ]]; then
    obj="$(jq -c '.recursive=true' <<<"$obj")"
  fi
  printf 'file\t%s (mode %s)\t%s\n' "$dest" "$mode" "$obj" >>"$candidates_file"
done

# ---- Env var candidates ----
# Heuristic: look at exported env vars matching known interesting patterns,
# skip empties and things that look like paths / versions.
while IFS='=' read -r k v; do
  [[ -z "$k" || -z "$v" ]] && continue
  case "$v" in
    /*|\~/*|*:*/*) continue ;;  # paths
    [0-9]*.[0-9]*.[0-9]*) continue ;;  # versions
  esac
  # Tokens/keys of any useful length.
  if [[ ${#v} -lt 12 || ${#v} -gt 4096 ]]; then continue; fi
  obj="$(jq -n --arg e "$k" '{envName:$e}')"
  printf 'env\tenv:%s\t%s\n' "$k" "$obj" >>"$candidates_file"
done < <(env | grep -E '^(.*_(TOKEN|KEY|SECRET|PASSWORD|PASS|CREDENTIAL|API_KEY)|GITHUB_TOKEN|DATABASE_URL|REDIS_URL|OPENAI_.*|ANTHROPIC_.*|VERCEL_.*|AWS_.*|GCP_.*|GOOGLE_.*|STRIPE_.*|CF_.*|CLOUDFLARE_.*|NPM_.*|HF_.*|HUGGINGFACE_.*)=' || true)

# gh token fallback as a standalone candidate.
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  printf 'fallback\tGITHUB_TOKEN (from gh CLI)\t%s\n' '{"fallback":"gh-cli"}' >>"$candidates_file"
fi

total="$(wc -l <"$candidates_file" | tr -d ' ')"
if [[ "$total" -eq 0 ]]; then
  echo "no candidates discovered. you can still hand-write $out — see secrets.example.json." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Picker (gum choose, no-limit, all pre-selected).
# ------------------------------------------------------------------------------
echo
echo "==> $total candidate(s) found. space toggles, enter confirms."
# Build labels list; preserve the index so we can map back.
labels=()
while IFS=$'\t' read -r _type label _spec; do labels+=("$label"); done <"$candidates_file"

selected="$(
  printf '%s\n' "${labels[@]}" \
    | gum filter --no-limit \
        --placeholder "type to search · tab toggles · enter confirms" \
        --selected "$(IFS=,; echo "${labels[*]}")" \
        --height 20 \
        --indicator "›" \
        --selected-prefix " ✓ " \
        --unselected-prefix "   " \
    || true
)"

if [[ -z "$selected" ]]; then
  echo "nothing selected, not writing $out" >&2; exit 1
fi

# ------------------------------------------------------------------------------
# Emit secrets.json
# ------------------------------------------------------------------------------
declare -a ENV_ENTRIES=()
declare -a FILE_ENTRIES=()

while IFS= read -r label; do
  [[ -z "$label" ]] && continue
  # Find the matching candidate line.
  line="$(grep -F -m1 $'\t'"$label"$'\t' "$candidates_file" || true)"
  [[ -z "$line" ]] && continue
  IFS=$'\t' read -r type _lbl spec <<<"$line"

  case "$type" in
    bw)
      # Label is "<bw name>  →  <VAR_NAME>"
      var_name="${label##*→ }"
      var_name="${var_name## }"
      ENV_ENTRIES+=("$(jq -n --arg k "$var_name" --argjson v "$spec" '{($k):$v}')")
      ;;
    env)
      # Label is "env:VAR_NAME"
      var_name="${label#env:}"
      ENV_ENTRIES+=("$(jq -n --arg k "$var_name" --argjson v "$spec" '{($k):$v}')")
      ;;
    fallback)
      # Label is "GITHUB_TOKEN (from gh CLI)"
      var_name="${label%% *}"
      ENV_ENTRIES+=("$(jq -n --arg k "$var_name" --argjson v "$spec" '{($k):$v}')")
      ;;
    file)
      FILE_ENTRIES+=("$spec")
      ;;
  esac
done <<<"$selected"

env_merged='{}'
for e in "${ENV_ENTRIES[@]}"; do
  env_merged="$(jq -c --argjson b "$e" '. * $b' <<<"$env_merged")"
done

files_merged='[]'
for f in "${FILE_ENTRIES[@]}"; do
  files_merged="$(jq -c --argjson b "$f" '. + [$b]' <<<"$files_merged")"
done

bw_block='null'
if [[ -n "$bw_folder" ]]; then
  bw_block="$(jq -n --arg f "$bw_folder" '{folder:$f}')"
fi

jq -n \
  --argjson bw "$bw_block" \
  --argjson env "$env_merged" \
  --argjson files "$files_merged" \
  '{bitwarden:$bw, env:$env, files:$files}
   | if .bitwarden == null then del(.bitwarden) else . end' \
  >"$out"

echo
echo "==> wrote $out:"
echo "     env entries:  $(jq '.env|length' "$out")"
echo "     file entries: $(jq '.files|length' "$out")"
echo "     bitwarden:    $(jq -r '.bitwarden.folder // "(none)"' "$out")"
echo
echo "review it, commit to your fork, then run: just secrets <handle>"
