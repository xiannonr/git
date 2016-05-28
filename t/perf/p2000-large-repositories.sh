#!/bin/sh

test_description="Benchmarking Git operations with large repositories"

. ./perf-lib.sh

file_count=1000
test -z "$GIT_TEST_LONG" || file_count="30000"
test -z "$P2000_FILE_COUNT" || file_count="$P2000_FILE_COUNT"

test_expect_success 'setup' '
	git init &&
	test-mock-branch --seed=$file_count --target-file-count=$file_count \
		--ref-name=refs/heads/x$file_count |
	git fast-import &&
	test-mock-branch --seed=-$file_count --target-file-count=$file_count \
		--ref-name=refs/heads/y$file_count |
	git fast-import
'

export file_count
test_expect_success 'initial checkout' 'git reset --hard y$file_count'

test_perf 'checkout files (x2)' '
	git checkout --no-progress x$file_count &&
	git checkout --no-progress y$file_count
'

test_perf 'status' '
	git status
'

test_done
