#!/bin/sh

test_description="Benchmarking Git operations with large repositories"

. ./perf-lib.sh

# We do not really work with large repositories here, but instead use smaller
# repositories and then extrapolate the performance characteristics. This makes
# testing more efficient, both in terms of storage and in terms of runtime.

sizes="50 150 300"
test -z "$GIT_TEST_LONG" || sizes="500 1500 3000"

test_expect_success 'setup' '
	git init &&
	for count in $sizes
	do
		sha1=$(test-mock-branch --target-file-count=$count) &&
		git branch f$count $sha1 ||
		exit
	done
'

for count in $sizes
do
	export count
	test_perf "checkout $count files" '
		rm -rf .git/index * &&
		git checkout f$count
	'
done

test_done
