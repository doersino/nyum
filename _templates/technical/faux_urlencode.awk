#!/usr/bin/awk

# faux urlencode, replaces non-alphanumeric characters with their ascii
# "codepoints" but notably without a leading "%", also removes spaces and turns
# uppercase lowercase (so, basically, something very different indeed); based on
# https://gist.github.com/moyashi/4063894 (changes are noted below)

BEGIN {
    for (i = 0; i <= 255; i++) {
        ord[sprintf("%c", i)] = i
    }
}

function encode(str, c, len, res) {
    str = tolower(str)                              # added
    len = length(str)
    res = ""
    for (i = 1; i <= len; i++) {
        c = substr(str, i, 1);
        if (c ~ /[0-9A-Za-z]/)
            res = res c
        else if (c == " ")                          # added
            res = res                               # added
        else
            #res = res "%" sprintf("%02X", ord[c])  # removed
            res = res sprintf("%02X", ord[c])       # added
    }
    return res
}

{ print encode($0) }
