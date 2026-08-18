# viewer

**Public host for encrypted model pages.** GitHub Pages on a free organisation
plan only serves from a public repository, so everything in `docs/` is readable
by anyone who knows the URL — and by anyone who clones this repo, now or later.

**Therefore: nothing goes in here unencrypted.** Build pages with
`rhino-viewer --passphrase`, which AES-256-GCM encrypts the payload and puts the
key derivation in the browser. That covers the geometry *and* the layer names,
the source filename and the title, so a page reveals nothing about which
commission it belongs to until someone with the passphrase opens it.

Filenames are hashes for the same reason. A repository called `lim-viewer`
holding `dome-cable-lengths.html` tells the world what the studio is working on
without anyone opening a thing.

    rhino-viewer model.3dm --passphrase-file secret.txt -o docs/m/<slug>.html

`<slug>` is `printf '<name>' | shasum -a 256 | cut -c1-8`, so re-publishing the
same model keeps its URL.

The tool lives in [rhino-viewer](https://github.com/Nikolas-Weinstein-Studios/rhino-viewer).
Passphrases are not stored here. Send the link and the passphrase by different
routes, and rotate by rebuilding — it is one command.
