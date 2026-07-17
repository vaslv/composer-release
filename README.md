# vaslv/composer-release

Interactive release helper for Composer projects. It looks at your existing git
tags, offers the next patch / minor / major version, writes it to
`composer.json`, then commits, tags and (optionally) pushes — so you never have
to check what the last version was before cutting a release.

```
Current version: v1.4.2

Select next version:
  1) patch  → v1.4.3
  2) minor  → v1.5.0
  3) major  → v2.0.0
  4) custom
  q) quit
```

## Requirements

- bash, git and composer available in `PATH`
- Composer 2.x

## Installation

```bash
composer require --dev vaslv/composer-release
```

The package is a Composer plugin, so on first install Composer will ask whether
you trust it. Answer `y`, or allow it up front:

```bash
composer config allow-plugins.vaslv/composer-release true
```

## Usage

The plugin registers a native Composer command:

```bash
composer release
```

The script is also exposed through `vendor/bin`, so these work too:

```bash
vendor/bin/release
composer exec release
```

## What it does

1. Refuses to run with a dirty working tree or on a detached HEAD; warns when
   you are not on `main`/`master`.
2. Fetches tags from `origin` (when the remote exists), then finds the latest
   semver tag — `1.2.3` and `v1.2.3` styles are both supported, mixed styles
   compare correctly, and the existing prefix is preserved.
3. Lets you pick patch / minor / major / custom for the next version.
4. If `composer.json` already commits a `version` field, updates it and commits
   as `chore(release): <tag>` (restoring the file if the commit fails). Without
   the field — the Packagist-recommended setup — the release is tag-only.
5. Creates an annotated tag.
6. Asks whether to push the branch and the tag to `origin` in one atomic push.

Every destructive step asks for confirmation first; nothing is pushed without
an explicit yes.

## Development

```bash
composer install
composer analyse         # PHPStan, level max
composer test            # PHPUnit smoke tests for the plugin wiring
bats tests/release.bats  # end-to-end tests for the release script
```

## License

MIT
