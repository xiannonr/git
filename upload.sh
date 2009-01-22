#!/bin/sh

# This is a simple script that will produce my blog on repo.or.cz

# The idea is to have source-<timestamp>.txt files as input, having the
# stories, and this script turning them into nice HTML, committing
# everything, and then pushing it to my repository.

# The blog will then be served using gitweb.

# To make it easier on me, if a file "source.txt" exists, it is
# automatically renamed using the current timestamp.

# TODO: handle images (git add them and rewrite the URL dynamically)
# TODO: generate an RSS feed, too

BRANCH=blog
URL="dscho.git?a=blob_plain;hb=$BRANCH;f="
CSS=blog.css
NEW=new
OUTPUT=index.html
TITLE="Dscho's blog"

LC_ALL=C
export LC_ALL

die () {
	echo "$*" >&2
	exit 1
}

nth () {
	# add illogical suffix
	case "$1" in
	*1?|*[04-9]) echo "$1th";;
	*1) echo "$1st";;
	*2) echo "$1nd";;
	*3) echo "$1rd";;
	esac
}

make_chinese_hour () {
	case $1 in
	23|00) echo Rat;;
	01|02) echo Buffalo;;
	03|04) echo Tiger;;
	05|06) echo Rabbit;;
	07|08) echo Dragon;;
	09|10) echo Snake;;
	11|12) echo Horse;;
	13|14) echo Goat;;
	15|16) echo Monkey;;
	17|18) echo Rooster;;
	19|20) echo Dog;;
	21|22) echo Pig;;
	esac
}

digit_to_roman () {
	case $1 in
	1) echo $2;;
	2) echo $2$2;;
	3) echo $2$2$2;;
	4) echo $2$3;;
	5) echo $3;;
	6) echo $3$2;;
	7) echo $3$2$2;;
	8) echo $3$2$2$2;;
	9) echo $2$4;;
	esac
}

make_roman_number () {
	case $1 in
	'') ;;
	?) digit_to_roman $1 I V X;;
	??) echo $(digit_to_roman ${1%?} X L C)$(make_roman_number ${1#?});;
	???) echo $(digit_to_roman ${1%??} C D M)$(make_roman_number ${1#?});;
	????) echo $(digit_to_roman ${1%???} M)$(make_roman_number ${1#?});;
	esac
}

make_date () {
	printf "%s, %s of %s, Anno Domini %s, at the hour of the %s\n" \
		$(date +%A -d @$1) \
		$(nth $(date +%e -d @$1)) \
		$(date +%B -d @$1) \
		$(make_roman_number $(date +%Y -d @$1)) \
		$(make_chinese_hour $(date +%H -d @$1))
}

# make an argument for sed, to replace $1..$1 by <$2>..</$2>
markup_substitution () {
	case "$1" in
	?) echo "s/$1\\([^$1]*\\)$1/<$2>\\\\1<\/$2>/g";;
	??)
		tmp="[^${1%?}]*"
		tmp2="\\|${1%?}[^${1#?}]$tmp"
		tmp3="\\($tmp\\($tmp2\\($tmp2\\($tmp2\\)\\)\\)\\)"
		echo "s/$1$tmp3$1/<$2>\\\\1<\/$2>/g"
	;;
	esac
}

# transform markup in stdin to HTML
markup () {
	sed -e 's!^$!</p><p>!' \
		-e 's!IMHO!in my humble opinion!g' \
		-e 's!repo.or.cz!<a href=http://&>&</a>!g' \
		-e 's!:-)!\&#x263a;!g' \
		-e "$(markup_substitution "''" i)" \
		-e "$(markup_substitution "_" u)"
}

# make HTML page
make_html () {
	cat << EOF
<html>
	<head>
		<title>$TITLE</title>
		<meta http-equiv="Content-Type"
			content="text/html; charset=UTF-8"/>
		<link rel="stylesheet" type="text/css" href="$URL$CSS">
	</head>
	<body>
		<div class=content>
			<h1>$TITLE</h1>
EOF

	# timestamps will not need padding to sort correctly, for some time...
	for file in $(ls -r source-*.txt)
	do
		basename=${file%.txt}
		timestamp=${basename#source-}
		echo "<h6>$(make_date $timestamp)</h6>"
		echo "<h2>$(sed 1q < $file | markup)</h2>"
		echo ""
		echo "<p>"
		sed 1d < $file | markup
		echo "</p>"
	done |
	sed -e 's/^./\t\t\t&/'

	cat << EOF
		</div>
	</body>
</html>
EOF

}

# parse command line option
case "$1" in
*dry*) DRYRUN=1; shift;;
esac

test "$#" = 0 ||
die "Usage: $0 [--dry-run]"

# make sure we're in the correct working directory
cd "$(dirname "$0")"

# make sure we're on the correct branch
test refs/heads/$BRANCH = $(git symbolic-ref HEAD) ||
die "Not on branch $BRANCH"

# make sure there are no uncommitted changes
git update-index --refresh &&
git diff-files --quiet &&
git diff-index --quiet --cached HEAD ||
die "Have uncommitted changes!"

# rename the new blog entry if it exists
now=$(date +%s)
test ! -f $NEW || {
	mv -i $NEW source-$now.txt &&
	git add source-$now.txt
} ||
die "Could not rename source.txt"

if test -z "$DRYRUN"
then
	# rewrite URLs
	sed -e "s/url(/&$URL/g" < $CSS.in > $CSS &&
	git add $CSS ||
	die "Rewriting $CSS failed"
else
	OUTPUT=test.html
	CSS=$CSS.in
	URL=
fi

make_html > $OUTPUT || die "Could not write $OUTPUT"

test ! -z "$DRYRUN" && exit

git add $OUTPUT &&
git commit -s -m "Update $(make_date $now)" &&
git push origin +$BRANCH
