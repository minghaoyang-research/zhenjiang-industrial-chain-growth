# Growth concentration in Zhenjiang's new-power equipment chain, 2021 to 2022
#
# Reads the city's monitoring workbook (sheet 1: summary table; sheet 2: the 254
# firms on the chain's register, with taxable sales for 2022 and the same period
# of 2021) and writes two tables and the figure to output/.
#
# Usage, from the project folder: Rscript R/zj_chain_curve.R [path/to/workbook.xlsx]
# Without a path, the .xlsx file in data/ is used.

library(readxl)
library(ggplot2)
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))  # file names and sheet labels are in Chinese

path <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(path)) path <- list.files("data", "\\.xlsx$", full.names = TRUE)[1]
dir.create("output", showWarnings = FALSE)

# ---- Firms (sheet 2) -------------------------------------------------------------
# Columns are taken by position because two of them are headed 同期.
# 2 = firm name, 4 = 2022 taxable sales, 5 = same period of 2021, in 10,000 yuan.
raw <- read_excel(path, sheet = 2, .name_repair = "minimal")
firms <- data.frame(firm = raw[[2]], s22 = raw[[4]], s21 = raw[[5]])
firms <- firms[!is.na(firms$firm), ]
stopifnot(nrow(firms) == 254)

t21 <- sum(firms$s21) / 1e4  # in 100 million yuan
t22 <- sum(firms$s22) / 1e4
growth <- (t22 / t21 - 1) * 100

# ---- Summary table (sheet 1) -----------------------------------------------------
summ <- read_excel(path, sheet = 1, col_names = FALSE, .name_repair = "minimal")
total <- function(label, col) as.numeric(summ[[col]][grepl(label, summ[[2]], fixed = TRUE)][1]) / 1e4
city22 <- total("全市规上工业企业", 4)
city21 <- total("全市规上工业企业", 5)
# the 254 firms add up to the chain's row in the summary table
stopifnot(abs(total("新型电力", 4) - t22) < 1e-4, abs(total("新型电力", 5) - t21) < 1e-4)

# ---- Growth of individual firms --------------------------------------------------
chg <- firms$s22 - firms$s21
pos <- firms$s21 > 0  # a growth rate needs a positive base
med_growth <- median((firms$s22[pos] / firms$s21[pos] - 1) * 100)

# ---- Rank by 2021 sales ----------------------------------------------------------
r <- firms[order(firms$s21, decreasing = TRUE), ]
r$inc <- r$s22 - r$s21
cum_base <- cumsum(r$s21) / sum(r$s21) * 100  # cumulative share of 2021 sales
cum_inc  <- cumsum(r$inc) / sum(r$inc) * 100  # cumulative share of the net increase

# contribution_pp: increase / chain sales in 2021 * 100, so the firms add up to 33.0
# share_of_net_increase_pct: increase / the chain's net increase * 100
by_rank <- do.call(rbind, lapply(c(1, 2, 3, 5, 10, 20, 50), function(k) {
  top <- r[1:k, ]
  rest <- r[-(1:k), ]
  data.frame(
    top_k                     = k,
    base_share_pct            = sum(top$s21) / sum(r$s21) * 100,
    share_2022_pct            = sum(top$s22) / sum(r$s22) * 100,
    contribution_pp           = sum(top$inc) / sum(r$s21) * 100,
    share_of_net_increase_pct = sum(top$inc) / sum(r$inc) * 100,
    rest_growth_pct           = (sum(rest$s22) / sum(rest$s21) - 1) * 100
  )
}))

hhi <- function(x) sum((x / sum(x))^2)
# median growth over the firms ranked k with a positive 2021 base; share of them that shrank
tier_median    <- function(k) { k <- k[r$s21[k] > 0]; median((r$s22[k] / r$s21[k] - 1) * 100) }
tier_declining <- function(k) mean(r$s22[k] < r$s21[k]) * 100
gains_4_50 <- r$inc[4:50]

summary_vals <- c(
  firms                             = nrow(firms),
  firms_positive_2021               = sum(pos),
  chain_sales_2021_100m             = t21,
  chain_sales_2022_100m             = t22,
  chain_growth_pct                  = growth,
  n_down                            = sum(chg < 0),
  n_up                              = sum(chg > 0),
  n_flat                            = sum(chg == 0),
  median_firm_growth_pct            = med_growth,
  gross_gains_100m                  = sum(chg[chg > 0]) / 1e4,
  gross_losses_100m                 = sum(chg[chg < 0]) / 1e4,
  hhi_2021                          = hhi(firms$s21),
  hhi_2022                          = hhi(firms$s22),
  cr3_2021_pct                      = sum(sort(firms$s21, decreasing = TRUE)[1:3]) / sum(firms$s21) * 100,
  cr3_2022_reranked_pct             = sum(sort(firms$s22, decreasing = TRUE)[1:3]) / sum(firms$s22) * 100,
  top3_2021_fixed_share_2022_pct    = sum(r$s22[1:3]) / sum(r$s22) * 100,
  curve_peak_pct                    = max(cum_inc),
  curve_peak_rank                   = which.max(cum_inc),
  rest_after_50_base_share_pct      = 100 - cum_base[50],
  rest_after_50_growth_pct          = (sum(r$s22[-(1:50)]) / sum(r$s21[-(1:50)]) - 1) * 100,
  top3_growth_pct                   = (sum(r$s22[1:3]) / sum(r$s21[1:3]) - 1) * 100,
  rank4_50_growth_pct               = (sum(r$s22[4:50]) / sum(r$s21[4:50]) - 1) * 100,
  rank4_50_median_growth_pct        = tier_median(4:50),
  rank4_50_share_declining_pct      = tier_declining(4:50),
  rank4_50_top3_gainers_share_pct   = sum(sort(gains_4_50, decreasing = TRUE)[1:3]) / sum(gains_4_50) * 100,
  rest_after_50_median_growth_pct   = tier_median(51:nrow(r)),
  rest_after_50_share_declining_pct = tier_declining(51:nrow(r)),
  city_sales_2021_100m              = city21,
  city_sales_2022_100m              = city22,
  city_growth_pct                   = (city22 / city21 - 1) * 100
)

write.csv(by_rank, "output/results_by_rank.csv", row.names = FALSE)
write.csv(data.frame(measure = names(summary_vals), value = unname(summary_vals)),
          "output/results_summary.csv", row.names = FALSE)

# ---- Figure ----------------------------------------------------------------------
curve <- data.frame(x = c(0, cum_base), y = c(0, cum_inc))
pts <- data.frame(x = cum_base[c(1, 3, 50)], y = cum_inc[c(1, 3, 50)])
rest_g <- summary_vals[["rest_after_50_growth_pct"]]

lab1 <- sprintf("Largest firm\n%.1f%% of 2021 sales, %.1f%% of the net increase", pts$x[1], pts$y[1])
lab3 <- sprintf("3 largest firms\n%.1f%% of 2021 sales, %.1f%% of the net increase", pts$x[2], pts$y[2])
lab50 <- sprintf("50 largest firms\n%.1f%% of 2021 sales, %.1f%% of the net increase", pts$x[3], pts$y[3])
labrest <- sprintf("Other %d firms\n%.1f%% of 2021 sales\n%s %.2f%% as a group",
                   nrow(r) - 50, 100 - cum_base[50], ifelse(rest_g < 0, "shrank", "grew"), abs(rest_g))

p <- ggplot() +
  annotate("rect", xmin = pts$x[3], xmax = 100, ymin = 0, ymax = 117, fill = "grey95") +
  geom_hline(yintercept = seq(20, 100, 20), colour = "grey90", linewidth = 0.3) +
  annotate("segment", x = 0, y = 0, xend = 100, yend = 100,
           colour = "grey60", linewidth = 0.45, linetype = "22") +
  geom_path(data = curve, aes(x, y), colour = "dodgerblue3", linewidth = 0.9) +
  geom_point(data = pts, aes(x, y), shape = 21, size = 3.2, fill = "dodgerblue3",
             colour = "white", stroke = 1.1) +
  annotate("segment", x = pts$x[1] + 0.9, y = pts$y[1] + 0.4, xend = 11.6, yend = 61.2,
           colour = "grey35", linewidth = 0.3) +
  annotate("text", x = 12, y = 60, label = lab1, hjust = 0, size = 3, lineheight = 1) +
  annotate("segment", x = pts$x[2] + 0.9, y = pts$y[2] - 0.9, xend = 23.6, yend = 75,
           colour = "grey35", linewidth = 0.3) +
  annotate("text", x = 24, y = 73, label = lab3, hjust = 0, size = 3, lineheight = 1) +
  annotate("segment", x = pts$x[3] - 0.9, y = pts$y[3] + 1, xend = 65.4, yend = 107.5,
           colour = "grey35", linewidth = 0.3) +
  annotate("text", x = 65, y = 110, label = lab50, hjust = 1, size = 3, lineheight = 1) +
  annotate("text", x = (pts$x[3] + 100) / 2, y = 24, label = labrest, size = 3, lineheight = 1.1) +
  annotate("text", x = 84, y = 80.5, label = sprintf("If every firm had grown %.1f%%", growth),
           angle = 22, vjust = 1, size = 2.8, colour = "grey35") +
  scale_x_continuous(breaks = seq(0, 100, 20)) +
  scale_y_continuous(breaks = seq(0, 100, 20)) +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 117), expand = FALSE, clip = "off") +
  labs(
    title = "The three largest firms accounted for over three quarters of the 2022 net increase",
    subtitle = sprintf("Zhenjiang new-power equipment chain, %d firms. Taxable sales %+.1f%% in 2022, median firm %+.2f%%",
                       nrow(firms), growth, med_growth),
    x = "Cumulative share of 2021 taxable sales, firms ranked from largest (%)",
    y = "Cumulative share of the 2022 net increase (%)",
    caption = paste("Source: municipal monitoring data compiled at the Zhenjiang Academy of Social Sciences in 2023, used with permission.",
                    "Nominal taxable sales. Firms ranked by 2021 sales.", sep = "\n")
  ) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid = element_blank(),
    axis.text = element_text(colour = "grey35"),
    axis.title = element_text(colour = "grey35", size = 9),
    axis.title.x = element_text(margin = margin(t = 8)),
    axis.title.y = element_text(margin = margin(r = 8)),
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9.5, colour = "grey35", margin = margin(b = 12)),
    plot.caption = element_text(size = 7.5, colour = "grey35", hjust = 0, margin = margin(t = 10)),
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.margin = margin(14, 16, 10, 10)
  )

ggsave("output/fig_concentration_curve.png", p, width = 7.2, height = 4.6, dpi = 200, bg = "white")
