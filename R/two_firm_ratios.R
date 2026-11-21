# Ratios for docs/two-firms-note.md.
#
# Reads the public figures in evidence/public_figures.csv, the source list in
# evidence/sources.csv and the two tables that R/zj_chain_curve.R writes to
# output/. The workbook is not needed. Stops if a figure is missing or listed
# twice, if a source key or unit is unknown, or if one of the identities
# described in the note does not hold. Writes output/two_firm_derived.csv.
# reference/two_firm_reference.py repeats the calculation in Python.
#
# Usage: Rscript R/two_firm_ratios.R

fields <- count.fields("evidence/public_figures.csv", sep = ",", quote = "\"", comment.char = "")
if (any(fields != 9)) stop("Row with the wrong number of fields in evidence/public_figures.csv: line ", which(fields != 9)[1])
fig  <- read.csv("evidence/public_figures.csv", colClasses = "character", encoding = "UTF-8")
src  <- read.csv("evidence/sources.csv", colClasses = "character", encoding = "UTF-8")
smry <- read.csv("output/results_summary.csv")
rk   <- read.csv("output/results_by_rank.csv")
columns <- c("firm", "scope", "indicator", "period", "value", "unit", "source", "page", "table")
if (!identical(names(fig), columns)) stop("Unexpected columns in evidence/public_figures.csv")

key <- paste(fig$firm, fig$scope, fig$indicator, fig$period)
if (anyDuplicated(key)) stop("Figure listed twice: ", key[anyDuplicated(key)])
if (anyDuplicated(src$key)) stop("Source key listed twice: ", src$key[anyDuplicated(src$key)])
unknown <- setdiff(fig$source, src$key)
if (length(unknown)) stop("Source key not in evidence/sources.csv: ", paste(unknown, collapse = ", "))
units <- c("10k_yuan", "yuan", "pct", "10k_kwh", "10k_tonnes", "gw", "mw",
           "t_per_a", "10k_pieces", "mg_per_l")
unknown <- setdiff(fig$unit, units)
if (length(unknown)) stop("Unknown unit: ", paste(unknown, collapse = ", "))
value <- suppressWarnings(as.numeric(fig$value))
if (anyNA(value)) stop("Value is not a number: ", key[is.na(value)][1])

# One documented figure, looked up by its four keys.
v <- function(firm, scope, indicator, period) {
  x <- value[key == paste(firm, scope, indicator, period)]
  if (length(x) != 1) stop("Figure not found: ", paste(firm, scope, indicator, period))
  x
}
same <- function(a, b, what, tol = 0.005) {
  if (abs(a - b) > tol) stop("Identity does not hold: ", what, " (", a, " against ", b, ")")
}
s      <- function(measure) smry$value[smry$measure == measure]
k      <- function(top_k, column) rk[rk$top_k == top_k, column]
growth <- function(new, old) 100 * (new / old - 1)

out <- list()
add <- function(name, x) out[[name]] <<- x

# Register sales of the two largest firms, from the published rank table.
c21 <- s("chain_sales_2021_100m")
c22 <- s("chain_sales_2022_100m")
m21 <- k(1, "base_share_pct") / 100 * c21
m22 <- k(1, "share_2022_pct") / 100 * c22
z21 <- k(2, "base_share_pct") / 100 * c21 - m21
z22 <- k(2, "share_2022_pct") / 100 * c22 - m22
add("meike_register_sales_2021_100m", m21)
add("meike_register_sales_2022_100m", m22)
add("cecep_register_sales_2021_100m", z21)
add("cecep_register_sales_2022_100m", z22)
add("cecep_register_growth_pct", growth(z22, z21))
add("meike_share_of_net_increase_pct", k(1, "share_of_net_increase_pct"))
add("cecep_share_of_net_increase_pct", k(2, "share_of_net_increase_pct") - k(1, "share_of_net_increase_pct"))
add("top2_share_of_net_increase_pct", k(2, "share_of_net_increase_pct"))

# Reporting scopes, in 100 million yuan.
cz  <- "cecep_zj"
reg <- "parent_region_zhenjiang"
seg <- "parent_segment_manufacturing"
mod <- "module_business"
mk  <- function(indicator, y) v("meike", "group", indicator, y)
co  <- function(indicator, y) v(cz, "company", indicator, y)
md  <- function(indicator, y) v(cz, mod, indicator, y)
register_meike <- c("2021" = m21, "2022" = m22)
for (y in c("2021", "2022")) {
  add(paste0("meike_group_revenue_", y, "_100m"), mk("revenue", y) / 1e4)
  add(paste0("meike_register_over_group_revenue_pct_", y), 100 * register_meike[[y]] / (mk("revenue", y) / 1e4))
}
for (y in c("2021", "2022")) {
  add(paste0("cecep_company_revenue_", y, "_100m"), co("revenue", y) / 1e8)
  add(paste0("cecep_region_revenue_", y, "_100m"), v(cz, reg, "revenue", y) / 1e8)
  add(paste0("cecep_segment_revenue_", y, "_100m"), v(cz, seg, "revenue", y) / 1e8)
}
add("cecep_company_revenue_growth_pct", growth(co("revenue", "2022"), co("revenue", "2021")))

# CECEP Zhenjiang module volumes. The reply's table must add up as printed,
# and the annual reports must match it as the note says.
for (y in c("2020", "2021", "2022")) {
  same(md("output", y) + md("purchased", y), md("output_plus_purchased", y), paste("reply supply", y))
  same(md("internal_use", y) + md("external_sales", y), md("internal_plus_external", y), paste("reply disposals", y))
}
for (y in c("2020", "2021")) {
  same(v(cz, seg, "production_reported", y), md("output_plus_purchased", y), paste("reported production", y))
  same(v(cz, seg, "sales_reported", y), md("internal_plus_external", y), paste("reported sales", y))
}
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
for (y in c("2021", "2022")) {
  add(paste0("cecep_purchased_share_of_supply_pct_", y), 100 * md("purchased", y) / md("output_plus_purchased", y))
}
supply_change <- md("output_plus_purchased", "2022") - md("output_plus_purchased", "2021")
output_change <- md("output", "2022") - md("output", "2021")
bought_change <- md("purchased", "2022") - md("purchased", "2021")
same(output_change + bought_change, supply_change, "split of the 2022 change in supply")
add("cecep_supply_change_2022_mw", supply_change)
add("cecep_output_change_2022_mw", output_change)
add("cecep_purchased_change_2022_mw", bought_change)

# CECEP Zhenjiang purchases from two module suppliers.
ta <- function(indicator, y) v(cz, "supplier_taineng", indicator, y)
ru <- function(indicator, y) v(cz, "supplier_ruijing", indicator, y)
same(v(cz, "parent_top5_suppliers", "supplier_one_purchases", "2022") / 1e4,
     ta("purchases_incl_vat", "2022"), "annual report supplier one is Taineng")
same(v(cz, "parent_top5_suppliers", "supplier_three_purchases", "2022") / 1e4,
     ru("purchases_incl_vat", "2022"), "annual report supplier three matches Ruijing")
add("cecep_taineng_purchases_2022_100m", ta("purchases_incl_vat", "2022") / 1e4)
add("cecep_ruijing_purchases_2022_100m", ru("purchases_incl_vat", "2022") / 1e4)

# Meike: output, purchases, energy and returns.
for (y in c("2021", "2022")) {
  same(mk("wafer_output_own", y) + mk("wafer_outsourced_processing", y), mk("wafer_output_total", y),
       paste("Meike wafer output", y), tol = 0.015)
  same(mk("wafer_output_own_pieces", y) + mk("wafer_outsourced_processing_pieces", y), mk("wafer_output_total_pieces", y),
       paste("Meike wafer output in pieces", y))
}
pieces_share <- 100 * mk("wafer_outsourced_processing_pieces", "2022") / mk("wafer_output_total_pieces", "2022")
same(pieces_share, mk("wafer_outsourced_share_by_pieces", "2022"), "Meike outsourced share by pieces 2022")
add("meike_wafer_outsourced_share_by_pieces_pct_2022", pieces_share)
for (y in c("2021", "2022")) {
  add(paste0("meike_electricity_", y, "_gwh"), mk("electricity", y) * 1e4 / 1e6)
  add(paste0("meike_group_net_profit_", y, "_100m"), mk("net_profit", y) / 1e4)
}
add("meike_net_profit_ratio_2022_to_2021", mk("net_profit", "2022") / mk("net_profit", "2021"))
add("meike_baotou_net_profit_over_group_net_profit_pct_2023",
    100 * v("meike", "baotou", "net_profit", "2023") / mk("net_profit", "2023"))

# CECEP Zhenjiang: net profit, in 100 million yuan.
for (y in c("2021", "2022")) {
  add(paste0("cecep_company_net_profit_", y, "_100m"), co("net_profit", y) / 1e8)
  add(paste0("cecep_manufacturing_net_profit_after_elimination_", y, "_100m"),
      v(cz, "manufacturing_after_elimination", "net_profit", y) / 1e4)
}

# CECEP Zhenjiang: discharge tables in the four reports.
pollutants <- c("ammonia_nitrogen", "total_phosphorus", "total_nitrogen", "cod", "fluoride", "suspended_solids")
reports <- c("2022H1_report", "2022_annual_report", "2023H1_report", "2023_annual_report")
disclosed <- function(p, r) co(paste0("discharge_", p), r)
approved  <- function(p, r) co(paste0("approved_", p), r)
add("cecep_pollutants_with_same_approved_total_in_four_reports",
    sum(sapply(pollutants, function(p) length(unique(sapply(reports, function(r) approved(p, r)))) == 1)))
add("cecep_pollutants_with_2022_half_year_above_2022_annual",
    sum(sapply(pollutants, function(p) disclosed(p, "2022H1_report") > disclosed(p, "2022_annual_report"))))
add("cecep_pollutants_with_2023_half_year_equal_to_2023_annual",
    sum(sapply(pollutants, function(p) disclosed(p, "2023H1_report") == disclosed(p, "2023_annual_report"))))
add("cecep_pollutants_with_2023_half_year_concentration_equal_to_annual",
    sum(sapply(pollutants, function(p) co(paste0("concentration_", p), "2023H1_report") ==
                                       co(paste0("concentration_", p), "2023_annual_report"))))
add("cecep_co2_purchased_electricity_2022_tonnes", co("co2_purchased_electricity", "2022") * 1e4)

res <- data.frame(measure = names(out), value = unlist(out, use.names = FALSE))
write.csv(res, "output/two_firm_derived.csv", row.names = FALSE)
