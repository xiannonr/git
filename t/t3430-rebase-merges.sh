#!/bin/sh
#
# Copyright (c) 2018 Johannes E. Schindelin
#

test_description='git rebase -i --rebase-merges

This test runs git rebase "interactively", retaining the branch structure by
recreating merge commits.

Initial setup:

    -- B --                   (first)
   /       \
 A - C - D - E - H            (master)
       \       /
         F - G                (second)
'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_cmp_graph () {
	cat >expect &&
	git log --graph --boundary --format=%s "$@" >output &&
	sed "s/ *$//" <output >output.trimmed &&
	test_cmp expect output.trimmed
}

test_expect_success 'setup' '
	write_script replace-editor.sh <<-\EOF &&
	mv "$1" "$(git rev-parse --git-path ORIGINAL-TODO)"
	cp script-from-scratch "$1"
	EOF

	test_commit A &&
	git checkout -b first &&
	test_commit B &&
	git checkout master &&
	test_commit C &&
	test_commit D &&
	git merge --no-commit B &&
	test_tick &&
	git commit -m E &&
	git tag -m E E &&
	git checkout -b second C &&
	test_commit F &&
	test_commit G &&
	git checkout master &&
	git merge --no-commit G &&
	test_tick &&
	git commit -m H &&
	git tag -m H H
'

test_expect_success 'create completely different structure' '
	cat >script-from-scratch <<-\EOF &&
	label onto

	# onebranch
	pick G
	pick D
	label onebranch

	# second
	reset onto
	pick B
	label second

	reset onto
	merge -C H second
	merge onebranch # Merge the topic branch '\''onebranch'\''
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	git rebase -i -r A &&
	test_cmp_graph <<-\EOF
	*   Merge the topic branch '\''onebranch'\''
	|\
	| * D
	| * G
	* |   H
	|\ \
	| |/
	|/|
	| * B
	|/
	* A
	EOF
'

test_expect_success 'generate correct todo list' '
	cat >expect <<-\EOF &&
	label onto

	reset onto
	pick d9df450 B
	label E

	reset onto
	pick 5dee784 C
	label branch-point
	pick ca2c861 F
	pick 088b00a G
	label H

	reset branch-point # C
	pick 12bd07b D
	merge -R -C 2051b56 E # E
	merge -R -C 233d48a H # H

	EOF

	grep -v "^#" <.git/ORIGINAL-TODO >output &&
	test_cmp expect output
'

test_expect_success '`reset` refuses to overwrite untracked files' '
	git checkout -b refuse-to-reset &&
	test_commit dont-overwrite-untracked &&
	git checkout @{-1} &&
	: >dont-overwrite-untracked.t &&
	echo "reset refs/tags/dont-overwrite-untracked" >script-from-scratch &&
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_must_fail git rebase -r HEAD &&
	git rebase --abort
'

test_expect_success 'failed `merge` writes patch (may be rescheduled, too)' '
	test_when_finished "test_might_fail git rebase --abort" &&
	git checkout -b conflicting-merge A &&

	: fail because of conflicting untracked file &&
	>G.t &&
	echo "merge -C H G" >script-from-scratch &&
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	test_must_fail git rebase -ir HEAD &&
	grep "^merge -C .* G$" .git/rebase-merge/done &&
	grep "^merge -C .* G$" .git/rebase-merge/git-rebase-todo &&
	test_path_is_file .git/rebase-merge/patch &&

	: fail because of merge conflict &&
	rm G.t .git/rebase-merge/patch &&
	git reset --hard &&
	test_commit conflicting-G G.t not-G conflicting-G &&
	test_must_fail git rebase --continue &&
	! grep "^merge -C .* G$" .git/rebase-merge/git-rebase-todo &&
	test_path_is_file .git/rebase-merge/patch
'

test_expect_success 'with a branch tip that was cherry-picked already' '
	git checkout -b already-upstream master &&
	base="$(git rev-parse --verify HEAD)" &&

	test_commit A1 &&
	test_commit A2 &&
	git reset --hard $base &&
	test_commit B1 &&
	test_tick &&
	git merge -m "Merge branch A" A2 &&

	git checkout -b upstream-with-a2 $base &&
	test_tick &&
	git cherry-pick A2 &&

	git checkout already-upstream &&
	test_tick &&
	git rebase -i -r upstream-with-a2 &&
	test_cmp_graph upstream-with-a2.. <<-\EOF
	*   Merge branch A
	|\
	| * A1
	* | B1
	|/
	o A2
	EOF
'

test_expect_success 'do not rebase cousins unless asked for' '
	git checkout -b cousins master &&
	before="$(git rev-parse --verify HEAD)" &&
	test_tick &&
	git rebase -r HEAD^ &&
	test_cmp_rev HEAD $before &&
	test_tick &&
	git rebase --rebase-merges=rebase-cousins HEAD^ &&
	test_cmp_graph HEAD^.. <<-\EOF
	*   Merge the topic branch '\''onebranch'\''
	|\
	| * D
	| * G
	|/
	o H
	EOF
'

test_expect_success 'refs/rewritten/* is worktree-local' '
	git worktree add wt &&
	cat >wt/script-from-scratch <<-\EOF &&
	label xyz
	exec GIT_DIR=../.git git rev-parse --verify refs/rewritten/xyz >a || :
	exec git rev-parse --verify refs/rewritten/xyz >b
	EOF

	test_config -C wt sequence.editor \""$PWD"/replace-editor.sh\" &&
	git -C wt rebase -i HEAD &&
	test_must_be_empty wt/a &&
	test_cmp_rev HEAD "$(cat wt/b)"
'

test_expect_success 'post-rewrite hook and fixups work for merges' '
	git checkout -b post-rewrite &&
	test_commit same1 &&
	git reset --hard HEAD^ &&
	test_commit same2 &&
	git merge -m "to fix up" same1 &&
	echo same old same old >same2.t &&
	test_tick &&
	git commit --fixup HEAD same2.t &&
	fixup="$(git rev-parse HEAD)" &&

	mkdir -p .git/hooks &&
	test_when_finished "rm .git/hooks/post-rewrite" &&
	echo "cat >actual" | write_script .git/hooks/post-rewrite &&

	test_tick &&
	git rebase -i --autosquash -r HEAD^^^ &&
	printf "%s %s\n%s %s\n%s %s\n%s %s\n" >expect $(git rev-parse \
		$fixup^^2 HEAD^2 \
		$fixup^^ HEAD^ \
		$fixup^ HEAD \
		$fixup HEAD) &&
	test_cmp expect actual
'

test_expect_success 'refuse to merge ancestors of HEAD' '
	echo "merge HEAD^" >script-from-scratch &&
	test_config -C wt sequence.editor \""$PWD"/replace-editor.sh\" &&
	before="$(git rev-parse HEAD)" &&
	git rebase -i HEAD &&
	test_cmp_rev HEAD $before
'

test_expect_success 'root commits' '
	git checkout --orphan unrelated &&
	(GIT_AUTHOR_NAME="Parsnip" GIT_AUTHOR_EMAIL="root@example.com" \
	 test_commit second-root) &&
	test_commit third-root &&
	cat >script-from-scratch <<-\EOF &&
	pick third-root
	label first-branch
	reset [new root]
	pick second-root
	merge first-branch # Merge the 3rd root
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	git rebase -i --force --root -r &&
	test "Parsnip" = "$(git show -s --format=%an HEAD^)" &&
	test $(git rev-parse second-root^0) != $(git rev-parse HEAD^) &&
	test $(git rev-parse second-root:second-root.t) = \
		$(git rev-parse HEAD^:second-root.t) &&
	test_cmp_graph HEAD <<-\EOF &&
	*   Merge the 3rd root
	|\
	| * third-root
	* second-root
	EOF

	: fast forward if possible &&
	before="$(git rev-parse --verify HEAD)" &&
	test_might_fail git config --unset sequence.editor &&
	test_tick &&
	git rebase -i --root -r &&
	test_cmp_rev HEAD $before
'

test_expect_success 'a "merge" into a root commit is a fast-forward' '
	head=$(git rev-parse HEAD) &&
	cat >script-from-scratch <<-EOF &&
	reset [new root]
	merge $head
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	git rebase -i -r HEAD^ &&
	test_cmp_rev HEAD $head
'

test_expect_success 'A root commit can be a cousin, treat it that way' '
	git checkout --orphan khnum &&
	test_commit yama &&
	git checkout -b asherah master &&
	test_commit shamkat &&
	git merge --allow-unrelated-histories khnum &&
	test_tick &&
	git rebase -f -r HEAD^ &&
	! test_cmp_rev HEAD^2 khnum &&
	test_cmp_graph HEAD^.. <<-\EOF &&
	*   Merge branch '\''khnum'\'' into asherah
	|\
	| * yama
	o shamkat
	EOF
	test_tick &&
	git rebase --rebase-merges=rebase-cousins HEAD^ &&
	test_cmp_graph HEAD^.. <<-\EOF
	*   Merge branch '\''khnum'\'' into asherah
	|\
	| * yama
	|/
	o shamkat
	EOF
'

test_expect_success 'octopus merges' '
	git checkout -b three &&
	test_commit before-octopus &&
	test_commit three &&
	git checkout -b two HEAD^ &&
	test_commit two &&
	git checkout -b one HEAD^ &&
	test_commit one &&
	test_tick &&
	(GIT_AUTHOR_NAME="Hank" GIT_AUTHOR_EMAIL="hank@sea.world" \
	 git merge -m "Tüntenfüsch" two three) &&

	: fast forward if possible &&
	before="$(git rev-parse --verify HEAD)" &&
	test_tick &&
	git rebase -i -r HEAD^^ &&
	test_cmp_rev HEAD $before &&

	test_tick &&
	git rebase -i --force -r HEAD^^ &&
	test "Hank" = "$(git show -s --format=%an HEAD)" &&
	test "$before" != $(git rev-parse HEAD) &&
	test_cmp_graph HEAD^^.. <<-\EOF
	*-.   Tüntenfüsch
	|\ \
	| | * three
	| * | two
	| |/
	* | one
	|/
	o before-octopus
	EOF
'

test_expect_success 'rebase amended merges' '
	git checkout -b amended-merge A &&
	test_commit common &&
	test_commit file1 &&
	git reset --hard HEAD^ &&
	test_commit file2 &&
	git merge -m merge file1 &&
	echo extra >>file1.t &&
	git commit --amend -m amended file1.t &&
	git rebase -i -r -f common &&
	grep extra file1.t
'

test_cmp_diff () {
	q_to_tab >expect &&
	git diff >actual.diff &&
	sed -e 's/^\(..[<>]* \)[0-9a-f]*\.\.\. /\1<HASH>... /' \
		-e '/^index /d' -e 's/ *$//' \
		<actual.diff >actual &&
	test_cmp expect actual
}

# This test case reflects a real-world scenario, where a function was renamed
# in one topic branch, a caller for the same function was added in a competing
# topic branch, and upstream introduces conflicting changes for one or the
# other, or both.
test_expect_success 'rebase merge commit (realistic example)' '
	git checkout --orphan rebase-merge &&
	q_to_tab >main.c <<-\EOF &&
	int core(void) {
	Qprintf("Hello, world!\n");
	}
	EOF
	test_tick && git add main.c && git commit -m main &&
	git checkout -b add-caller &&
	q_to_tab >>main.c <<-\EOF &&
	/* caller */
	void caller(void) {
	Qcore();
	}
	EOF
	test_tick && git commit -m add-caller -a &&
	git checkout rebase-merge &&
	mv main.c main.c.orig &&
	sed "s/core/hi/g" <main.c.orig >main.c &&
	test_tick && git commit -m rename-to-hi -a &&
	git merge --no-commit add-caller &&
	mv main.c main.c.orig &&
	sed "s/core/hi/g" <main.c.orig >main.c &&
	test_tick && git -c core.editor=touch commit -a &&
	test_cmp_graph <<-\EOF &&
	*   Merge branch '\''add-caller'\'' into rebase-merge
	|\
	| * add-caller
	* | rename-to-hi
	|/
	* main
	EOF

	: now simulate upstream coming up with conflicting changes for &&
	: the rename, for the added function, and for both &&
	git worktree add -b add-event-loop upstream add-caller^ &&
	(
		cd upstream &&
		q_to_tab >>main.c <<-\EOF &&
		/* main event loop */
		void event_loop(void) {
		Q/* TODO: place holder for now */
		}
		EOF
		test_tick && git commit -m add-event-loop -a &&

		git checkout -b rename-to-greeting add-caller^ &&
		mv main.c main.c.orig &&
		sed "s/core/greeting/g" <main.c.orig >main.c &&
		test_tick && git commit -m rename-to-greeting -a &&

		git checkout -b two-conflicts &&
		q_to_tab >>main.c <<-\EOF &&
		/* main code */
		int main(int argc, char **argv) {
		Qreturn greeting();
		}
		EOF
		test_tick && git commit -m add-main -a
	) &&

	: now, rebase onto all three of those conflicting upstream branches &&
	: first, just the renamed function: &&
	: rename-to-hi must clash with rename-to-greeting &&
	git checkout -b rebase-1 &&
	test_must_fail git rebase -ir rename-to-greeting &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,3 -1,3 +1,7 @@@
	++<<<<<<< HEAD
	 +int greeting(void) {
	++=======
	+ int hi(void) {
	++>>>>>>> <HASH>... rename-to-hi
	  Qprintf("Hello, world!\n");
	  }
	EOF
	: re-rename-to-hi &&
	git checkout --theirs main.c &&
	test_tick && git add main.c && test_must_fail git rebase --continue &&
	: the rebased add-caller still uses greeting instead of hi &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,4 -1,4 +1,8 @@@
	++<<<<<<< intermediate merge
	 +int hi(void) {
	++=======
	+ int greeting(void) {
	++>>>>>>> <HASH>... merge head #1
	  Qprintf("Hello, world!\n");
	  }
	  /* caller */
	EOF
	: use hi, i.e. the version in the rebased history so far &&
	git checkout --ours main.c &&
	test_tick && git add main.c && git rebase --continue &&
	test_cmp_graph <<-\EOF &&
	*   Merge branch '\''add-caller'\'' into rebase-merge
	|\
	| * add-caller
	* | rename-to-hi
	|/
	* rename-to-greeting
	* main
	EOF

	: second, cause conflict with the added event loop &&
	git checkout -b rebase-2 rebase-merge &&
	test_must_fail git rebase -ir add-event-loop &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,7 -1,7 +1,13 @@@
	  int core(void) {
	  Qprintf("Hello, world!\n");
	  }
	++<<<<<<< HEAD
	 +/* main event loop */
	 +void event_loop(void) {
	 +Q/* TODO: place holder for now */
	++=======
	+ /* caller */
	+ void caller(void) {
	+ Qcore();
	++>>>>>>> <HASH>... add-caller
	  }
	EOF
	: resolve by adding both &&
	mv main.c main.c.orig &&
	sed -e "s/^=.*/}/" -e "/^[<>]/d" <main.c.orig >main.c &&
	test_tick && git add main.c && test_must_fail git rebase --continue &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,7 -1,7 +1,20 @@@
	  int hi(void) {
	  Qprintf("Hello, world!\n");
	  }
	++<<<<<<< intermediate merge
	++<<<<<<<< HEAD
	 +/* main event loop */
	 +void event_loop(void) {
	 +Q/* TODO: place holder for now */
	++========
	++=======
	++/* main event loop */
	++void event_loop(void) {
	++Q/* TODO: place holder for now */
	++}
	++>>>>>>> <HASH>... merge head #1
	+ /* caller */
	+ void caller(void) {
	+ Qhi();
	++>>>>>>>> <HASH>... original merge
	  }
	EOF
	: HEAD renamed core to hi, MERGE_HEAD did more complicated stuff... &&
	git show MERGE_HEAD:main.c | sed "s/core/hi/g" >main.c &&
	git add main.c &&
	test_tick &&
	git rebase --continue &&
	test_cmp_graph <<-\EOF &&
	*   Merge branch '\''add-caller'\'' into rebase-merge
	|\
	| * add-caller
	* | rename-to-hi
	|/
	* add-event-loop
	* main
	EOF

	: third, cause conflict with the added event loop and the rename &&
	git checkout -b rebase-3 rebase-merge &&
	test_must_fail git rebase -ir two-conflicts &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,7 -1,7 +1,13 @@@
	 -int core(void) {
	 +int greeting(void) {
	  Qprintf("Hello, world!\n");
	  }
	++<<<<<<< HEAD
	 +/* main code */
	 +int main(int argc, char **argv) {
	 +Qreturn greeting();
	++=======
	+ /* caller */
	+ void caller(void) {
	+ Qcore();
	++>>>>>>> <HASH>... add-caller
	  }
	EOF
	: resolve by adding both &&
	mv main.c main.c.orig &&
	sed -e "s/^=.*/}/" -e "/^[<>]/d" <main.c.orig >main.c &&
	test_tick && git add main.c && test_must_fail git rebase --continue &&
	: now the renames conflict &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,7 -1,3 +1,11 @@@
	++<<<<<<< HEAD
	 +int greeting(void) {
	++=======
	+ int hi(void) {
	++>>>>>>> <HASH>... rename-to-hi
	  Qprintf("Hello, world!\n");
	  }
	 +/* main code */
	 +int main(int argc, char **argv) {
	 +Qreturn greeting();
	 +}
	EOF
	: again, we prefer our rename to hi &&
	git checkout --theirs main.c &&
	test_tick && git add main.c && test_must_fail git rebase --continue &&
	: HEAD renamed core to hi, MERGE_HEAD did more complicated stuff... &&
	test_cmp_diff <<-\EOF &&
	diff --cc main.c
	--- a/main.c
	+++ b/main.c
	@@@ -1,7 -1,11 +1,15 @@@
	++<<<<<<< intermediate merge
	 +int hi(void) {
	++=======
	+ int greeting(void) {
	++>>>>>>> <HASH>... merge head #1
	  Qprintf("Hello, world!\n");
	  }
	+ /* main code */
	+ int main(int argc, char **argv) {
	+ Qreturn greeting();
	+ }
	  /* caller */
	  void caller(void) {
	 -Qcore();
	 +Qhi();
	  }
	EOF
	: we really wanted hi, not greeting... &&
	mv main.c main.c.orig &&
	sed -e "/^[=<>]/d" -e "/^int greeting/d" -e "s/greeting/hi/g" \
		<main.c.orig >main.c &&
	git add main.c &&
	test_tick && git rebase --continue &&
	test_cmp_graph <<-\EOF
	*   Merge branch '\''add-caller'\'' into rebase-merge
	|\
	| * add-caller
	* | rename-to-hi
	|/
	* add-main
	* rename-to-greeting
	* main
	EOF
'

test_done
