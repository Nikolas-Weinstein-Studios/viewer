#!/bin/sh
# Publish a model to the Pages site, or update one already there.
#
#   ./publish.sh <model.3dm> "<name>" [--dry-run]
#
# The name is what the page calls itself once unlocked, and what the slug derives
# from -- so re-publishing the same model under the same name keeps its URL.
#
# This exists because the sequence is five steps across two repositories and one
# of them is "remember --passphrase". Forgetting that would put a commission's
# geometry on the open internet in the clear, so the guard below refuses rather
# than trusting anyone to remember.

set -eu

REPO_URL="https://nikolas-weinstein-studios.github.io/viewer"
SECRET="secret.txt"

cd "$(dirname "$0")"

if [ $# -lt 2 ]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

MODEL="$1"
NAME="$2"
DRY="${3:-}"

[ -f "$MODEL" ] || { echo "no such model: $MODEL" >&2; exit 1; }
[ -f "$SECRET" ] || { echo "no $SECRET here -- put the passphrase in it (it is gitignored)" >&2; exit 1; }

RV="$(command -v rhino-viewer || true)"
[ -n "$RV" ] || RV="../rhino-viewer/.venv/bin/rhino-viewer"
[ -x "$RV" ] || { echo "rhino-viewer not found -- see the README" >&2; exit 1; }

SLUG="$(printf '%s' "$NAME" | shasum -a 256 | cut -c1-8)"
OUT="docs/m/$SLUG.html"
[ -f "$OUT" ] && WHAT="updating" || WHAT="publishing"
echo "$WHAT \"$NAME\" -> $OUT"

# Note: no --fragment. That is for a host supplying its own <head>/<body>, such
# as a Claude Artifact; a fragment served by Pages is a page with no document.
"$RV" "$MODEL" -o "$OUT" -t "$NAME" --passphrase-file "$SECRET"

# ---- the guard ------------------------------------------------------------
# Everything in docs/ is world-readable. A page whose payload is not an envelope
# is plaintext, and must not reach the remote.
for f in docs/m/*.html; do
  [ -f "$f" ] || continue
  if ! grep -q '"enc":"AES-GCM"' "$f"; then
    echo >&2
    echo "REFUSING TO PUBLISH: $f has an unencrypted payload." >&2
    echo "This repository is public. Rebuild it with --passphrase-file." >&2
    exit 1
  fi
done
# and the passphrase itself must never be tracked
if git ls-files --error-unmatch "$SECRET" >/dev/null 2>&1; then
  echo "REFUSING TO PUBLISH: $SECRET is tracked by git." >&2
  exit 1
fi
echo "guard: every page in docs/ is encrypted, and $SECRET is untracked"

URL="$REPO_URL/m/$SLUG.html"
if [ "$DRY" = "--dry-run" ]; then
  echo "dry run, nothing pushed. would be: $URL"
  exit 0
fi

git add "$OUT"
if git diff --cached --quiet; then
  echo "no change to publish -- the page already matches this model"
else
  git commit -q -m "$WHAT $SLUG"
  git push -q origin main
  echo "pushed. waiting for the Pages build..."
  i=0
  while [ $i -lt 30 ]; do
    s="$(gh api "repos/Nikolas-Weinstein-Studios/viewer/pages" --jq .status 2>/dev/null || echo unknown)"
    [ "$s" = "built" ] && break
    sleep 10
    i=$((i + 1))
  done
  echo "pages: ${s:-unknown}"
fi

# ---- prove it is actually being served -----------------------------------
i=0
while [ $i -lt 12 ]; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$URL")"
  [ "$code" = "200" ] && break
  sleep 10
  i=$((i + 1))
done
echo "$URL -> HTTP $code"
[ "$code" = "200" ] || { echo "not being served yet; try again shortly" >&2; exit 1; }

if curl -s "$URL" | grep -q '"enc":"AES-GCM"'; then
  echo "served page is encrypted. done."
else
  echo "SERVED PAGE IS NOT ENCRYPTED -- take it down now." >&2
  exit 1
fi
