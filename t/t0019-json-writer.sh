#!/bin/sh

test_description='test json-writer JSON generation'
. ./test-lib.sh

test_expect_success 'unit test of json-writer routines' '
	test-json-writer -u
'

test_expect_success 'trivial object' '
	cat >expect <<-\EOF &&
	{}
	EOF
	test-json-writer >actual \
		@object \
		@end &&
	test_cmp expect actual
'

test_expect_success 'trivial array' '
	cat >expect <<-\EOF &&
	[]
	EOF
	test-json-writer >actual \
		@array \
		@end &&
	test_cmp expect actual
'

test_expect_success 'simple object' '
	cat >expect <<-\EOF &&
	{"a":"abc","b":42,"c":3.14,"d":true,"e":false,"f":null}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-double %.2f c 3.140 \
			@object-true d \
			@object-false e \
			@object-null f \
		@end &&
	test_cmp expect actual
'

test_expect_success 'simple array' '
	cat >expect <<-\EOF &&
	["abc",42,3.14,true,false,null]
	EOF
	test-json-writer >actual \
		@array \
			@array-string abc \
			@array-int 42 \
			@array-double %.2f 3.140 \
			@array-true \
			@array-false \
			@array-null \
		@end &&
	test_cmp expect actual
'

test_expect_success 'nested inline object' '
	cat >expect <<-\EOF &&
	{"a":"abc","b":42,"sub1":{"c":3.14,"d":true,"sub2":{"e":false,"f":null}}}
	EOF
	test-json-writer >actual \
		@object \
			@object-string a abc \
			@object-int b 42 \
			@object-object "sub1" \
				@object-double %.2f c 3.140 \
				@object-true d \
				@object-object "sub2" \
					@object-false e \
					@object-null f \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_expect_success 'nested inline array' '
	cat >expect <<-\EOF &&
	["abc",42,[3.14,true,[false,null]]]
	EOF
	test-json-writer >actual \
		@array \
			@array-string abc \
			@array-int 42 \
			@array-array \
				@array-double %.2f 3.140 \
				@array-true \
				@array-array \
					@array-false \
					@array-null \
				@end \
			@end \
		@end &&
	test_cmp expect actual
'

test_done
