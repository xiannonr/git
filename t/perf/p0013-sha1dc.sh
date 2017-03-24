#!/bin/sh

test_description="Tests performance of SHA1DC vs OpenSSL"

. ./perf-lib.sh

test -n "$DC_AND_OPENSSL_SHA1" || {
	skip_all='DC_AND_OPENSSL_SHA1 required for this test'
	test_done
}

test_perf 'calculate SHA-1 for 300MB (SHA1DC)' '
	dd if=/dev/zero bs=1M count=300 |
	test-sha1
'

test_perf 'calculate SHA-1 for 300MB (OpenSSL)' '
	dd if=/dev/zero bs=1M count=300 |
	test-sha1 --disable-sha1dc
'

test_done

