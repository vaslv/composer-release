#!/usr/bin/env bats
# Run: bats tests/release.bats  (https://bats-core.readthedocs.io)
#
# Each test runs bin/release inside a throwaway git repo with a composer shim
# on PATH, so the suite needs git + bash only.

setup() {
    TMP_REPO="$(mktemp -d)"
    cd "$TMP_REPO"
    git init -q -b main .
    git config user.email test@example.com
    git config user.name test
    printf '{"name":"acme/app"}\n' > composer.json
    git add -A
    git commit -qm init

    # composer shim: "composer config version X" rewrites composer.json,
    # everything else is a no-op — keeps the suite hermetic. Lives OUTSIDE
    # the repo so the dirty-tree guard doesn't see it as an untracked file.
    SHIM_DIR="$(mktemp -d)"
    cat > "$SHIM_DIR/composer" <<'SHIM'
#!/bin/sh
if [ "$1" = "config" ] && [ "$2" = "version" ]; then
    printf '{"name":"acme/app","version":"%s"}\n' "$3" > composer.json
fi
exit 0
SHIM
    chmod +x "$SHIM_DIR/composer"
    export PATH="$SHIM_DIR:$PATH"

    RELEASE="$BATS_TEST_DIRNAME/../bin/release"
}

teardown() {
    rm -rf "$TMP_REPO" "$SHIM_DIR"
}

@test "picks highest version across v-prefixed and bare tags" {
    git tag 2.0.0
    git tag v0.1.0
    run bash -c "printf 'q\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current version: 2.0.0"* ]]
}

@test "numeric (not lexical) ordering: 1.10.0 beats 1.9.0, prefix preserved" {
    git tag v1.9.0
    git tag v1.10.0
    run bash -c "printf 'q\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current version: v1.10.0"* ]]
}

@test "no tags falls back to 0.0.0" {
    run bash -c "printf 'q\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Starting from 0.0.0"* ]]
}

@test "tags with leading-zero components are ignored, not crashing" {
    git tag v1.0.08
    run bash -c "printf 'q\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Starting from 0.0.0"* ]]
    [[ "$output" != *"value too great for base"* ]]
}

@test "refuses to run on detached HEAD" {
    git checkout -q --detach
    run bash -c "printf 'q\n' | '$RELEASE'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"detached HEAD"* ]]
}

commit_version_field() {
    printf '{"name":"acme/app","version":"%s"}\n' "$1" > composer.json
    git add composer.json
    git commit -qm 'track version field'
}

@test "no version field: tag-only release, composer.json untouched" {
    git tag v0.1.0
    head_before="$(git rev-parse HEAD)"
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"creating tag only"* ]]
    git rev-parse -q --verify refs/tags/v0.1.1
    [ "$(git rev-parse HEAD)" = "$head_before" ]
    [ -z "$(git status --porcelain)" ]
}

@test "committed version field is bumped and committed" {
    commit_version_field 0.1.0
    git tag v0.1.0
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    git rev-parse -q --verify refs/tags/v0.1.1
    grep -q '"version":"0.1.1"' composer.json
    [ "$(git log -1 --format=%s)" = "chore(release): v0.1.1" ]
    [ -z "$(git status --porcelain)" ]
}

@test "failed commit leaves working tree clean and creates no tag" {
    commit_version_field 0.1.0
    git tag v0.1.0
    printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -ne 0 ]
    [ -z "$(git status --porcelain)" ]
    ! git rev-parse -q --verify refs/tags/v0.1.1
}

@test "rerun after failed tag step skips the commit and still tags" {
    commit_version_field 0.1.0
    git tag v0.1.0
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    git tag -d v0.1.1 >/dev/null
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping commit"* ]]
    git rev-parse -q --verify refs/tags/v0.1.1
}

@test "custom entry of an existing version is rejected before any mutation" {
    git tag v0.1.0
    run bash -c "printf '4\n0.1.0\n' | '$RELEASE'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
    [ -z "$(git status --porcelain)" ]
}
