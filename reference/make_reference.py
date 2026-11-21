"""Python version of the analysis in R/zj_chain_curve.R.

Reads the monitoring workbook, writes reference/reference_summary_python.csv and
reference/reference_by_rank_python.csv, and reports whether they agree with the R
tables in output/ to six decimal places. The workbook is confidential and is not in
this repository.

Usage: python3 reference/make_reference.py [path/to/workbook.xlsx]
Without a path, the .xlsx file in data/ is used. Needs openpyxl.
"""
import csv
import sys
from itertools import accumulate
from pathlib import Path
from statistics import median

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parent.parent
paths = sys.argv[1:2] or list((ROOT / "data").glob("*.xlsx"))
if len(paths) != 1:
    sys.exit("Put the workbook in data/ as the only .xlsx file, or pass its path as an argument.")
wb = load_workbook(paths[0], read_only=True, data_only=True)

# Sheet 2, one row per firm: column 2 is the name, 4 is 2022 taxable sales and
# 5 is the same period of 2021, in 10,000 yuan.
firms = [(r[1], r[3], r[4]) for r in wb.worksheets[1].iter_rows(min_row=2, max_col=5, values_only=True) if r[1]]
if len(firms) != 254:
    sys.exit(f"Expected 254 firms on sheet 2, found {len(firms)}.")


def city_total(col):
    """Sales of all industrial firms above designated size (sheet 1), in 100 million yuan."""
    for r in wb.worksheets[0].iter_rows(max_col=5, values_only=True):
        if r[1] and "全市规上工业企业" in str(r[1]):
            return r[col] / 1e4


def growth_pct(new, old):
    return (new / old - 1) * 100


s22 = [f[1] for f in firms]
s21 = [f[2] for f in firms]
t21, t22 = sum(s21) / 1e4, sum(s22) / 1e4
city21, city22 = city_total(4), city_total(3)
chg = [b - a for b, a in zip(s22, s21)]
med_growth = median(growth_pct(b, a) for b, a in zip(s22, s21) if a > 0)

# Rank by 2021 sales, largest first
ranked = sorted(firms, key=lambda f: f[2], reverse=True)
r22 = [f[1] for f in ranked]
r21 = [f[2] for f in ranked]
inc = [b - a for b, a in zip(r22, r21)]
cum_base = [c / sum(r21) * 100 for c in accumulate(r21)]
cum_inc = [c / sum(inc) * 100 for c in accumulate(inc)]

by_rank = [(k,
            sum(r21[:k]) / sum(r21) * 100,
            sum(r22[:k]) / sum(r22) * 100,
            sum(inc[:k]) / sum(r21) * 100,
            sum(inc[:k]) / sum(inc) * 100,
            growth_pct(sum(r22[k:]), sum(r21[k:])))
           for k in (1, 2, 3, 5, 10, 20, 50)]


def hhi(x):
    return sum((v / sum(x)) ** 2 for v in x)


def tier_median(first, last):
    return median(growth_pct(r22[i], r21[i]) for i in range(first - 1, last) if r21[i] > 0)


def tier_declining(first, last):
    return sum(r22[i] < r21[i] for i in range(first - 1, last)) / (last - first + 1) * 100


gains_4_50 = inc[3:50]
summary = [
    ("firms", len(firms)),
    ("firms_positive_2021", sum(a > 0 for a in s21)),
    ("chain_sales_2021_100m", t21),
    ("chain_sales_2022_100m", t22),
    ("chain_growth_pct", growth_pct(t22, t21)),
    ("n_down", sum(c < 0 for c in chg)),
    ("n_up", sum(c > 0 for c in chg)),
    ("n_flat", sum(c == 0 for c in chg)),
    ("median_firm_growth_pct", med_growth),
    ("gross_gains_100m", sum(c for c in chg if c > 0) / 1e4),
    ("gross_losses_100m", sum(c for c in chg if c < 0) / 1e4),
    ("hhi_2021", hhi(s21)),
    ("hhi_2022", hhi(s22)),
    ("cr3_2021_pct", sum(sorted(s21, reverse=True)[:3]) / sum(s21) * 100),
    ("cr3_2022_reranked_pct", sum(sorted(s22, reverse=True)[:3]) / sum(s22) * 100),
    ("top3_2021_fixed_share_2022_pct", sum(r22[:3]) / sum(r22) * 100),
    ("curve_peak_pct", max(cum_inc)),
    ("curve_peak_rank", cum_inc.index(max(cum_inc)) + 1),
    ("rest_after_50_base_share_pct", 100 - cum_base[49]),
    ("rest_after_50_growth_pct", growth_pct(sum(r22[50:]), sum(r21[50:]))),
    ("top3_growth_pct", growth_pct(sum(r22[:3]), sum(r21[:3]))),
    ("rank4_50_growth_pct", growth_pct(sum(r22[3:50]), sum(r21[3:50]))),
    ("rank4_50_median_growth_pct", tier_median(4, 50)),
    ("rank4_50_share_declining_pct", tier_declining(4, 50)),
    ("rank4_50_top3_gainers_share_pct", sum(sorted(gains_4_50, reverse=True)[:3]) / sum(gains_4_50) * 100),
    ("rest_after_50_median_growth_pct", tier_median(51, len(ranked))),
    ("rest_after_50_share_declining_pct", tier_declining(51, len(ranked))),
    ("city_sales_2021_100m", city21),
    ("city_sales_2022_100m", city22),
    ("city_growth_pct", growth_pct(city22, city21)),
]

COLUMNS = ["base_share_pct", "share_2022_pct", "contribution_pp", "share_of_net_increase_pct", "rest_growth_pct"]
out = ROOT / "reference"
with open(out / "reference_summary_python.csv", "w", newline="\n", encoding="ascii") as f:
    f.write("measure,value\n")
    for name, value in summary:
        f.write(f"{name},{value:.6f}\n")
with open(out / "reference_by_rank_python.csv", "w", newline="\n", encoding="ascii") as f:
    f.write("top_k," + ",".join(COLUMNS) + "\n")
    for k, *values in by_rank:
        f.write(f"{k}," + ",".join(f"{v:.6f}" for v in values) + "\n")

# Compare with the R tables in output/ at six decimal places.
py_vals = dict(summary)
py_vals.update((f"top_{k} {c}", x) for k, *values in by_rank for c, x in zip(COLUMNS, values))
r_vals = {}
with open(ROOT / "output" / "results_summary.csv", newline="", encoding="utf-8") as f:
    r_vals.update((r["measure"], float(r["value"])) for r in csv.DictReader(f))
with open(ROOT / "output" / "results_by_rank.csv", newline="", encoding="utf-8") as f:
    r_vals.update((f"top_{r['top_k']} {c}", float(r[c])) for r in csv.DictReader(f) for c in COLUMNS)
differ = [n for n, x in py_vals.items() if n not in r_vals or f"{x:.6f}" != f"{r_vals[n]:.6f}"]
print(f"{len(py_vals)} values; {len(differ)} differ from the R tables in output/ at six decimals")
if differ:
    sys.exit("Differ: " + ", ".join(differ))
