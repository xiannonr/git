#!/bin/sh
#
# Copyright (c) 2016, Twitter, Inc
#

test_description='git-index-helper

Testing git index-helper
'

. ./test-lib.sh

git index-helper -h 2>/dev/null
test $? = 129 ||
{
	skip_all='skipping index-helper tests: no index-helper executable'
	test_done
}

test_expect_success 'index-helper smoke test' '
	git index-helper --exit-after 1 &&
	test_path_is_missing .git/index-helper.sock
'

test_done
