#!/bin/sh

# This is a simple script that will produce my blog on repo.or.cz

# The idea is to have source-<timestamp>.txt files as input, having the
# stories, and this script turning them into nice HTML, committing
# everything, and then pushing it to my repository.

# The blog will then be served using gitweb.

# To make it easier on me, if a file "new" exists, it is automatically
# renamed using the current timestamp.

# How to use:
#
# $ mkdir my-blog
# $ cd my-blog
# $ git init
#
# Then symlink or copy this file (upload.sh); you can track it or add it
# to .gitignore, does not matter.
#
# Add a remote "origin" (you might want to track only the appropriate branch
# if the repository contains other branches, too), add a background image,
# and then set the config variables gitweb.url, blog.title, blog.background
# and blog.branch appropriately.
#
# Example:
#
# $ git remote add -t blog repo.or.cz:/srv/git/git/dscho.git/
# $ git symbolic-ref HEAD refs/heads/blog
# $ cp ~/images/background.jpg ./
# $ git config gitweb.url http://repo.or.cz/w/git/dscho.git
# $ git config blog.title "Dscho's blog"
# $ git config blog.background background.jpg
# $ git config blog.branch blog
#
# Now you can start writing posts, by creating a file called "new", and
# calling ./upload.sh to commit the post together with the images and
# push all.
#
# Note that no file names may contain spaces.

# TODO: document the "syntax" of the source-*.txt files


# make sure we're in the correct working directory
cd "$(dirname "$0")"

GITWEBURL="$(git config gitweb.url)"
test -z "$GITWEBURL" && {
	echo "Please set gitweb.url in the Git config first!" >&2
	exit 1
}

get_config () {
	value=$(git config blog.$1)
	test -z "$value" && value=$2
	echo $value
}

BACKGROUNDIMG=$(get_config background paper.jpg)
TITLE=$(get_config title "Dscho's blog")
MAXENTRIES=$(get_config maxPostsPerPage 10)
BRANCH=$(get_config branch blog)

URLPREFIX="$(dirname "$GITWEBURL")"/
REMOTEREPOSITORY="$(basename "$GITWEBURL")"
case "$GITWEBURL" in
*'?'*) BLOBPLAIN="$REMOTEREPOSITORY;a=blob_plain";;
*/) URLPREFIX=$GITWEBURL; BLOBPLAIN="a=blob_plain";;
*) BLOBPLAIN="$REMOTEREPOSITORY?a=blob_plain";;
esac
URL="$BLOBPLAIN;hb=$BRANCH;f="
ORIGURL=$URL
NEW=new
OUTPUT=index.html
RSS=blog.rss
TEST=test.html
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

strip_prefix () {
	echo "${1#$2}"
}

chomp () {
	strip_prefix "${1%$3}" "$2"
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
	# sed does not know minimal match with .*, only greedy one
	middle=
	middleend=
	delim=$1
	right_no=3
	while test ! -z "$delim"
	do
		right_no=$(($right_no+1))
		test $right_no -gt 9 &&
		die "Invalid markup pattern: $1"
		first=$(expr "$delim" : '\(.\)')
		delim=${delim#$first}
		test -z "$delim" && {
			middle="$middle\\([^$first]\\|$first[A-Za-z0-9]\\)"
			break
		}
		middle="$middle\\([^$first]\\|$first"
		middleend="$middleend\\)"
	done

	left="\\(^\\|[^A-Za-z0-9]\\)$1\\($middle$middleend*\\)"
	right="$1\\($\\|[^A-Za-z0-9]\\)"
	echo "s/$left$right/\\\\1<$2>\\\\2<\/$2>\\\\$right_no/g"
}

space80='        '
space80="$space80$space80$space80$space80$space80$space80$space80$space80"
# transform markup in stdin to HTML
markup () {
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
		-e "s!\\[\\[\(Image\|SVG\):.*!$THIS handle &!e" \
		-e 's!<bash>!<table\
				border=1 bgcolor='$bash_bg'>\
			<tr><td bgcolor=lightblue colspan=3>\
				<pre>'"$space80"'</pre>\
			</td></tr>\
			<tr><td>\
				<table cellspacing=5 border=0\
					 style="color:'$bash_fg';">\
				<tr><td>\
					<pre>!' \
		-e 's!</bash>!</pre>\
				</td></tr>\
				</table>\
			</td></tr>\
			</table>!' \

}

# output lines containing <timestamp> <filename> <title>
get_blog_entries () {
	for file in $(ls -r source-*.txt)
	do
		timestamp=$(chomp $file source- .txt)
		title="$(sed 1q < $file | markup)"
		echo "$timestamp $file $title"
	done
}

get_last_removed_entry () {
	git log --pretty=format: --name-only --diff-filter=D HEAD |
	while read line
	do
		case "$line" in
		source-*.txt) file=$line;;
		'') test -z "$file" || {
			echo "$file"
			break
		};;
		esac
	done
}

box_count=0
begin_box () {
	test $box_count = 0 || echo "<br>"
	echo "<table width=$toc_width bgcolor=#e0e0e0 border=1>"
	echo "<tr><th>$1</th></tr>"
	echo "<tr><td>"
}

end_box () {
	echo "</td></tr></table>"
	box_count=$(($box_count+1))
}

# make HTML page
make_html () {
	body_style="width:800px"
	body_style="$body_style;background-image:url($URL$BACKGROUNDIMG)"
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
		begin_box "Table of contents:"
		echo '<p><ul>'
		get_blog_entries |
		while read timestamp filename title
		do
			date="$(date +"%d %b %Y" -d @$timestamp)"
			echo "<li><a href=#$timestamp>$date $title</a>"
		done
		echo '</ul></p>'
		file=
		last_removed_entry=$(get_last_removed_entry)
		test -z "$last_removed_entry" || {
			commit=$(git log --pretty=format:%H --diff-filter=AM \
					-- $last_removed_entry |
				head -n 1)
			previous="$BLOBPLAIN;hb=$commit"
			echo "<a href=$previous;f=index.html>Older posts</a>"
		}
		end_box

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

		# About
		test -f about.html && {
			begin_box "About this blog:"
			cat about.html
			end_box
		}

		# Links
		test -f links.html && {
			begin_box "Links:"
			cat links.html
			end_box
		}

		# Google AdSense
		test -z "$DRYRUN" && test -f google.adsense && {
			begin_box "Google Ads:"
			cat google.adsense
			end_box
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
		# remove all tags
		title=$(echo "$title" | sed 's/<[^>]*>//g')
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

get_image_files () {
	git ls-files |
	grep -v '\.\(rss\|html\|gitignore\|in\|sh\|txt\|adsense\)$'
}

remove_old_entries () {
	count=$(ls source-*.txt | wc -l)
	test $MAXENTRIES -ge $count && return

	for file in source-*.txt
	do
		test $MAXENTRIES -lt $count || break
		git rm $file > /dev/null || return 1
		count=$(($count-1))
		echo $file
	done

	# remove no-longer referenced images
	image_files=$(get_image_files)
	referenced_files="$(cat source-*.txt |
		tr ']|' '\n' |
		sed -ne 's/\[\[\(Image\|SVG\)://p') $BACKGROUNDIMG"
	for file in $(echo $image_files $referenced_files $referenced_files |
			tr ' ' '\n' | sort | uniq -u)
	do
		git rm $file > /dev/null || return 1
		echo $file
	done
}

# never, ever have spaces in the file names
commit_new_images () {
	files="$(remove_old_entries) $RSS $BACKGROUNDIMG" ||
	die "Could not remove old entries"


	generate_rss > $RSS &&
	git add $RSS ||
	die "Could not generate $RSS"

	for image in $(cat source-* |
		tr ' ]|' '\n' |
		sed -n 's/.*\[\[\(Image\|SVG\)://p' |
		sort |
		uniq)
	do
		git add $image || die "Could not git add image $image"
		files="$files $image"
	done

	git update-index --refresh &&
	git diff-files --quiet -- $files &&
	git diff --cached --quiet HEAD -- $files ||
	git commit -s -m "Housekeeping on $(make_date $now)" $files
}

get_image_url () {
	test ! -z "$DRYRUN" && echo "$1" && return
	rev=$(git rev-list -1 HEAD -- $1)
	test -z "$rev" && die "No revision found for $1"
	echo "$BLOBPLAIN;hb=$rev;f=$1"
}

handle_svg_file () {
	# for some reason, Firefox adds scrollbars, so nudge the width a bit
	width=$(sed -ne 's/.* width="\([^"]*\).*/\1/p' -e '/<metadata/q' < "$1")
	test -z "$width" || width=" width=$(($width+5))"
	url=$(get_image_url "$1")
	cat << EOF
<center>
	<table border=0>
		<tr>
			<td align=center>
				<embed type="image/svg+xml"
					src="$url"$width />
			</td>
		</tr>
		<tr>
			<td align=center>
				<a href=$url>$1</a>
			</td>
		</tr>
	</table>
</center>
EOF
}

handle_image_file () {
	echo "<center><img src=$(get_image_url "${1%% *}") ${1#* }></center>"
}



# parse command line option
case "$1" in
*dry*) DRYRUN=1; export DRYRUN; shift;;
*show*) firefox "$(pwd)"/$TEST; exit;;
*remote*) firefox $URLPREFIX$URL$OUTPUT; exit;;
handle)
	shift
	case "$1" in
	"[[SVG:"*) handle_svg_file "$(chomp "$*" '\[\[SVG:' '\]\]')";;
	"[[Image:"*) handle_image_file "$(chomp "$*" '\[\[Image:' '\]\]')";;
	esac
	exit
;;
'') ;;
*) die "Unknown command: $1";;
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
IMAGEFILES="$(get_image_files)"
REV=$(git rev-list -1 HEAD -- $IMAGEFILES)
test -z "$REV" && REV=$BRANCH
URL="$BLOBPLAIN;hb=$REV;f="

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
