import os
from tqdm import tqdm
import cdsapi

dataset = "derived-era5-land-daily-statistics"
request = {
    "variable": ["2m_temperature"],
    "month": [
        "01", "02", "03",
        "04", "05", "06",
        "07", "08", "09",
        "10", "11", "12"
    ],
    "day": [
        "01", "02", "03",
        "04", "05", "06",
        "07", "08", "09",
        "10", "11", "12",
        "13", "14", "15",
        "16", "17", "18",
        "19", "20", "21",
        "22", "23", "24",
        "25", "26", "27",
        "28", "29", "30",
        "31"
    ],
    "daily_statistic": "daily_mean",
    "time_zone": "utc-05:00",
    "frequency": "1_hourly",
    "area": [50, -130, 20, -60]
}

years = [1970, 1980, 1990, 2000, 2010]
client = cdsapi.Client()
raw = f'/orcd/pool/003/hnaka24/climate/data/ERA5_Land_Shahine/'
os.makedirs(raw, exist_ok=True)

with tqdm(total=len(years)) as pbar:
    for year in years:
        outfile = os.path.join(raw, f"./{year}.nc")
        if os.path.exists(outfile):
            pbar.set_description(f"Skipping {year} (already exists)")
        else:
            pbar.set_description(f"Downloading for year: {year}")
            request["year"] = str(year)
            client.retrieve(dataset, request, outfile)
        _ = pbar.update(1)