# viewer

Public host for **encrypted** model pages, built by
[rhino-viewer](https://github.com/Nikolas-Weinstein-Studios/rhino-viewer).

Live at `https://nikolas-weinstein-studios.github.io/viewer/m/<slug>.html`

## Publish or update a model

```
./publish.sh <model.3dm> "<name>"
./publish.sh <model.3dm> "<name>" --dry-run     # build and check, push nothing
```

That is the whole thing. It derives the slug from the name, builds the page
encrypted, refuses if anything in `docs/` is not, commits, pushes, waits for the
Pages build, then fetches the live URL and confirms what is being served is
ciphertext. It prints the URL at the end.

**The name determines the URL.** `<slug>` is
`printf '<name>' | shasum -a 256 | cut -c1-8`, so publishing the same model under
the same name updates the same page and any link already sent keeps working. A
different name is a different page. There is no index of slugs here on purpose —
see below — so keep a note of the names you use, or recompute the slug from the
name when you need it.

The passphrase goes in `secret.txt`, which is gitignored. Rotating it is the same
command: change the file, publish again.

## Why everything here is encrypted

GitHub Pages on a free organisation plan serves **only from a public repository**.
So everything in `docs/` is readable by anyone with the URL, and by anyone who
clones this repo now or in ten years.

`rhino-viewer --passphrase` therefore AES-256-GCM encrypts the payload and derives
the key in the browser with PBKDF2-SHA256. **It covers the layer names, the source
filename and the title as well as the geometry** — a public page reading "Lim
Cable Redux" over a passphrase box has already disclosed the thing worth
protecting. Pages are called `Model viewer` until someone opens one.

The same reasoning explains the rest of the shape of this repo: it is called
`viewer` and not `lim-viewer`, files are named by hash and not by commission, and
no slug-to-model index is kept here. A tidy index would undo all of it.

**Two things the encryption does not do.** The slug is not a secret — anyone who
guesses the name can compute it — it only stops a crawler from enumerating pages,
and the payload is what actually protects the model. And the ciphertext is public,
so a weak passphrase can be attacked offline; 250,000 PBKDF2 rounds raise the cost
of each guess but do not rescue a guessable phrase.

## Two guards, because remembering is not a control

| | |
|---|---|
| `publish.sh` | refuses to push if any page in `docs/` has a plaintext payload, or if `secret.txt` is tracked |
| `.github/workflows/no-plaintext.yml` | fails on any push touching `docs/` whose pages are not encrypted — catches a page committed by hand, or a session that forgot the flag |

Forgetting `--passphrase` once would put a commission's geometry on the open
internet. That is too easy a mistake to leave to prose.

## Setup on a new machine

```
git clone https://github.com/Nikolas-Weinstein-Studios/viewer.git viewer-pages
git clone https://github.com/Nikolas-Weinstein-Studios/rhino-viewer.git
cd rhino-viewer && python -m venv .venv && .venv/bin/pip install -e ".[crypto]"
cd ../viewer-pages && printf '<the passphrase>' > secret.txt
```

`publish.sh` finds `rhino-viewer` on `PATH`, or falls back to
`../rhino-viewer/.venv/bin/rhino-viewer`, so the two clones sitting side by side
is the arrangement it expects. It also needs `gh` authenticated, to read the Pages
build status.

## How the site itself is configured

Written down so it can be rebuilt, not just used. Pages serves from **branch
`main`, path `/docs`**:

```
gh api -X POST repos/Nikolas-Weinstein-Studios/viewer/pages \
  -f "source[branch]=main" -f "source[path]=/docs"
```

`docs/.nojekyll` stops Jekyll from touching the output. A first build takes a
couple of minutes; `publish.sh` waits for it.

## If the org ever moves to GitHub Team

Pages would then serve from a **private** repo with visibility limited to org
members, and none of the above would be necessary — no encryption, no hashed
filenames, real titles. That is the better answer to this problem and it costs
about $4/user/month over 3 seats. `rhino-viewer/STATE.md` records why it was not
taken now. Revisit if the plan changes.

## Do not use `--fragment` here

`--fragment` emits body-level HTML for a host that supplies its own
`<!doctype><head><body>`, such as a Claude Artifact. Served by Pages it is a page
with no document. `publish.sh` never passes it; if you build by hand, don't either.
