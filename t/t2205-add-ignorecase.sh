#!/bin/sh

test_description='adding files, ignoring the case of the file names'

. ./test-lib.sh

if test_have_prereq !CASE_INSENSITIVE_FS
then
	skip_all="skipping tests requiring a case-insensitive file system"
	test_done
fi

test_expect_success setup '
	test_config core.ignoreCase true &&
	mkdir CaseDir &&
	test_commit CaseDir/File &&
	git ls-files >out &&
	grep CaseDir/File out
'

test_expect_failure 'add directory using different case than previously' '
	echo 1 >CaseDir/One &&
	git add casedir/. &&
	git ls-files >out &&
	grep OneDir/One out
'

test_done

