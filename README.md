# vaslv/composer-release

Interactive release helper for Composer projects. It looks at your existing git
tags, offers the next patch / minor / major version, then tags and (optionally)
pushes — so you never have to check what the last version was before cutting a
release.

The git tag is the only source of truth. A release writes no files and creates
no release commit: nothing in the working tree records the version, so nothing
can drift from the tag or conflict on a merge.

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

- bash and git available in `PATH`
- Composer 2.x (to install the plugin; the release script itself never shells
  out to composer)

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
4. Creates an annotated tag, its message defaulting to the tag itself and
   configurable (see below). That is the whole release: no file is written and
   no commit is made.
5. Asks whether to push the branch and the tag to `origin` in one atomic push.
   The branch goes along even though nothing was committed — the tagged commit
   may simply not be on `origin` yet, and an atomic push never leaves a tag
   pointing at a commit nobody can fetch.

Every destructive step asks for confirmation first; nothing is pushed without
an explicit yes.

If `composer.json` still commits a `version` field, the command prints a
warning. It does not touch the field — see below.

## Configuring the tag message

By default the annotated tag carries the tag as its message (`v1.2.3`). Set a
template once per repository to use your own wording instead:

```bash
git config release.tagMessage 'Release {tag}'
```

- `{tag}` is replaced with the tag being created, prefix included.
- A template without the placeholder is used verbatim — handy for a fixed
  message like `ship it`.
- The template is never evaluated: `$(...)`, backticks and `$VAR` end up in the
  message as literal text.
- Add `--global` to apply it to every repository, or drop the setting with
  `git config --unset release.tagMessage`.

## Migrating from 0.1.x

0.1.x updated a `version` field in `composer.json` and made a
`chore(release): <tag>` commit whenever the project committed one. 0.2.0 drops
that entirely: the release is always tag-only.

If your project commits the field:

```bash
composer config --unset version
composer update --lock          # refresh the lock file's content hash
```

Removing the field changes `composer.json`, which changes the hash recorded in
`composer.lock`; without the second command `composer validate` reports the
lock file as out of date.

Nothing else is required — a project that never committed the field already
behaved this way.

## Getting the version into a deployed application

A library needs no follow-up: Packagist derives the version from the tag. An
application does, because the deployed artifact has no tags. Pass the tag in at
build time and bake it into the image — that is the whole recipe.

`Dockerfile`, as the **last** layers so a version bump invalidates nothing
above them:

```dockerfile
ARG APP_VERSION=dev
ARG VCS_REF=
ARG BUILD_DATE=

ENV APP_VERSION=${APP_VERSION}

LABEL org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"
```

CI (GitLab shown; GitHub Actions is the same with `github.ref_name` /
`github.sha`) — note the single variable feeding both the image tag and the
build argument, so the two can never disagree:

```yaml
- export APP_VERSION="${CI_COMMIT_TAG:-$CI_COMMIT_SHORT_SHA}"
- export IMAGE="$REGISTRY/$PROJECT:$APP_VERSION"
- >-
  docker build
  --build-arg APP_VERSION="$APP_VERSION"
  --build-arg VCS_REF="$CI_COMMIT_SHA"
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  -t "$IMAGE" .
```

In a Laravel application, read it in `config/app.php` — `env()` must be called
inside the config file, because `php artisan config:cache` does not load `.env`
at all and a runtime `env()` would return `null` silently, only in production:

```php
'version' => env('APP_VERSION') ?: null,
```

Two traps worth stating outright:

- **Do not put `APP_VERSION` in `.env`.** Laravel's dotenv is immutable and
  leaves an already-set process variable alone, so the value baked into the
  image always wins and the `.env` entry is ignored without a word.
- **Keep the version a property of the artifact, not of the run.** Passing it
  as a runtime environment variable instead of a build argument means the same
  image reports different versions depending on how it was started.

What a running container actually is:

```bash
docker inspect <container> --format '{{index .Config.Labels "org.opencontainers.image.version"}}'
```

## Development

```bash
composer install
composer analyse         # PHPStan, level max
composer test            # PHPUnit smoke tests for the plugin wiring
composer test-shell      # bats end-to-end tests for the release script
```

The two suites stay separate commands on purpose: `composer test` needs only
PHP, while `test-shell` needs [bats](https://bats-core.readthedocs.io) and runs
the actual script against throwaway git repositories.

## License

MIT
