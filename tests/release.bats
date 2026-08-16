#!/usr/bin/env bats
# Run: bats tests/release.bats  (https://bats-core.readthedocs.io)
#
# Each test runs bin/release inside a throwaway git repo, so the suite needs
# git + bash only. The script never shells out to composer, so there is nothing
# to stub.

setup() {
    TMP_REPO="$(mktemp -d)"
    cd "$TMP_REPO"
    git init -q -b main .
    git config user.email test@example.com
    git config user.name test
    printf '{"name":"acme/app"}\n' > composer.json
    git add -A
    git commit -qm init

    RELEASE="$BATS_TEST_DIRNAME/../bin/release"
}

teardown() {
    rm -rf "$TMP_REPO"
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

@test "release is tag-only: no commit, working tree untouched" {
    git tag v0.1.0
    head_before="$(git rev-parse HEAD)"
    count_before="$(git rev-list --count HEAD)"
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing in the working tree changed"* ]]
    git rev-parse -q --verify refs/tags/v0.1.1
    [ "$(git rev-parse HEAD)" = "$head_before" ]
    [ "$(git rev-list --count HEAD)" = "$count_before" ]
    [ -z "$(git status --porcelain)" ]
}

@test "a committed version field is warned about, never rewritten" {
    commit_version_field 0.1.0
    git tag v0.1.0
    head_before="$(git rev-parse HEAD)"
    before="$(cat composer.json)"
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'still commits a "version" field'* ]]
    git rev-parse -q --verify refs/tags/v0.1.1
    [ "$(cat composer.json)" = "$before" ]
    [ "$(git rev-parse HEAD)" = "$head_before" ]
    [ -z "$(git status --porcelain)" ]
}

@test "a repo without composer.json releases without a stray grep error" {
    git rm -q composer.json
    git commit -qm 'drop composer.json'
    git tag v0.1.0
    run bash -c "printf '1\ny\n' | '$RELEASE'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"No such file"* ]]
    git rev-parse -q --verify refs/tags/v0.1.1
}

@test "custom entry of an existing version is rejected before any mutation" {
    git tag v0.1.0
    run bash -c "printf '4\n0.1.0\n' | '$RELEASE'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
    [ -z "$(git status --porcelain)" ]
}
