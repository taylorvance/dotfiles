#!/usr/bin/env bats
# @covers src/dotfiles/.claude/scripts/pr-feedback.mjs

setup() {
    export TEST_DIR
    TEST_DIR=$(mktemp -d)
    mkdir -p "$TEST_DIR/bin"
    export PATH="$TEST_DIR/bin:$PATH"
    SCRIPT="$BATS_TEST_DIRNAME/../../src/dotfiles/.claude/scripts/pr-feedback.mjs"

    cat > "$TEST_DIR/bin/gh" <<'EOF'
#!/bin/sh

if [ "$1 $2" = "repo view" ]; then
    printf '%s\n' '{"owner":{"login":"octo"},"name":"repo"}'
    exit 0
fi

query="" cursor="" id=""
for arg in "$@"; do
    case "$arg" in
        query=*) query=${arg#query=} ;;
        cursor=*) cursor=${arg#cursor=} ;;
        id=*) id=${arg#id=} ;;
    esac
done

connection() {
    printf '{"nodes":[{"id":"%s"}],"pageInfo":{"hasNextPage":%s,"endCursor":%s}}' "$1" "$2" "$3"
}

case "$query" in
    *'... on PullRequestReviewThread'*)
        if [ "$id" = "T1" ] && [ -z "$cursor" ]; then
            value=$(connection TC1 true '"TC_NEXT"')
        elif [ "$id" = "T1" ]; then
            value=$(connection TC2 false null)
        elif [ "$id" = "T3" ]; then
            value=$(connection TC3 false null)
        else
            value=$(connection TC_RESOLVED false null)
        fi
        printf '{"data":{"node":{"comments":%s}}}\n' "$value"
        ;;
    *'reviewThreads(first:'*)
        if [ -z "$cursor" ]; then
            value='{"nodes":[{"id":"T1","isResolved":false,"isOutdated":false}],"pageInfo":{"hasNextPage":true,"endCursor":"T_NEXT"}}'
        else
            value='{"nodes":[{"id":"T2","isResolved":true,"isOutdated":false},{"id":"T3","isResolved":false,"isOutdated":true}],"pageInfo":{"hasNextPage":false,"endCursor":null}}'
        fi
        printf '{"data":{"repository":{"pullRequest":{"reviewThreads":%s}}}}\n' "$value"
        ;;
    *'reviews(first:'*)
        if [ -z "$cursor" ]; then value=$(connection R1 true '"R_NEXT"')
        else value='{"nodes":[{"id":"R2"},{"id":"RB","author":{"login":"semanticdiff-com","__typename":"Bot"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}'; fi
        printf '{"data":{"repository":{"pullRequest":{"reviews":%s}}}}\n' "$value"
        ;;
    *'comments(first:'*)
        if [ -z "$cursor" ]; then value=$(connection C1 true '"C_NEXT"')
        else value='{"nodes":[{"id":"C2"},{"id":"CB","author":{"login":"cypress","__typename":"Bot"}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}'; fi
        printf '{"data":{"repository":{"pullRequest":{"comments":%s}}}}\n' "$value"
        ;;
    *)
        printf '%s\n' '{"errors":[{"message":"unexpected query"}]}'
        ;;
esac
EOF
    chmod +x "$TEST_DIR/bin/gh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "pr-feedback paginates root and nested feedback connections" {
    run node "$SCRIPT" 42

    [ "$status" -eq 0 ]
    for id in C1 C2 R1 R2 T1 T2 T3 TC1 TC2 TC3 TC_RESOLVED; do
        [[ "$output" == *"\"$id\""* ]]
    done
}

@test "pr-feedback drops bot comments and reviews and reports the omission" {
    run node "$SCRIPT" 42

    [ "$status" -eq 0 ]
    for id in CB RB; do
        [[ "$output" != *"\"$id\""* ]]
    done
    [[ "$output" == *botFeedbackOmitted* ]]
}

@test "pr-feedback rejects a flag before calling gh" {
    run node "$SCRIPT" --unresolved

    [ "$status" -eq 1 ]
    [ "$output" = "unknown flag: --unresolved (usage: pr-feedback.mjs [PR_NUMBER])" ]
}

@test "pr-feedback rejects an invalid explicit PR number before calling gh" {
    run node "$SCRIPT" nope

    [ "$status" -eq 1 ]
    [ "$output" = "invalid PR number: nope" ]
}
