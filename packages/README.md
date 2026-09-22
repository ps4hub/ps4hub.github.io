# packages/

This folder is served by the hub's **Package Installer** page (`packages.html`), which lets the PS4 sideload `.pkg` files directly from its browser.

On the live deployment this folder is full of `.pkg` files — game saves, avatar packs, homebrew installers, etc. — collected from various community sources over time, without a single clear license or origin per file. That content is **intentionally not included in this repo**: it's a mix of user-added, third-party, and sometimes copyright-adjacent material (game saves, avatar/asset packs) that doesn't belong in a public repo the way the exploit sources under `payloads/` do.

`packages.php` (the page logic that lists and serves whatever's dropped in this folder) **is** included — only the actual package files are excluded.

If you're setting this hub up yourself: drop your own `.pkg` files directly into this folder on your server. Nothing else needs to change — the packages page picks up whatever's here automatically.
