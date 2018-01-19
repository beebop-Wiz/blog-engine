#!/bin/bash
BLOGHOME=/home/beebop/public/blog
AUTHOR="Blake Thomas"
PREVIEW_LENGTH=10

# colorscheme nonsense
typeset -A solarized
solarized=(
    [base03]="#002b36"
    [base02]="#073642"
    [base01]="#586e75"
    [base00]="#657b83"
    [base0]="#839496"
    [base1]="#93a1a1"
    [base2]="#eee8d5"
    [base3]="#fdf6e3"
    [yellow]="#b58900"
    [orange]="#cb4b16"
    [red]="#dc322f"
    [magenta]="#d33682"
    [violet]="#6c71c4"
    [blue]="#268bd2"
    [cyan]="#2aa198"
    [green]="#859900"
)

typeset -A categories_color
categories_color=(
    [meta]=cyan
)

typeset -a categories
categories=(
    meta
)

# do some math for the header length
LINES=$(($(wc -l blog_header.html | cut -d ' ' -f 1) + $PREVIEW_LENGTH))
OFFSET=$(($(awk '/BEGIN CONTENT/ {print FNR}' blog_header.html) + 1))

# generate blog posts

truncate $BLOGHOME/posts.txt -s 0
for c in $categories; do truncate $BLOGHOME/$c/posts.txt -s 0; done

for MARKDOWN in `find $BLOGHOME/md -type f -regex '^.*[^#~]$' -printf "%T+\t%p\n" | sort -r | cut -f 2`; do
    HTML=$BLOGHOME/$(realpath --relative-to=$BLOGHOME/md/ $MARKDOWN)     # convert to normalized path relative to /blog
    HTML=${HTML%.md}.html				  # convert to .html extension via bash JFM
    CATEGORY=$(dirname $(realpath --relative-to=$BLOGHOME/md/ $MARKDOWN))
    WWWPATH=$(realpath --relative-to=$BLOGHOME/md $MARKDOWN)
    WWWPATH=/${WWWPATH%.md}.html
    mkdir -p $(dirname $HTML)
    CONTENT=$(mktemp)
    HEADER_PROC=$(mktemp)
    # header information generation goes here
    sed "\
s/{{WWWPATH}}/${WWWPATH//\//\\/}/g;\
s/{{TITLE}}/$(head -n 1 $MARKDOWN)/g;\
s/{{AUTHOR}}/$AUTHOR/g;\
s/{{STYLE_CSS}}/color:${solarized[${categories_color[$CATEGORY]}]};/g;\
s/{{CATEGORY}}/$CATEGORY/g;\
s/{{DATE}}/$(date -d @$(stat -c %Y $MARKDOWN) +%Y-%m-%d)/g"\
	< blog_header.html > $HEADER_PROC
    tail -n +2 $MARKDOWN | markdown - >> $CONTENT
    cat $CONTENT >> $HEADER_PROC
    cat $HEADER_PROC blog_footer.html > $HTML
    tail -n +$OFFSET $HEADER_PROC | head -n $(($(wc -l blog_header.html | cut -d ' ' -f 1) - OFFSET + 10)) > $HTML.preview
    /bin/echo -e $HTML "\t" $(head -n 1 $MARKDOWN) >> $BLOGHOME/posts.txt
    /bin/echo -e $HTML "\t" $(head -n 1 $MARKDOWN) >> $BLOGHOME/$CATEGORY/posts.txt
    echo $HTML
    rm $CONTENT
    rm $HEADER_PROC
done

# generate indexes

sed "s/{{CATEGORY}}/All Posts/g;" < index_header.html > $BLOGHOME/index.html
while read f; do
    NAME=$(echo $f | cut -d ' ' -f 1)
    HTML=$(realpath --relative-to=$BLOGHOME $NAME)
    TITLE=$(echo $f | cut -d ' ' -f 2-)
    echo "<div class=\"preview\">" >> $BLOGHOME/index.html
    cat $NAME.preview >> $BLOGHOME/index.html
    if [ $(($(wc -l $NAME.preview | cut -d ' ' -f 1) - ($(wc -l blog_header.html | cut -d ' ' -f 1) - $OFFSET))) -ge $PREVIEW_LENGTH ]; then
	echo "... (<a class=\"continue\" href=\"/$HTML\">Read more</a>)" >> $BLOGHOME/index.html
    fi
    echo "</div>" >> $BLOGHOME/index.html
done <$BLOGHOME/posts.txt	# this syntax is kinda weird. this is essentially the input to the `read f`
# gotta love bash - why I have to do this crap to read line-by-line
# instead of token-by-token has always confused me

# generate by-category indexes

for c in $categories; do
    sed "s/{{CATEGORY}}/$c/g;s/{{STYLE_CSS}}/color:${solarized[${categories_color[$CATEGORY]}]};/g;" index_header.html > $BLOGHOME/$c/index.html
    while read f; do
	NAME=$(echo $f | cut -d ' ' -f 1)
	HTML=$(realpath --relative-to=$BLOGHOME $NAME)
	TITLE=$(echo $f | cut -d ' ' -f 2-)
	echo "<div class=\"preview\">" >> $BLOGHOME/$c/index.html
	cat $NAME.preview >> $BLOGHOME/$c/index.html
	echo "... (<a class=\"continue\" href=\"/$HTML\">Read more</a>)" >> $BLOGHOME/$c/index.html
	echo "</div>" >> $BLOGHOME/$c/index.html
    done <$BLOGHOME/$c/posts.txt
    cat index_footer.html >> $BLOGHOME/$c/index.html
done

cat index_footer.html >> $BLOGHOME/index.html
