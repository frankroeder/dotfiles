#!/usr/bin/env python3

import html
import json
import re
import sys
import urllib.parse
import urllib.request
from html.parser import HTMLParser

LANGS = frozenset({"de", "en"})
BRACKET_RE = (
    (r"<(.*?)>", "abbreviations"),
    (r"\[(.*?)\]", "comments"),
    (r"\((.*?)\)", "optionalData"),
    (r"\{(.*?)\}", "wordClassDefinitions"),
)


class DictParser(HTMLParser):
    def __init__(self, input_lang):
        super().__init__(convert_charrefs=True)
        self.input_lang = input_lang
        self.in_table = False
        self.table_depth = 0
        self.left = ""
        self.items = []
        self.seen = set()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "table" and attrs.get("id") == "searchres_table":
            self.in_table = True
            self.table_depth = 1
            return
        if not self.in_table:
            return
        if tag == "table":
            self.table_depth += 1
            return
        if tag != "td":
            return
        cls = attrs.get("class", "")
        if "srtd2" in cls:
            self.left = clean(attrs.get("data-term", ""))
        elif "srtd3" in cls and self.left:
            right = clean(attrs.get("data-term", ""))
            if right:
                self.add_item(self.left, right)

    def handle_endtag(self, tag):
        if not self.in_table:
            return
        if tag == "table":
            self.table_depth -= 1
            if self.table_depth <= 0:
                self.in_table = False

    def add_item(self, left, right):
        key = (left, right)
        if key in self.seen:
            return
        if self.input_lang == "de":
            source_raw, target_raw, copy_lang = right, left, "en"
        else:
            source_raw, target_raw, copy_lang = left, right, "de"
        self.seen.add(key)
        self.items.append(
            {
                "source": copy_clean(source_raw),
                "target": copy_clean(target_raw),
                "meta": text_meta(target_raw),
                "copy": copy_clean(target_raw),
                "copyLang": copy_lang,
            }
        )


def clean(value):
    return " ".join(html.unescape(value or "").replace("\xa0", " ").split())


def text_meta(value):
    meta = {name: [] for _, name in BRACKET_RE}
    for pattern, name in BRACKET_RE:
        meta[name] = [m.group(1) for m in re.finditer(pattern, value or "")]
    return meta


def copy_clean(value):
    text = value or ""
    for pattern, _ in BRACKET_RE:
        text = re.sub(pattern, "", text)
    text = re.sub(r"\d", "", text)
    return " ".join(text.split())


def detect_input_lang(url, query, html_text):
    if "/deutsch-englisch/" in url:
        return "de"
    if "/englisch-deutsch/" in url:
        return "en"
    q = query.casefold()
    if f'value="{html.escape(query, quote=True)}"' in html_text and any(c in q for c in "äöüß"):
        return "de"
    return "en"


def parse_query(query):
    parts = query.split()
    if (
        len(parts) > 2
        and parts[0].lower() in LANGS
        and parts[1].lower() in LANGS
        and parts[0].lower() != parts[1].lower()
    ):
        return parts[0].lower(), parts[1].lower(), " ".join(parts[2:]).strip()
    return "", "", query


def lookup(query):
    source_lang, target_lang, term = parse_query(query)
    pair = (source_lang + target_lang) if source_lang and target_lang else "deen"
    url = f"https://m.dict.cc/{pair}/?s={urllib.parse.quote_plus(term)}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=10) as res:
        final_url = res.geturl()
        page = res.read().decode("utf-8", "replace")
    input_lang = source_lang or detect_input_lang(final_url, term, page)
    parser = DictParser(input_lang)
    parser.feed(page)
    copy_lang = target_lang or ("en" if input_lang == "de" else "de")
    return parser.items, copy_lang, term, final_url


def main():
    query = " ".join(sys.argv[1:]).strip()
    if not query:
        print(json.dumps({"status": "empty", "items": []}, ensure_ascii=False))
        return
    try:
        items, copy_lang, term, url = lookup(query)
        print(
            json.dumps(
                {
                    "query": term,
                    "status": "ok" if items else "no-results",
                    "copyLang": copy_lang,
                    "url": url,
                    "items": items,
                },
                ensure_ascii=False,
            )
        )
    except Exception as e:
        print(
            json.dumps(
                {"query": query, "status": "error", "error": str(e), "items": []},
                ensure_ascii=False,
            )
        )


if __name__ == "__main__":
    main()