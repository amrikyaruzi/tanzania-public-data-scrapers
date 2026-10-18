"""Tanzania Health Facility Registry scraper, asynchronous Python version.

Same output as R/hfrs_scraper.R, using aiohttp with a semaphore to cap the
number of requests in flight.

Usage:  python python/hfrs_async.py  ->  data/hfrs_facilities_<date>_py.csv
"""

import asyncio
import datetime as dt
import os
import re

import aiohttp
import polars as pl
from bs4 import BeautifulSoup

BASE = os.environ.get("HFRS_BASE", "https://hfrs.moh.go.tz/web/index.php?r=portal%2Fquick-search")
HEADERS = {"User-Agent": "tanzania-public-data-scrapers (https://github.com/amrikyaruzi/tanzania-public-data-scrapers)"}
MAX_IN_FLIGHT = 20
RETRIES = 4


async def fetch(session: aiohttp.ClientSession, sem: asyncio.Semaphore, url: str) -> str:
    """GET a page, retrying with exponential back-off."""
    for attempt in range(RETRIES):
        try:
            async with sem, session.get(url, timeout=aiohttp.ClientTimeout(total=60)) as resp:
                resp.raise_for_status()
                return await resp.text()
        except (aiohttp.ClientError, asyncio.TimeoutError):
            if attempt == RETRIES - 1:
                raise
            await asyncio.sleep(2 ** attempt)
    raise RuntimeError("unreachable")


def last_page(html: str) -> int:
    link = BeautifulSoup(html, "html.parser").select_one(".page-item.last .page-link")
    return int(re.search(r"page=(\d+)", link["href"]).group(1)) if link else 1


def parse_listing(html: str) -> tuple[list[str], list[list[str]]]:
    table = BeautifulSoup(html, "html.parser").find("table")
    headers = [th.get_text(strip=True) for th in table.find("thead").find_all("th")]
    rows = [[td.get_text(strip=True) for td in tr.find_all("td")] for tr in table.find("tbody").find_all("tr")]
    return headers, rows


async def scrape() -> pl.DataFrame:
    sem = asyncio.Semaphore(MAX_IN_FLIGHT)
    async with aiohttp.ClientSession(headers=HEADERS) as session:
        firsts = await asyncio.gather(*(fetch(session, sem, f"{BASE}&filters={f}") for f in ("publ", "priv")))
        urls = [f"{BASE}&filters={f}&page={p}"
                for f, html in zip(("publ", "priv"), firsts)
                for p in range(1, last_page(html) + 1)]
        print(f"Fetching {len(urls)} listing pages")
        pages = await asyncio.gather(*(fetch(session, sem, u) for u in urls), return_exceptions=True)

    failed = [u for u, p in zip(urls, pages) if isinstance(p, Exception)]
    if failed:
        print(f"Warning: {len(failed)} page(s) failed, e.g. {failed[0]}")

    headers, rows = None, []
    for page in pages:
        if isinstance(page, Exception):
            continue
        headers, page_rows = parse_listing(page)
        rows.extend(page_rows)

    df = pl.DataFrame(rows, schema=headers, orient="row")
    return (df.drop([c for c in ("#", "") if c in df.columns])
              .unique(subset="Facility Code", keep="first")
              .with_columns(pl.col("Region").str.replace(r" Region$", "")))


if __name__ == "__main__":
    data = asyncio.run(scrape())
    os.makedirs("data", exist_ok=True)
    out = f"data/hfrs_facilities_{dt.date.today()}_py.csv"
    data.write_csv(out)
    print(f"{data.height} facilities written to {out}")
