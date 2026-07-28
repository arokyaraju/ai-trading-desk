"""
Downloads NSE F&O bhavcopy for a date range, filters to Nifty options only,
and writes one simplified CSV per day to nse_data_cache/.

Usage:
    python nse_bhavcopy_downloader.py 2026-06-01 2026-07-25

Each output file: nse_data_cache/bhavcopy_YYYY-MM-DD.csv
Columns: expiry,strike,option_type,oi,volume,close
"""

import sys
import os
from datetime import date, datetime, timedelta
from jugaad_data.nse import bhavcopy_fo_save
import zipfile
import glob
import csv as csvlib

CACHE_DIR = os.path.join(os.path.dirname(__file__), "..", "nse_data_cache")
RAW_DIR = os.path.join(os.path.dirname(__file__), "nse_raw_temp")


def download_and_extract(target_date: date) -> str | None:
    os.makedirs(RAW_DIR, exist_ok=True)
    try:
        bhavcopy_fo_save(target_date, RAW_DIR)
    except Exception as e:
        print(f"  Skip {target_date} (likely holiday or no data): {e}")
        return None

    # jugaad_data saves a zip; find the most recently created one
    zips = sorted(glob.glob(os.path.join(RAW_DIR, "*.zip")), key=os.path.getmtime)
    if not zips:
        # some versions save a raw .csv directly
        csvs = sorted(glob.glob(os.path.join(RAW_DIR, "*.csv")), key=os.path.getmtime)
        return csvs[-1] if csvs else None

    latest_zip = zips[-1]
    with zipfile.ZipFile(latest_zip) as z:
        names = [n for n in z.namelist() if n.lower().endswith(".csv")]
        if not names:
            return None
        z.extract(names[0], RAW_DIR)
        return os.path.join(RAW_DIR, names[0])


def filter_and_write(raw_csv_path: str, target_date: date):
    os.makedirs(CACHE_DIR, exist_ok=True)
    out_path = os.path.join(CACHE_DIR, f"bhavcopy_{target_date.isoformat()}.csv")

    rows_written = 0
    with open(raw_csv_path, newline="", encoding="utf-8", errors="ignore") as infile, \
         open(out_path, "w", newline="", encoding="utf-8") as outfile:

        reader = csvlib.DictReader(infile)
        writer = csvlib.writer(outfile)
        writer.writerow(["expiry", "strike", "option_type", "oi", "volume", "close"])

        for row in reader:
            # NSE bhavcopy column names have varied historically — check both common variants
            symbol = (row.get("TckrSymb") or row.get("SYMBOL") or "").strip()
            instrument = (row.get("FinInstrmTp") or row.get("INSTRUMENT") or "").strip()

            if symbol != "NIFTY":
                continue
            if instrument not in ("IDO", "OPTIDX"):  # index options, both old/new naming seen
                continue

            option_type = (row.get("OptnTp") or row.get("OPTION_TYP") or "").strip()
            if option_type not in ("CE", "PE"):
                continue

            expiry = (row.get("XpryDt") or row.get("EXPIRY_DT") or "").strip()
            strike = (row.get("StrkPric") or row.get("STRIKE_PR") or "").strip()
            oi = (row.get("OpnIntrst") or row.get("OPEN_INT") or "0").strip()
            volume = (row.get("TtlTradgVol") or row.get("CONTRACTS") or "0").strip()
            close = (row.get("ClsPric") or row.get("CLOSE") or "0").strip()

            writer.writerow([expiry, strike, option_type, oi, volume, close])
            rows_written += 1

    print(f"  Wrote {rows_written} Nifty option rows -> {out_path}")


def daterange(start: date, end: date):
    d = start
    while d <= end:
        if d.weekday() < 5:  # skip weekends, holidays handled by the try/except above
            yield d
        d += timedelta(days=1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python nse_bhavcopy_downloader.py YYYY-MM-DD YYYY-MM-DD")
        sys.exit(1)

    start = datetime.strptime(sys.argv[1], "%Y-%m-%d").date()
    end = datetime.strptime(sys.argv[2], "%Y-%m-%d").date()

    for d in daterange(start, end):
        print(f"Downloading {d} ...")
        raw = download_and_extract(d)
        if raw:
            filter_and_write(raw, d)