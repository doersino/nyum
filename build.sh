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
    echo "${BOLD}$@${NORMAL}"
}

function x {
    $QUIET || echo "↪" $@ >&2
    $@
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

status "Building recipe pages..."
for FILE in _recipes/*.md; do
    # set basename to enable linking to github in the footer
    x pandoc "$FILE" \
        --metadata-file config.yaml \
        --metadata basename="$(basename $FILE .md)" \
        --metadata updatedtime="$(date -r "$FILE" "+%Y-%m-%d")" \
        --template _templates/recipe.template.html \
        -o "_site/$(basename "$FILE" .md).html"
done

status "Extracting metadata..."
for FILE in _recipes/*.md; do
    # set basename to avoid having to use $sourcefile$ which pandoc sets automatically but contains the relative path
    x pandoc "$FILE" \
        --metadata-file config.yaml \
        --metadata basename="$(basename $FILE .md)" \
        --template _templates/technical/category.template.txt \
        -t html -o "_temp/$(basename "$FILE" .md).category.txt"

    # set htmlfile in order to link to it on the index page
    x pandoc "$FILE" \
        --metadata htmlfile="$(basename $FILE .md).html" \
        --template _templates/technical/metadata.template.json \
        -t html -o "_temp/$(basename $FILE .md).metadata.json"
done

status "Grouping metadata by category..."  # (yep, this is a right mess)
echo "{\"categories\": [" > _temp/index.json
SEPARATOR_OUTER=""  # no comma before first list element (categories)
SEPARATOR_INNER=""  # ditto (recipes per category)
IFS=$'\n'           # tell for loop logic to split on newlines only, not spaces
CATS="$(cat _temp/*.category.txt)"
echo $CATS
for CATEGORY in $(echo "$CATS" | cut -d" " -f2- | sort | uniq); do
    printf "$SEPARATOR_OUTER" >> _temp/index.json
    x printf "{\"category\": \"$CATEGORY\", \"recipes\": [" >> _temp/index.json
    for C in $(echo "$CATS"); do
        BASENAME=$(echo "$C" | cut -d" " -f1)
        C_CAT=$(echo "$C" | cut -d" " -f2-)
        if [[ "$C_CAT" == "$CATEGORY" ]]; then
            printf "$SEPARATOR_INNER" >> _temp/index.json
            x cat "_temp/$BASENAME.metadata.json" >> _temp/index.json
            SEPARATOR_INNER=","
        fi
    done
    x printf "]}\n" >> _temp/index.json
    SEPARATOR_OUTER=","
    SEPARATOR_INNER=""
done
unset IFS
echo "]}" >> _temp/index.json

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
    printf "$SEPARATOR" >> _temp/search.json
    x cat "$FILE" >> _temp/search.json
    SEPARATOR=","
done
echo "]" >> _temp/search.json
x cp -r _temp/search.json _site/

TIME_END=$(date +%s)
TIME_TOTAL=$((TIME_END-TIME_START))

EMOJI="🍇🍈🍉🍊🍋🍌🍍🥭🍎🍏🍐🍑🍒🍓🥝🍅🥥🥑🍆🥔🥕🌽🌶️🥒🥬🥦"
status "All done after $TIME_TOTAL seconds!" "${EMOJI:RANDOM%${#EMOJI}:1}"
