#!/bin/sh

# This is a simple script that will produce my blog on repo.or.cz

# The idea is to have source-<timestamp>.txt files as input, having the
# stories, and this script turning them into nice HTML, committing
# everything, and then pushing it to my repository.

# The blog will then be served using gitweb.

# To make it easier on me, if a file "source.txt" exists, it is
# automatically renamed using the current timestamp.

# TODO: have a configurable maximum number of entries per page, and links
#	to older pages

# make sure we're in the correct working directory
cd "$(dirname "$0")"

GITWEBURL="$(git config gitweb.url)"
test -z "$GITWEBURL" && {
	echo "Please set gitweb.url in the Git config first!" >&2
	exit 1
}

URLPREFIX="$(dirname "$GITWEBURL")"/
REMOTEREPOSITORY="$(basename "$GITWEBURL")"
BRANCH=blog
URL="$REMOTEREPOSITORY?a=blob_plain;hb=$BRANCH;f="
ORIGURL=$URL
NEW=new
OUTPUT=index.html
RSS=blog.rss
TEST=test.html
TITLE="Dscho's blog"
THIS=$0

LC_ALL=C
export LC_ALL

move_new_entry_back () {
	test -f source-$now.txt &&
	mv source-$now.txt $NEW &&
	git rm --cached -f source-$now.txt
}

die () {
	move_new_entry_back
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
	image_pattern="\\[\\[Image:\([^]]*\)"
	image_pattern2="$image_pattern\(\\|[^\]]*\)\?\]\]"
	case "$*" in
	*invert-bash*) bash_bg=white; bash_fg=black;;
	*) bash_bg=black; bash_fg=white;;
	esac
	sed -e 's!^$!</p><p>!' \
		-e "$(markup_substitution "''" i)" \
		-e "$(markup_substitution "_" u)" \
		-e 's!IMHO!in my humble opinion!g' \
		-e 's!BTW!By the way,!g' \
		-e 's!repo.or.cz!<a href=http://&>&</a>!g' \
		-e 's!:-)!\&#x263a;!g' \
		-e "s!$image_pattern2!<center><img src=$URL\1></center>!g" \
		-e "s!\\[\\[SVG:\\([^]]*\\)\]\]!$THIS handle &!e" \
		-e 's!<bash>!<table\
				border=1 bgcolor='$bash_bg'>\
			<tr><td bgcolor=lightblue colspan=3>\
				\&nbsp;\
			</td></tr>\
			<tr><td>\
				<table cellspacing=5 border=0\
					 style="color:'$bash_fg';">\
				<tr><td>\
					<pre>!' \
		-e 's!</bash>!		</pre>\
				</td></tr>\
				</table>\
			</td></tr>\
			</table>!' \

}

# output lines containing <timestamp> <filename> <title>
get_blog_entries () {
	for file in $(ls -r source-*.txt)
	do
		basename=${file%.txt}
		timestamp=${basename#source-}
		title="$(sed 1q < $file | markup)"
		echo "$timestamp $file $title"
	done
}

# make HTML page
make_html () {
	body_style="width:800px"
	body_style="$body_style;background-image:url(${URL}paper.jpg)"
	body_style="$body_style;background-repeat:repeat-y"
	body_style="$body_style;background-attachment:scroll"
	body_style="$body_style;padding:0px;"
	text_style="width:610px"
	text_style="$text_style;margin-left:120px"
	text_style="$text_style;margin-top:50px"
	text_style="$text_style;align:left"
	text_style="$text_style;vertical-align:top;"
	cat << EOF
<html>
	<head>
		<title>$TITLE</title>
		<meta http-equiv="Content-Type"
			content="text/html; charset=UTF-8"/>
	</head>
	<body style="$body_style">
		<div style="$text_style">
			<h1>$TITLE</h1>
EOF
	indent='\t\t\t'

	# make toc
	toc_width=400px
	toc_style="position:absolute;top:50px;left:810px;width=$toc_width"
	{
		echo "<div style=\"$toc_style\">"
		echo "<table width=$toc_width bgcolor=#e0e0e0 border=1>"
		echo "<tr><th>Table of contents:</th></tr>"
		echo "<tr><td>"
		echo '<p><ol>'
		get_blog_entries |
		while read timestamp filename title
		do
			date="$(date +"%d %b %Y" -d @$timestamp)"
			echo "<li><a href=#$timestamp>$date $title</a>"
		done
		echo '</ol></p>'
		echo '</td></tr></table>'

		# RSS feed
		rss_style="background-color:orange;text-decoration:none"
		rss_style="$rss_style;color:white;font-family:sans-serif;"
		echo '<br>'
		echo '<div style="text-align:right;">'
		echo "<a href=\"$ORIGURL$RSS\""
		echo '   title="Subscribe to my RSS feed"'
		echo '   class="rss" rel="nofollow"'
		echo "   style=\"$rss_style\">RSS</a>"
		echo '</div>'

		# Links
		test -f links.html && {
			echo "<br>"
			echo "<table width=$toc_width bgcolor=#e0e0e0 border=1>"
			echo "<tr><th>Links:</th></tr>"
			echo "<tr><td>"
			cat links.html
			echo "</td></tr></table>"
		}

		# Google AdSense
		test -z "$DRYRUN" && test -f google.adsense && {
			echo "<br>"
			echo "<table width=$toc_width bgcolor=#e0e0e0 border=1>"
			echo "<tr><th>Google Ads:</th></tr>"
			echo "<tr><td align=center>"
			cat google.adsense
			echo "</td></tr></table>"
		}

		echo '</div>'
	} | sed -s "s/^/$indent/"


	# timestamps will not need padding to sort correctly, for some time...
	get_blog_entries |
	while read timestamp filename title
	do
		echo "<h6>$(make_date $timestamp)</h6>"
		echo "<a name=$timestamp>"
		echo "<h2>$title</h2>"
		echo ""
		echo "<p>"
		sed 1d < $filename | markup
		echo "</p>"
	done |
	sed -e "s/^./$indent&/" \
		-e "/<pre>/,/<\/pre>/s/^$indent//"

	cat << EOF
		</div>
	</body>
</html>
EOF
}

generate_rss () {
	echo '<?xml version="1.0" encoding="utf-8"?>'
	echo '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">'
	echo '<channel>'
	echo "<title>Dscho's blog</title>"
	echo "<link>$URLPREFIX${URL}index.html</link>"
	self="$URLPREFIX$ORIGURL$RSS"
	selfattribs='rel="self" type="application/rss+xml"'
	echo "<atom:link href=\"$self\" $selfattribs/>"
	echo '<description>A few stories told by Dscho</description>'
	echo "<lastBuildDate>$(date --rfc-2822)</lastBuildDate>"
	echo '<language>en-us</language>'

	get_blog_entries |
	while read timestamp filename title
	do
		echo '<item>'
		echo "<title>$title</title>"
		echo "<link>$URLPREFIX${URL}index.html#$timestamp</link>"
		echo "<guid>$URLPREFIX${URL}index.html#$timestamp</guid>"
		echo "<pubDate>$(date --rfc-2822 -d @$timestamp)</pubDate>"
		description="$(cat < $filename | markup invert-bash)"
		echo "<description><![CDATA[$description]]></description>"
		echo "</item>"
	done

	echo '</channel>'
	echo '</rss>'
}

# never, ever have spaces in the file names
commit_new_images () {
	generate_rss > $RSS &&
	git add $RSS ||
	die "Could not generate $RSS"

	images=
	for image in $(cat source-* |
		tr ' ]|' '\n' |
		sed -n 's/.*\[\[\(Image\|SVG\)://p' |
		sort |
		uniq)
	do
		git add $image || die "Could not git add image $image"
		images="$images $image"
	done

	git update-index --refresh &&
	git diff-files --quiet -- $images &&
	git diff --cached --quiet HEAD -- $images ||
	git commit -s -m "Commit some images on $(make_date $now)" $images
}

handle_svg_file () {
	# for some reason, Firefox adds scrollbars, so nudge the width a bit
	width=$(sed -ne 's/.* width="\([^"]*\).*/\1/p' -e '/<metadata/q' < "$1")
	test -z "$width" || width=" width=$(($width+5))"
	REV=$(git rev-list -1 HEAD -- $1)
	test -z "$REV" || URL="$REMOTEREPOSITORY?a=blob_plain;hb=$REV;f="
	cat << EOF
<center>
	<table border=0>
		<tr>
			<td align=center>
				<embed type="image/svg+xml"
					src="$URL$1"$width />
			</td>
		</tr>
		<tr>
			<td align=center>
				<a href=$URL$1>$1</a>
			</td>
		</tr>
	</table>
</center>
EOF
}



# parse command line option
case "$1" in
*dry*) DRYRUN=1; shift;;
*show*) firefox "$(pwd)"/$TEST; exit;;
*remote*) firefox $URLPREFIX$URL$OUTPUT; exit;;
handle)
	case "$2" in
	"[[SVG:"*) file=${2#??SVG:}; file=${file%??}; handle_svg_file "$file";;
	esac
	exit
;;
esac

test "$#" = 0 ||
die "Usage: $0 [--dry-run]"

# make sure we're on the correct branch
test refs/heads/$BRANCH = $(git symbolic-ref HEAD) ||
die "Not on branch $BRANCH"

# make sure there are no uncommitted changes
git update-index --refresh &&
git diff-files --quiet ||
die "Have unstaged changes!"

# rename the new blog entry if it exists
now=$(date +%s)
test ! -f $NEW || {
	mv -i $NEW source-$now.txt &&
	git add source-$now.txt
} ||
die "Could not rename source.txt"

# commit the images that are referenced and not yet committed
test ! -z "$DRYRUN" ||
commit_new_images ||
die "Could not commit new images"

# to find the images reliably, we have to use the commit name, not the branch
# we use the latest commit touching an image file.
IMAGEFILES="$(git ls-files |
	grep -v '\.\(rss\|html\|gitignore\|in\|sh\|txt\|adsense\)$')"
REV=$(git rev-list -1 HEAD -- $IMAGEFILES)
test -z "$REV" && REV=$BRANCH
URL="$REMOTEREPOSITORY?a=blob_plain;hb=$REV;f="

if test ! -z "$DRYRUN"
then
	# Output to test.html and have local links into the current directory
	OUTPUT=$TEST
	URL=
fi

make_html > $OUTPUT || die "Could not write $OUTPUT"

test ! -z "$DRYRUN" && {
	move_new_entry_back
	exit
}

git add $OUTPUT &&
git commit -s -m "Update $(make_date $now)" &&
git push origin +$BRANCH
