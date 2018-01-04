#!/bin/sh

test_description='colored git blame'
. ./test-lib.sh

PROG='git blame -c'
. "$TEST_DIRECTORY"/annotate-tests.sh

test_expect_success 'colored blame colors contiguous lines' '
	git blame --abbrev=12 --color-lines hello.c >actual.raw &&
	test_decode_color <actual.raw >actual &&
	grep "<BOLD;BLACK>(F" actual > F.expect &&
	grep "<BOLD;BLACK>(H" actual > H.expect &&
	test_line_count = 2 F.expect &&
	test_line_count = 3 H.expect
'

test_done
