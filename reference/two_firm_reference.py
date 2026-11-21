"""Python version of R/two_firm_ratios.R.

Reads evidence/public_figures.csv, evidence/sources.csv and the two tables in
output/, makes the same checks as the R script and writes
reference/two_firm_derived_python.csv. If output/two_firm_derived.csv exists,
it also reports whether the two agree to six decimal places. It does not need
the workbook.

Usage: python3 reference/two_firm_reference.py
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UNITS = {"10k_yuan", "yuan", "pct", "10k_kwh", "10k_tonnes", "gw", "mw",
         "t_per_a", "10k_pieces", "mg_per_l"}


def read(path):
    with open(ROOT / path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


COLUMNS = ["firm", "scope", "indicator", "period", "value", "unit", "source", "page", "table"]
with open(ROOT / "evidence" / "public_figures.csv", newline="", encoding="utf-8") as f:
    if next(csv.reader(f)) != COLUMNS:
        sys.exit("Unexpected columns in evidence/public_figures.csv")
fig, sources = {}, {r["key"] for r in read("evidence/sources.csv")}
for line, r in enumerate(read("evidence/public_figures.csv"), start=2):
    if None in r or None in r.values():
        sys.exit(f"Row with the wrong number of fields in evidence/public_figures.csv: line {line}")
    key = (r["firm"], r["scope"], r["indicator"], r["period"])
    if key in fig:
        sys.exit(f"Figure listed twice: {' '.join(key)}")
    if r["source"] not in sources:
        sys.exit(f"Source key not in evidence/sources.csv: {r['source']}")
    if r["unit"] not in UNITS:
        sys.exit(f"Unknown unit: {r['unit']}")
    try:
        fig[key] = float(r["value"])
    except ValueError:
        sys.exit(f"Value is not a number: {' '.join(key)}")
smry = {r["measure"]: float(r["value"]) for r in read("output/results_summary.csv")}
rank = {int(r["top_k"]): {c: float(x) for c, x in r.items()} for r in read("output/results_by_rank.csv")}


def v(firm, scope, indicator, period):
    try:
        return fig[(firm, scope, indicator, period)]
    except KeyError:
        sys.exit(f"Figure not found: {firm} {scope} {indicator} {period}")


def same(a, b, what, tol=0.005):
    if abs(a - b) > tol:
        sys.exit(f"Identity does not hold: {what} ({a} against {b})")


def growth(new, old):
    return 100 * (new / old - 1)


out = []
add = lambda name, x: out.append((name, x))

# Register sales of the two largest firms, from the published rank table.
c21, c22 = smry["chain_sales_2021_100m"], smry["chain_sales_2022_100m"]
m21 = rank[1]["base_share_pct"] / 100 * c21
m22 = rank[1]["share_2022_pct"] / 100 * c22
z21 = rank[2]["base_share_pct"] / 100 * c21 - m21
z22 = rank[2]["share_2022_pct"] / 100 * c22 - m22
add("meike_register_sales_2021_100m", m21)
add("meike_register_sales_2022_100m", m22)
add("cecep_register_sales_2021_100m", z21)
add("cecep_register_sales_2022_100m", z22)
add("cecep_register_growth_pct", growth(z22, z21))
add("meike_share_of_net_increase_pct", rank[1]["share_of_net_increase_pct"])
add("cecep_share_of_net_increase_pct", rank[2]["share_of_net_increase_pct"] - rank[1]["share_of_net_increase_pct"])
add("top2_share_of_net_increase_pct", rank[2]["share_of_net_increase_pct"])

# Reporting scopes, in 100 million yuan.
cz, reg, seg, mod = "cecep_zj", "parent_region_zhenjiang", "parent_segment_manufacturing", "module_business"
mk = lambda indicator, y: v("meike", "group", indicator, y)
co = lambda indicator, y: v(cz, "company", indicator, y)
md = lambda indicator, y: v(cz, mod, indicator, y)
for y, register in (("2021", m21), ("2022", m22)):
    add(f"meike_group_revenue_{y}_100m", mk("revenue", y) / 1e4)
    add(f"meike_register_over_group_revenue_pct_{y}", 100 * register / (mk("revenue", y) / 1e4))
for y in ("2021", "2022"):
    add(f"cecep_company_revenue_{y}_100m", co("revenue", y) / 1e8)
    add(f"cecep_region_revenue_{y}_100m", v(cz, reg, "revenue", y) / 1e8)
    add(f"cecep_segment_revenue_{y}_100m", v(cz, seg, "revenue", y) / 1e8)
add("cecep_company_revenue_growth_pct", growth(co("revenue", "2022"), co("revenue", "2021")))

# CECEP Zhenjiang module volumes and the identities described in the note.
for y in ("2020", "2021", "2022"):
    same(md("output", y) + md("purchased", y), md("output_plus_purchased", y), f"reply supply {y}")
    same(md("internal_use", y) + md("external_sales", y), md("internal_plus_external", y), f"reply disposals {y}")
for y in ("2020", "2021"):
    same(v(cz, seg, "production_reported", y), md("output_plus_purchased", y), f"reported production {y}")
    same(v(cz, seg, "sales_reported", y), md("internal_plus_external", y), f"reported sales {y}")
same(v(cz, seg, "production_reported", "2022"),
     md("output_plus_purchased", "2022") - md("internal_use", "2022"), "reported production 2022")
same(v(cz, seg, "sales_reported", "2022"), md("external_sales", "2022"), "reported sales 2022")
add("cecep_module_output_growth_pct_2022", growth(md("output", "2022"), md("output", "2021")))
add("cecep_modules_purchased_ratio_2022_to_2021", md("purchased", "2022") / md("purchased", "2021"))
add("cecep_external_sales_growth_pct_2022", growth(md("external_sales", "2022"), md("external_sales", "2021")))
add("cecep_internal_plus_external_growth_pct_2022",
    growth(md("internal_plus_external", "2022"), md("internal_plus_external", "2021")))
add("cecep_reported_production_growth_pct_2022",
    growth(v(cz, seg, "production_reported", "2022"), v(cz, seg, "production_reported", "2021")))
for y in ("2021", "2022"):
    add(f"cecep_purchased_share_of_supply_pct_{y}", 100 * md("purchased", y) / md("output_plus_purchased", y))
supply_change = md("output_plus_purchased", "2022") - md("output_plus_purchased", "2021")
output_change = md("output", "2022") - md("output", "2021")
bought_change = md("purchased", "2022") - md("purchased", "2021")
same(output_change + bought_change, supply_change, "split of the 2022 change in supply")
add("cecep_supply_change_2022_mw", supply_change)
add("cecep_output_change_2022_mw", output_change)
add("cecep_purchased_change_2022_mw", bought_change)

# CECEP Zhenjiang purchases from two module suppliers.
ta = lambda indicator, y: v(cz, "supplier_taineng", indicator, y)
ru = lambda indicator, y: v(cz, "supplier_ruijing", indicator, y)
same(v(cz, "parent_top5_suppliers", "supplier_one_purchases", "2022") / 1e4,
     ta("purchases_incl_vat", "2022"), "annual report supplier one is Taineng")
same(v(cz, "parent_top5_suppliers", "supplier_three_purchases", "2022") / 1e4,
     ru("purchases_incl_vat", "2022"), "annual report supplier three matches Ruijing")
add("cecep_taineng_purchases_2022_100m", ta("purchases_incl_vat", "2022") / 1e4)
add("cecep_ruijing_purchases_2022_100m", ru("purchases_incl_vat", "2022") / 1e4)

# Meike: output, purchases, energy and returns.
for y in ("2021", "2022"):
    same(mk("wafer_output_own", y) + mk("wafer_outsourced_processing", y), mk("wafer_output_total", y),
         f"Meike wafer output {y}", tol=0.015)
    same(mk("wafer_output_own_pieces", y) + mk("wafer_outsourced_processing_pieces", y), mk("wafer_output_total_pieces", y),
         f"Meike wafer output in pieces {y}")
pieces_share = 100 * mk("wafer_outsourced_processing_pieces", "2022") / mk("wafer_output_total_pieces", "2022")
same(pieces_share, mk("wafer_outsourced_share_by_pieces", "2022"), "Meike outsourced share by pieces 2022")
add("meike_wafer_outsourced_share_by_pieces_pct_2022", pieces_share)
for y in ("2021", "2022"):
    add(f"meike_electricity_{y}_gwh", mk("electricity", y) * 1e4 / 1e6)
    add(f"meike_group_net_profit_{y}_100m", mk("net_profit", y) / 1e4)
add("meike_net_profit_ratio_2022_to_2021", mk("net_profit", "2022") / mk("net_profit", "2021"))
add("meike_baotou_net_profit_over_group_net_profit_pct_2023",
    100 * v("meike", "baotou", "net_profit", "2023") / mk("net_profit", "2023"))

# CECEP Zhenjiang: net profit, in 100 million yuan.
for y in ("2021", "2022"):
    add(f"cecep_company_net_profit_{y}_100m", co("net_profit", y) / 1e8)
    add(f"cecep_manufacturing_net_profit_after_elimination_{y}_100m",
        v(cz, "manufacturing_after_elimination", "net_profit", y) / 1e4)

# CECEP Zhenjiang: discharge tables in the four reports.
pol = ["ammonia_nitrogen", "total_phosphorus", "total_nitrogen", "cod", "fluoride", "suspended_solids"]
reports = ["2022H1_report", "2022_annual_report", "2023H1_report", "2023_annual_report"]
disclosed = lambda p, r: co(f"discharge_{p}", r)
approved = lambda p, r: co(f"approved_{p}", r)
add("cecep_pollutants_with_same_approved_total_in_four_reports",
    sum(len({approved(p, r) for r in reports}) == 1 for p in pol))
add("cecep_pollutants_with_2022_half_year_above_2022_annual",
    sum(disclosed(p, "2022H1_report") > disclosed(p, "2022_annual_report") for p in pol))
add("cecep_pollutants_with_2023_half_year_equal_to_2023_annual",
    sum(disclosed(p, "2023H1_report") == disclosed(p, "2023_annual_report") for p in pol))
add("cecep_pollutants_with_2023_half_year_concentration_equal_to_annual",
    sum(co(f"concentration_{p}", "2023H1_report") == co(f"concentration_{p}", "2023_annual_report") for p in pol))
add("cecep_co2_purchased_electricity_2022_tonnes", co("co2_purchased_electricity", "2022") * 1e4)

with open(ROOT / "reference" / "two_firm_derived_python.csv", "w", newline="\n", encoding="ascii") as f:
    f.write('"measure","value"\n')
    for name, x in out:
        f.write(f'"{name}",{x:.6f}\n')

r_path = ROOT / "output" / "two_firm_derived.csv"
if r_path.exists():
    r_vals = {r["measure"]: float(r["value"]) for r in read("output/two_firm_derived.csv")}
    if list(r_vals) != [name for name, _ in out]:
        sys.exit("output/two_firm_derived.csv has different measures or order")
    differ = [name for name, x in out if f"{x:.6f}" != f"{r_vals[name]:.6f}"]
    print(f"{len(out)} measures; {len(differ)} differ from output/two_firm_derived.csv at six decimals")
    if differ:
        sys.exit("Differ: " + ", ".join(differ))
else:
    print("output/two_firm_derived.csv not found, so no comparison was made")
