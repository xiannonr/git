#!/bin/sh
#
# Copyright (c) 2016, Twitter, Inc
#

test_description='git-index-helper

Testing git index-helper
'

. ./test-lib.sh

test_expect_success 'index-helper creates usable pid file and can be killed' '
	test_path_is_missing .git/index-helper.pid &&
	git index-helper --detach &&
	test_path_is_file .git/index-helper.pid &&
	pid=$(sed s/[^0-9]//g .git/index-helper.pid) &&
	kill -0 $pid &&
	git index-helper --kill &&
	! kill -0 $pid
'

test_done
