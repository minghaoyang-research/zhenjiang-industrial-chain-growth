# Outputs

`output/results_by_rank.csv` has one row for each group of the largest 1, 2, 3, 5, 10, 20 and 50 firms, ranked by 2021 sales.

| Column | Meaning |
|---|---|
| `top_k` | number of firms in the group |
| `base_share_pct` | the group's share of chain sales in 2021 (%) |
| `share_2022_pct` | the same firms' share of chain sales in 2022 (%) |
| `contribution_pp` | the group's increase, in percentage points of chain growth |
| `share_of_net_increase_pct` | the group's increase as a share of the chain's net increase (%) |
| `rest_growth_pct` | growth of all the other firms taken together (%) |

`output/results_summary.csv` has 30 measures, one per row. Sales are in 100m yuan; shares and growth rates are in %.

| Measure | Meaning |
|---|---|
| `firms`, `firms_positive_2021` | firms in the data; those with 2021 sales above zero |
| `chain_sales_2021_100m`, `chain_sales_2022_100m`, `chain_growth_pct` | chain sales and growth |
| `n_down`, `n_up`, `n_flat` | firms whose sales fell, rose or did not change |
| `median_firm_growth_pct` | median growth of the firms with 2021 sales above zero (%) |
| `gross_gains_100m`, `gross_losses_100m` | total increase of the firms that grew; total fall of those that shrank (negative) |
| `hhi_2021`, `hhi_2022` | Herfindahl index of firm shares of chain sales, on a 0 to 1 scale |
| `cr3_2021_pct`, `top3_2021_fixed_share_2022_pct`, `cr3_2022_reranked_pct` | share of chain sales in 2021 held by the three largest firms of 2021; the same three firms' share in 2022; share in 2022 held by the three largest firms ranked on 2022 sales (see [below](#further-definitions)) |
| `curve_peak_pct`, `curve_peak_rank` | highest point of the cumulative curve and the rank at which it is reached |
| `rest_after_50_base_share_pct`, `rest_after_50_growth_pct` | the 204 firms outside the largest 50: their 2021 share and their growth as a group |
| `top3_growth_pct` | growth of the three largest firms by 2021 sales, as a group (%) |
| `rank4_50_growth_pct` | growth of the firms ranked 4th to 50th by 2021 sales, as a group (%) |
| `rank4_50_median_growth_pct` | median growth of the firms ranked 4th to 50th, over those with positive 2021 sales (%) |
| `rank4_50_share_declining_pct` | share of the firms ranked 4th to 50th whose sales fell (%) |
| `rank4_50_top3_gainers_share_pct` | share of the net increase of the firms ranked 4th to 50th that came from the three of them with the largest increases (%) |
| `rest_after_50_median_growth_pct` | median growth of the firms ranked 51st to 254th, over those with positive 2021 sales (%) |
| `rest_after_50_share_declining_pct` | share of the firms ranked 51st to 254th whose sales fell (%) |
| `city_sales_2021_100m`, `city_sales_2022_100m`, `city_growth_pct` | all industrial firms above designated size in the city |

`output/fig_concentration_curve.png` is the figure shown in the [README](../README.md). The curve plots the cumulative share of the 2022 net increase against the cumulative share of 2021 sales, adding firms from the largest down. The dashed line is where the curve would lie if every firm had grown at the chain's rate of 33.0%.

## Further definitions

- The top three share is given both ways. The three largest firms of 2021 held 34.36% of chain sales in 2022, and the three largest of 2022, ranked on 2022 sales, held 34.78%.
- Sheet 2 is read by column position, because two of its columns are headed 同期. The tax columns are not used.
