#!/usr/bin/env bash

TIME_START=$(date +%s)

# exit on errors
set -e

# parse arguments
QUIET=false
CLEAN=false
while [[ $# -gt 0 ]]; do
    if [ "$1" = "-q" ] || [ "$1" = "--quiet" ]; then
        QUIET=true
        shift
    elif [ "$1" = "-c" ] || [ "$1" = "--clean" ]; then
        CLEAN=true
        shift
    elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: bash build.sh [-q | --quiet] [-c | --clean]"
        echo "  Builds the site. If the -c flag is given, stops after resetting _site/ and _temp/."
        exit
    else
        shift
    fi
done

function status {
    $QUIET && return
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
    echo "${BOLD}$*${NORMAL}"
}

function x {
    _IFS="$IFS"
    IFS=" "
    $QUIET || echo "↪" "$*" >&2
    IFS="$_IFS"
    "$@"
}

status "Resetting _site/ and _temp/..."
# (...with a twist, just to make sure this doesn't throw an error the first time)
x mkdir -p _site/
x touch _site/dummy.txt
x rm -r _site/
x mkdir -p _site/
x mkdir -p _temp/
x touch _temp/dummy.txt
x rm -r _temp/
x mkdir -p _temp/

$CLEAN && exit

status "Copying assets..."
x cp -r _assets/ _site/assets/

status "Copying static files..."
for FILE in _recipes/*; do
    [[ "$FILE" == *.md ]] && continue
    x cp "$FILE" _site/
done

status "Extracting metadata..."
for FILE in _recipes/*.md; do
    # extract category name for each recipe, set basename to avoid having to
    # use $sourcefile$ in the template which pandoc sets automatically but
    # contains the relative path
    x pandoc "$FILE" \
        --metadata-file config.yaml \
        --metadata basename="$(basename "$FILE" .md)" \
        --template _templates/technical/category.template.txt \
        -t html -o "_temp/$(basename "$FILE" .md).category.txt"

    # extract metadata, set htmlfile in order to link to it on the index page
    x pandoc "$FILE" \
        --metadata htmlfile="$(basename "$FILE" .md).html" \
        --template _templates/technical/metadata.template.json \
        -t html -o "_temp/$(basename "$FILE" .md).metadata.json"
done

status "Grouping metadata by category..."  # (yep, this is a right mess)
echo "{\"categories\": [" > _temp/index.json
SEPARATOR_OUTER=""  # no comma before first list element (categories)
SEPARATOR_INNER=""  # ditto (recipes per category)
IFS=$'\n'           # tell for loop logic to split on newlines only, not spaces
CATS="$(cat _temp/*.category.txt)"
for CATEGORY in $(echo "$CATS" | cut -d" " -f2- | sort | uniq); do
    printf '%s' "$SEPARATOR_OUTER" >> _temp/index.json
    CATEGORY_FAUX_URLENCODED="$(echo "$CATEGORY" | awk -f "_templates/technical/faux_urlencode.awk")"

    # some explanation on the next line and similar ones: this uses `tee -a`
    # instead of `>>` to append to two files instead of one, but since we don't
    # actually want to see the output, pipe that to /dev/null
    x printf '%s' "{\"category\": \"$CATEGORY\", \"category_faux_urlencoded\": \"$CATEGORY_FAUX_URLENCODED\", \"recipes\": [" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" >/dev/null
    for C in $CATS; do
        BASENAME=$(echo "$C" | cut -d" " -f1)
        C_CAT=$(echo "$C" | cut -d" " -f2-)
        if [[ "$C_CAT" == "$CATEGORY" ]]; then
            printf '%s' "$SEPARATOR_INNER" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" >/dev/null
            x cat "_temp/$BASENAME.metadata.json" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" >/dev/null
            SEPARATOR_INNER=","
        fi
    done
    x printf "]}\n" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" >/dev/null
    SEPARATOR_OUTER=","
    SEPARATOR_INNER=""
done
unset IFS
echo "]}" >> _temp/index.json

status "Building recipe pages..."
for FILE in _recipes/*.md; do
    CATEGORY_FAUX_URLENCODED="$(cat "_temp/$(basename "$FILE" .md).category.txt" | cut -d" " -f2- | awk -f "_templates/technical/faux_urlencode.awk")"

    # when running under GitHub Actions, all file modification dates are set to
    # the date of the checkout (i.e., the date on which the workflow was
    # executed), so in that case, use the most recent commit date of each recipe
    # as its update date – you'll probably also want to set the TZ environment
    # variable to your local timezone in the workflow file (#21)
    if [[ "$GITHUB_ACTIONS" = true ]]; then
        UPDATED_AT="$(git log -1 --date=short-local --pretty='format:%cd' "$FILE")"
    else
        UPDATED_AT="$(date -r "$FILE" "+%Y-%m-%d")"
    fi

    # set basename to enable linking to github in the footer, and set
    # category_faux_urlencoded in order to link to that in the header
    x pandoc "$FILE" \
        --metadata-file config.yaml \
        --metadata basename="$(basename "$FILE" .md)" \
        --metadata category_faux_urlencoded="$CATEGORY_FAUX_URLENCODED" \
        --metadata updatedtime="$UPDATED_AT" \
        --template _templates/recipe.template.html \
        -o "_site/$(basename "$FILE" .md).html"
done

status "Building category pages..."
for FILE in _temp/*.category.json; do
    x pandoc _templates/technical/empty.md \
        --metadata-file config.yaml \
        --metadata title="dummy" \
        --metadata updatedtime="$(date "+%Y-%m-%d")" \
        --metadata-file "$FILE" \
        --template _templates/category.template.html \
        -o "_site/$(basename "$FILE" .category.json).html"
done

status "Building index page..."
x pandoc _templates/technical/empty.md \
    --metadata-file config.yaml \
    --metadata title="dummy" \
    --metadata updatedtime="$(date "+%Y-%m-%d")" \
    --metadata-file _temp/index.json \
    --template _templates/index.template.html \
    -o _site/index.html

status "Assembling search index..."
echo "[" > _temp/search.json
SEPARATOR=""
for FILE in _temp/*.metadata.json; do
    printf '%s' "$SEPARATOR" >> _temp/search.json
    x cat "$FILE" >> _temp/search.json
    SEPARATOR=","
done
echo "]" >> _temp/search.json
x cp -r _temp/search.json _site/

TIME_END=$(date +%s)
TIME_TOTAL=$((TIME_END-TIME_START))

EMOJI="🍇🍈🍉🍊🍋🍌🍍🥭🍎🍏🍐🍑🍒🍓🥝🍅🥥🥑🍆🥔🥕🌽🌶️🥒🥬🥦"
status "All done after $TIME_TOTAL seconds!" "${EMOJI:RANDOM%${#EMOJI}:1}"
