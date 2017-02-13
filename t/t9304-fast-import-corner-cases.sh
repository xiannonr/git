#!/bin/sh
test_description='test git fast-import corner cases'
. ./test-lib.sh

test_expect_success 'duplicate objects on import' '
	test_tick &&
	cat >input <<-INPUT_END &&
	blob
	mark :1
	data 13
	Hello world!

	blob
	mark :2
	data 13
	Hello world!

	commit refs/heads/master
	committer $GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL> $GIT_COMMITTER_DATE
	data <<COMMIT
	initial
	COMMIT
	M 100644 :1 hello.txt
	M 100644 :2 world.txt

	done
	INPUT_END

	git -c fastimport.unpacklimit=0 fast-import --done <input &&
	git fsck --no-progress &&
	git show-index <.git/objects/pack/*.idx >output &&
	grep "$(git rev-parse --verify HEAD:hello.txt)" <output >grepped &&
	test_line_count = 1 grepped
'

test_done

