#!/usr/bin/env python

import html
import json
import re
import sys
import urllib.parse
import urllib.request
from html.parser import HTMLParser

LANGS = {"de", "en"}


class DictParser(HTMLParser):
    def __init__(self, input_lang, limit=10):
        super().__init__(convert_charrefs=True)
        self.input_lang = input_lang
        self.limit = limit
        self.in_table = False
        self.table_depth = 0
        self.current_cell = ""
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
        if "srtd2" in cls or "srtd3" in cls:
            self.current_cell = "left" if "srtd2" in cls else "right"
            term = clean(attrs.get("data-term", ""))
            if self.current_cell == "left":
                self.left = term
            elif self.left and term:
                self.add_item(self.left, term)

    def handle_endtag(self, tag):
        if not self.in_table:
            return
        if tag == "td":
            self.current_cell = ""
        elif tag == "table":
            self.table_depth -= 1
            if self.table_depth <= 0:
                self.in_table = False

    def add_item(self, left, right):
        key = (left, right)
        if key in self.seen or len(self.items) >= self.limit:
            return
        if self.input_lang == "de":
            from_text = right
            to_text = left
            copy_lang = "en"
        else:
            from_text = left
            to_text = right
            copy_lang = "de"
        source = copy_clean(from_text)
        target = copy_clean(to_text)
        self.seen.add(key)
        self.items.append(
            {
                "left": left,
                "right": right,
                "from": from_text,
                "to": to_text,
                "source": source,
                "target": target,
                "meta": meta_text(to_text),
                "copy": target,
                "copyLang": copy_lang,
            }
        )


def clean(value):
    return " ".join(html.unescape(value or "").replace("\xa0", " ").split())


def copy_clean(value):
    value = re.sub(r"\s*(\{[^}]*\}|\[[^\]]*\]|<[^>]*>)", "", value)
    return " ".join(value.split())


def meta_text(value):
    parts = re.findall(r"\{([^}]*)\}|\[([^\]]*)\]|<([^>]*)>", value)
    flat = ["".join(p).strip() for p in parts]
    return ", ".join(p for p in flat if p)


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
    pair = source_lang + target_lang if source_lang and target_lang else "deen"
    url = "https://m.dict.cc/" + pair + "/?s=" + urllib.parse.quote_plus(term)
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Accept-Language": "en-US,en;q=0.8,de;q=0.7",
        },
    )
    with urllib.request.urlopen(req, timeout=5) as res:
        final_url = res.geturl()
        data = res.read().decode("utf-8", "replace")
    input_lang = source_lang or detect_input_lang(final_url, term, data)
    target_lang = target_lang or ("en" if input_lang == "de" else "de")
    parser = DictParser(input_lang)
    parser.feed(data)
    return parser.items, input_lang, target_lang, term


def main():
    query = " ".join(sys.argv[1:]).strip()
    if not query:
        print(json.dumps({"query": query, "status": "empty", "items": []}, ensure_ascii=False))
        return
    try:
        items, input_lang, copy_lang, term = lookup(query)
        status = "ok" if items else "no-results"
        print(
            json.dumps(
                {
                    "query": term,
                    "status": status,
                    "inputLang": input_lang,
                    "copyLang": copy_lang,
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
