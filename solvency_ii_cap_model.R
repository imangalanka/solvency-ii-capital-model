# =============================================================================
# PROJECT:  Simplified Solvency II-Style Capital Model
#           Hypothetical Lloyd's Syndicate "ABA 1234"
#
# AUTHOR:   Imanga Lankathilaka
# DATE:     May 2026
# VERSION:  1.0
#
# PURPOSE:
#   To build a simple but structurally sound capital model for a
#   hypothetical Lloyd's syndicate, broadly consistent with the Solvency II
#   Standard Formula framework. The model quantifies the Solvency Capital
#   Requirement (SCR) across four key risk modules and aggregates them using
#   a correlation matrix to produce a total capital requirement.
#
# REGULATORY CONTEXT:
#   Under Solvency II (Directive 2009/138/EC), insurers must hold capital
#   equal to the 99.5th percentile Value-at-Risk (VaR) of basic own funds
#   over a one-year time horizon. The Standard Formula provides a prescribed
#   method for calculating the SCR by risk module, using:
#     - Stress factors applied to volumes (premium, reserve, cat, market)
#     - A prescribed correlation matrix to aggregate risk charges
#
#   This model is a simplified approximation of the Standard Formula.
#   It is illustrative only and should not be used for regulatory submissions.
#
# RISK MODULES COVERED:
#   1. Premium Risk    — Potential losses on unearned/future business
#   2. Reserve Risk    — Adverse development of IBNR reserves
#   3. Catastrophe Risk — 1-in-200 catastrophe loss estimate
#   4. Market Risk     — Simplified interest rate / asset value stress
#
# AGGREGATION:
#   Risk charges are combined using a Solvency II-style correlation matrix
#   via the standard quadratic formula:
#   SCR_total = sqrt(sum_i sum_j rho_ij * SCR_i * SCR_j)
#
# PACKAGES REQUIRED:
#   ggplot2   — Visualisation
#   dplyr     — Data manipulation
#   scales    — Axis formatting
#
# LIMITATIONS:
#   - Standard Formula simplifications applied throughout
#   - Cat risk uses a simplified RDS (Reference Damage Scenario) approach
#   - Operational risk not modelled (typically ~3% of BSCR in standard formula)
#   - No allowance for risk mitigation (reinsurance, diversification by LoB)
#   - One-year VaR basis assumed throughout; multi-year risks not considered
#   - Asset portfolio is simplified; credit and liquidity risk excluded
#
# PEER REVIEW STATUS: Draft — prepared for learning purposes, not peer reviewed
# =============================================================================


# -----------------------------------------------------------------------------
# 0. ENVIRONMENT SETUP
# -----------------------------------------------------------------------------

rm(list = ls())       # Clear workspace
set.seed(42)          # Reproducibility

# Install packages if not already present
# repos argument prevents interactive mirror selection prompt
required_packages <- c("ggplot2", "dplyr", "scales")
new_packages <- required_packages[!(required_packages %in%
                                      installed.packages()[, "Package"])]
if (length(new_packages) > 0) {
  install.packages(new_packages, repos = "https://cloud.r-project.org")
}

library(ggplot2)
library(dplyr)
library(scales)

getwd()


# =============================================================================
# 1. SYNDICATE PROFILE — HYPOTHETICAL "ABA 1234"
# =============================================================================
# We define a small-to-mid-size Lloyd's syndicate writing predominantly
# Property and Casualty business. All figures in £millions.
#
# These inputs would come from the syndicate's business plan in practice.
# We keep the portfolio simple: two lines of business.
# =============================================================================

cat("  LLOYD'S SYNDICATE ABA 1234 — CAPITAL MODEL\n")
cat("  Solvency II Standard Formula (Simplified)\n")

# --- Syndicate Overview ---
syndicate_name  <- "ABA 1234"
reporting_year  <- 2026
currency        <- "GBP"

cat(sprintf("Syndicate   : %s\n", syndicate_name))
cat(sprintf("Report Year : %d\n", reporting_year))
cat(sprintf("Currency    : %s(£m)\n\n",currency))

# --- Lines of Business ---
# Property: short-tail, high cat exposure
# Casualty: longer tail, lower cat exposure
# Note: "Casualty" used here consistent with Lloyd's market convention
# In the broader UK GI market this class would typically be termed "Liability"
lob_names       <- c("Property", "Casualty")

# Gross Written Premium (GWP) by line (£m)
gwp             <- c(Property = 80, Casualty = 50)

# Net Earned Premium (NEP) — after reinsurance, ~75% of GWP (simplified)
# In practice this would reflect the actual reinsurance program
nep_ratio       <- 0.75
nep             <- gwp * nep_ratio

# Best estimate loss ratio by line (used in premium risk)
# Reflects actuarial best estimate of ultimate loss ratio
be_loss_ratio   <- c(Property = 0.60, Casualty = 0.65)
# Not used in base case SCR — this model uses NEP as volume measure
# Would be used in an extended model incorporating loss ratio risk explicitly

# Best estimate IBNR reserves by line (£m)
# Represents the net undiscounted best estimate of outstanding claims
be_reserves     <- c(Property = 45, Casualty = 75)

# Asset portfolio (simplified) (£m)
# Mostly bonds — typical for a Lloyd's syndicate

# Weighted average liability duration by line (years)
# Property: short-tail ~1 year average settlement
# Casualty: longer-tail ~4 year average settlement
# Weighted by reserves: (45 x 1 + 75 x 4) / 120 = 2.875 years
liability_duration <- (be_reserves["Property"] * 1 + be_reserves["Casualty"] * 4)/
                      sum(be_reserves)

# Then use it in BEL discounting
discount_rate <- 0.04
bel <- sum(be_reserves) / (1 + discount_rate)^liability_duration

risk_margin    <- bel * 0.08                # Risk margin ~8% of BEL (simplified)
premium_provs  <- sum(gwp) * 0.50 * nep_ratio  # Unearned premium (half year)
tech_provisions <- bel + risk_margin + premium_provs

# Simplified Own Funds (£m)
# Tier 1 capital: members' funds, retained earnings
# In practice, Own Funds = Assets - Technical Provisions (Solvency II basis)
own_funds_tier1 <- 95   # Tier 1 capital (highest quality)
own_funds_tier2 <- 15   # Tier 2 (e.g. subordinated debt, Letters of Credit)
total_own_funds <- own_funds_tier1 + own_funds_tier2

total_assets   <- tech_provisions + total_own_funds

#Asset allocation
bond_allocation <- 0.70  # 70% fixed income
equity_alloc    <- 0.10  # 10% equities
cash_alloc      <- 0.20  # 20% cash / money market

cat("--- SYNDICATE PORTFOLIO SUMMARY ---\n")
cat(sprintf("  GWP (Property)     : £%.0fm\n", gwp["Property"]))
cat(sprintf("  GWP (Casualty)     : £%.0fm\n", gwp["Casualty"]))
cat(sprintf("  Total GWP          : £%.0fm\n", sum(gwp)))
cat(sprintf("  Total NEP          : £%.0fm\n", sum(nep)))
cat(sprintf("  BE Reserves (Prop) : £%.0fm\n", be_reserves["Property"]))
cat(sprintf("  BE Reserves (Cas)  : £%.0fm\n", be_reserves["Casualty"]))
cat(sprintf("  Total BE Reserves  : £%.0fm\n", sum(be_reserves)))
cat(sprintf("  BEL (Discounted)   : £%.0fm\n", bel))
cat(sprintf("  Risk Margin        : £%.0fm\n", risk_margin))
cat(sprintf("  Premium Provisions : £%.0fm\n", premium_provs))
cat(sprintf("  Tech Provisions    : £%.0fm\n", tech_provisions))
cat(sprintf("  Total Assets       : £%.0fm\n\n", total_assets))

# =============================================================================
# 2. RISK MODULE 1 — PREMIUM RISK
# =============================================================================
# Premium risk is the risk of loss on business written or to be written
# during the next 12 months being worse than expected.
#
# Method: Volume-based stress approach (High-level approximation of the Standard Formula)
#   SCR_prem = NEP x sigma_prem x stress_factor
#
# Where:
#   NEP             = Net Earned Premium (volume measure)
#   sigma_prem      = Premium risk standard deviation (by line of business)
#   stress_factor   = 3; Simplified conservative 99.5% capital factor,
#                        allowing for skewness/lognormal-type loss behaviour 
#
# =============================================================================

cat("RISK MODULE 1: PREMIUM RISK\n")

# Standard deviation of premium risk by line (from EIOPA Standard Formula)
# These reflect the inherent volatility of each class of business
sigma_prem <- c(Property = 0.10,   # Property: moderate volatility
                Casualty = 0.13)   # Casualty: higher volatility, longer tail

stress_factor <- 3

# SCR for premium risk by line (£m)
# Note: Standard Formula uses a non-linear formula; we use a simplified
# linear stress for clarity and transparency at this level

scr_prem_vec <- nep * sigma_prem * stress_factor

# Aggregate premium risk SCR across lines using correlation
# Rows/Cols represent the lines of business written by this syndicate:
#   LoB 6 = Fire and other damage to property (Property)
#   LoB 4 = General liability (Casualty/Liability)
# Full 12x12 matrix prescribed by EIOPA — subset here to lines written only

eiopa_lob_corr <- matrix(
  c(1.00, 0.25,   # Property vs Property, Property vs Casualty
    0.25, 1.00),  # Casualty vs Property, Casualty vs Casualty
  nrow = 2,
  ncol = 2,
  dimnames = list(c("Property", "Casualty"),
                  c("Property", "Casualty"))
)

# Aggregate premium risk SCR using EIOPA prescribed LoB correlations
# Quadratic formula: SCR = sqrt( SCR^T x CorrMatrix x SCR )

scr_prem <- sqrt(as.numeric(
  t(scr_prem_vec) %*% eiopa_lob_corr %*% scr_prem_vec
))


cat(sprintf("  NEP (Property)          : £%.1fm\n", nep["Property"]))
cat(sprintf("  NEP (Casualty)          : £%.1fm\n", nep["Casualty"]))
cat(sprintf("  Sigma (Property)        : %.0f%%\n", sigma_prem["Property"] * 100))
cat(sprintf("  Sigma (Casualty)        : %.0f%%\n", sigma_prem["Casualty"] * 100))
cat(sprintf("  SCR Premium (Property)  : £%.1fm\n", scr_prem_vec["Property"]))
cat(sprintf("  SCR Premium (Casualty)  : £%.1fm\n", scr_prem_vec["Casualty"]))
cat("  EIOPA LoB Correlation Matrix:\n")
print(eiopa_lob_corr)
cat(sprintf("  SCR Premium Risk (Total): £%.1fm\n\n", scr_prem))

# =============================================================================
# 3. RISK MODULE 2 — RESERVE RISK
# =============================================================================
# Reserve risk is the risk that best estimate IBNR reserves are insufficient
# to cover the ultimate cost of claims already incurred.
#
# Method: Volume-based stress (Standard Formula approach)
#   SCR_res = BE_Reserves x sigma_res x stress_factor
#
# Where:
#   BE_Reserves     = Best estimate net IBNR reserves (volume measure)
#   sigma_res       = Reserve risk standard deviation by lin
#   stress_factor   = 3; Simplified conservative 99.5% capital factor,
#                        allowing for skewness/lognormal-type loss behaviour
#
# Key point: Reserve risk sigma tends to be lower than premium risk sigma
# for the same line, as reserves are already informed by claims experience.
# =============================================================================

cat("RISK MODULE 2: RESERVE RISK\n")

# Reserve risk standard deviations by line (EIOPA Standard Formula values)
sigma_res <- c(Property = 0.10,   # Property: well-developed triangles
               Casualty = 0.11)   # Casualty: more tail uncertainty



# SCR for reserve risk by line (£m)
scr_res_vec <- be_reserves * sigma_res * stress_factor

# Aggregate reserve risk SCR using same correlation structure as premium
scr_res <- sqrt(as.numeric(
  t(scr_res_vec) %*% eiopa_lob_corr %*% scr_res_vec
))

cat(sprintf("  BE Reserves (Property)  : £%.1fm\n", be_reserves["Property"]))
cat(sprintf("  BE Reserves (Casualty)  : £%.1fm\n", be_reserves["Casualty"]))
cat(sprintf("  Sigma (Property)        : %.0f%%\n", sigma_res["Property"] * 100))
cat(sprintf("  Sigma (Casualty)        : %.0f%%\n", sigma_res["Casualty"] * 100))
cat(sprintf("  SCR Reserve (Property)  : £%.1fm\n", scr_res_vec["Property"]))
cat(sprintf("  SCR Reserve (Casualty)  : £%.1fm\n", scr_res_vec["Casualty"]))
cat("  EIOPA LoB Correlation Matrix:\n")
print(eiopa_lob_corr)
cat(sprintf("  SCR Reserve Risk (Total): £%.1fm\n\n", scr_res))


# =============================================================================
# 4. RISK MODULE 3 — CATASTROPHE RISK
# =============================================================================
# Catastrophe risk is the risk of loss from a single large event or series
# of events — e.g. a major UK windstorm or US hurricane.
#
# Method: Reference Damage Scenario (RDS) approach
#   We define a 1-in-200 catastrophe scenario for each peril and take the
#   largest single event loss net of reinsurance as the cat SCR.
#
# This is a simplification of the Standard Formula Cat module, which uses
# prescribed scenarios or an internal cat model.
# In Lloyd's practice, syndicates typically use vendor cat models
# (RMS, AIR) to produce exceedance probability curves.
#
# Perils modelled:
#   - UK Windstorm (main nat cat peril for UK Property)
#   - US Hurricane (common Lloyd's cat exposure via open market)
# =============================================================================

cat("RISK MODULE 3: CATASTROPHE RISK\n")

# 1-in-200 gross loss scenarios by peril (£m)
# These are illustrative RDS losses — in practice from a cat model output
cat_scenarios_gross <- c(
  UK_Windstorm  = 60,    # Large UK winter storm event
  US_Hurricane  = 90     # Major Gulf of Mexico hurricane making landfall
)

# Reinsurance recovery rate per peril
# Property XL programme provides meaningful protection
ri_recovery_rate <- c(
  UK_Windstorm  = 0.60,   # 60% recovered under property cat XL
  US_Hurricane  = 0.65    # 65% recovered (higher limit purchased for US)
)

# Net cat loss per peril after reinsurance recovery
cat_scenarios_net <- cat_scenarios_gross * (1 - ri_recovery_rate)

# SCR cat = largest single net peril loss (conservative, simplified approach)
# Standard Formula would aggregate across perils using prescribed correlations
scr_cat <- max(cat_scenarios_net)
dominant_peril <- names(which.max(cat_scenarios_net))

cat(sprintf("  UK Windstorm (Gross)    : £%.1fm\n", cat_scenarios_gross["UK_Windstorm"]))
cat(sprintf("  UK Windstorm (Net RI)   : £%.1fm\n", cat_scenarios_net["UK_Windstorm"]))
cat(sprintf("  US Hurricane (Gross)    : £%.1fm\n", cat_scenarios_gross["US_Hurricane"]))
cat(sprintf("  US Hurricane (Net RI)   : £%.1fm\n", cat_scenarios_net["US_Hurricane"]))
cat(sprintf("  Dominant Peril          : %s\n", dominant_peril))
cat(sprintf("  SCR Catastrophe Risk    : £%.1fm\n\n", scr_cat))


# =============================================================================
# 5. RISK MODULE 4 — MARKET RISK (SIMPLIFIED)
# =============================================================================
# Market risk is the risk of loss from adverse movements in financial markets
# — interest rates, equity prices, credit spreads, currency, etc.
#
# Method: ALM Net Shock Approach (interest rate) + Prescribed Stress (equity)
#
# 5.1 Interest Rate Risk
#   Both upward and downward parallel shift shocks applied to the balance sheet
#   consistent with Solvency II Standard Formula interest rate sub-module.
#   The net impact is calculated on an ALM basis:
#     Rate UP   (+100bps): Bond prices fall, technical provisions decrease
#     Rate DOWN (-75bps) : Bond prices rise, technical provisions increase
#   SCR = max(net_loss_up, net_loss_down, 0)
#
#   Note: EIOPA prescribes term-structure shocks (different bps by maturity)
#   not a flat parallel shift. A parallel shock is used here as a simplification
#   — this understates risk for portfolios with significant long-duration
#   bond exposure. Liability duration of 2.875 years defined in Section 1
#   and referenced consistently here.
#
# 5.2 Equity Risk
#   39% stress applied to Type 1 equities (listed equities in EEA/OECD markets)
#   consistent with Solvency II Standard Formula equity sub-module.
#
# 5.3 Cash
#   No stress applied — assumed risk-free in this simplified model.
#
# Sub-modules aggregated by simple summation (conservative — no diversification
# benefit taken). Standard Formula prescribes a correlation matrix across
# market risk sub-modules which would reduce the total market risk SCR.
#
# Sub-modules NOT modelled (limitations):
#   - Spread risk        : Credit spread widening on bond portfolio
#   - Currency risk      : FX movements on non-GBP exposures
#   - Property risk      : Direct real estate holdings (none assumed)
#   - Concentration risk : Single counterparty exposure limits
# =============================================================================

cat("RISK MODULE 4: MARKET RISK (SIMPLIFIED)\n")

# Asset values by class (£m)
asset_bonds    <- total_assets * bond_allocation
asset_equity   <- total_assets * equity_alloc
asset_cash     <- total_assets * cash_alloc

# 5.1 Interest Rate risk module (ALM Net Shock Approach)

bond_duration        <- 3.0      # years (typical for short-duration insurer portfolio)
# liability_duration= 2.875 yrs, Weighted average duration of liabilities as per section 1

# Shocks defined (EIOPA currency-specific shocks are curve-dependent, parallel approximations used here)
rate_stress_up     <- 0.0100    # +100 basis points
rate_stress_down   <- 0.0075    # -75 basis points (prescribed for GBP/EUR at short durations)

# Convention: net_loss = loss on assets - gain on liabilities (or vice versa)
# Positive value = net loss to the syndicate

# Scenario A: Interest Rate UP Shock

# Bond stress: simplified duration-based interest rate stress
# Interest rate UP shock — decrease Bond price
bond_loss_up      <- asset_bonds * bond_duration * rate_stress_up 
tp_decrease_up    <- tech_provisions * liability_duration * rate_stress_up 
net_loss_up       <- bond_loss_up - tp_decrease_up


# Scenario B: Interest Rate DOWN Shock

bond_gain_down       <- asset_bonds * bond_duration * rate_stress_down
tp_increase_down     <- tech_provisions * liability_duration * rate_stress_down
net_loss_down        <- tp_increase_down - bond_gain_down


# SCR interest rate = worse of up and down shock, floored at zero
scr_interest <- max(net_loss_up, net_loss_down,0)
dominant_shock <- ifelse(net_loss_up >= net_loss_down, "Rate Up", "Rate Down")

# 5.2 Equity stress

# Standard Formula prescribes 39% stress for Type 1 equities
equity_stress_pct <- 0.39
equity_loss  <- asset_equity * equity_stress_pct

# 5.3 Cash
# Cash assumed risk-free in this simplified model
cash_loss    <- 0   

# Market risk SCR = sum of stressed losses (simplified, no diversification)
# In Standard Formula, sub-modules are correlated; we conservatively sum here
scr_market <- scr_interest + equity_loss + cash_loss

cat(sprintf("  Bond Portfolio Value    : £%.1fm (Duration: %.1f yrs)\n", asset_bonds, bond_duration))
cat(sprintf("  Net Technical Provisions: £%.1fm (Duration: %.1f yrs)\n", tech_provisions, liability_duration))
cat(sprintf("  Rate Up Net Loss        : £%.1fm\n", net_loss_up))
cat(sprintf("  Rate Down Net Loss      : £%.1fm\n", net_loss_down))
cat(sprintf("  Dominant Interest Shock : %s\n", dominant_shock))
cat(sprintf("  SCR Interest Rate (Net) : £%.1fm\n", scr_interest))
cat(sprintf("  Equity Portfolio Value  : £%.1fm (Stress: %.0f%%)\n", asset_equity, equity_stress_pct * 100))
cat(sprintf("  SCR Equity Risk         : £%.1fm\n", equity_loss))
cat(sprintf("  SCR Market Risk (Total) : £%.1fm\n\n", scr_market))


# =============================================================================
# 6. AGGREGATION — TOTAL SCR
# =============================================================================
# Two-step aggregation consistent with Solvency II Standard Formula structure
# (Delegated Regulation 2015/35, Annex IV)
#
# STEP 1: Premium + Reserve → Non-Life Underwriting Risk (rho = 0.50)
# STEP 2: Non-Life UW + Cat + Market → Total SCR (top-level corr matrix)
#
# LIMITATIONS:
#   Non-Life UW usually included Catastrophe Risk along with Lapse Risk
#   however is this model Catastrophe Risk is used in the top level.
#   Operational risk, counterparty default risk, and life/health risk
#   sub-modules not modelled — this model covers non-life underwriting
#   and market risk only.
# =============================================================================

cat("AGGREGATION: TOTAL SCR\n")
cat("  Standard Formula Two-Step Aggregation Structure\n")


# STEP 1: INNER AGGREGATION — Non-Life Premium & Reserve Risk

# Prescribed correlation of 0.50 between premium and reserve risk
# Source: Solvency II Delegated Regulation (EU) 2015/35, Annex IV
corr_prem_res   <- 0.50
scr_nl_prem_res <- sqrt(scr_prem^2 + scr_res^2 +
                          2 * corr_prem_res * scr_prem * scr_res)


# STEP 2: TOP-LEVEL AGGREGATION

scr_top_modules <- c(
  NonLife_UW  = as.numeric(scr_nl_prem_res),
  Catastrophe = as.numeric(scr_cat),
  Market      = as.numeric(scr_market)
)

n_top <- length(scr_top_modules)

# Top-level correlation matrix
# Non-Life UW vs Cat    = 0.25 
# Non-Life UW vs Market = 0.25 
# Cat vs Market         = 0.00 (catastrophe events not assumed to move markets)
corr_matrix_top <- matrix(
  c(1.00, 0.25, 0.25,
    0.25, 1.00, 0.00,
    0.25, 0.00, 1.00),
  nrow = n_top, ncol = n_top,
  dimnames = list(names(scr_top_modules), names(scr_top_modules))
)

cat("  Top-Level Regulatory Correlation Matrix:\n")
print(round(corr_matrix_top, 2))
cat("\n")

# Total SCR via quadratic aggregation formula
scr_total <- sqrt(as.numeric(
  t(scr_top_modules) %*% corr_matrix_top %*% scr_top_modules
))

# Simple sum across all four base risks — for diversification comparison
scr_sum_no_div  <- sum(scr_prem, scr_res, scr_cat, scr_market)
div_benefit     <- scr_sum_no_div - scr_total
div_benefit_pct <- (div_benefit / scr_sum_no_div) * 100

# -------------------------------------------------------------
# OUTPUT
# -------------------------------------------------------------
cat(sprintf("  SCR Premium Risk        : £%.1fm\n", scr_prem))
cat(sprintf("  SCR Reserve Risk        : £%.1fm\n", scr_res))
cat(sprintf("  [Non-Life UW Sub-Total] : £%.1fm\n", scr_nl_prem_res))
cat(sprintf("  SCR Catastrophe Risk    : £%.1fm\n", scr_cat))
cat(sprintf("  SCR Market Risk         : £%.1fm\n", scr_market))
cat("  ---------------------------------------\n")
cat(sprintf("  Sum (no diversification): £%.1fm\n", scr_sum_no_div))
cat(sprintf("  Diversification Benefit : £%.1fm (%.1f%%)\n",
            div_benefit, div_benefit_pct))
cat(sprintf("  TOTAL SCR               : £%.1fm\n\n", scr_total))

# =============================================================================
# 7. OWN FUNDS & SOLVENCY POSITION
# =============================================================================
# The Solvency Capital Requirement alone is insufficient — we also need to
# assess the syndicate's available capital (Own Funds) to determine whether
# it is adequately capitalised.
#
# Solvency Ratio = Eligible Own Funds / SCR
# A ratio > 100% means the syndicate meets its capital requirement.
# Lloyd's syndicates are typically capitalised well above 100% (Funds at Lloyd's)
# =============================================================================

cat("SOLVENCY POSITION\n")


# Solvency ratio
solvency_ratio  <- (total_own_funds / scr_total) * 100

# Capital surplus / deficit
capital_surplus <- total_own_funds - scr_total

cat(sprintf("  Tier 1 Own Funds        : £%.1fm\n", own_funds_tier1))
cat(sprintf("  Tier 2 Own Funds        : £%.1fm\n", own_funds_tier2))
cat(sprintf("  Total Own Funds         : £%.1fm\n", total_own_funds))
cat(sprintf("  Total SCR               : £%.1fm\n", scr_total))
cat(sprintf("  Capital Surplus         : £%.1fm\n", capital_surplus))
cat(sprintf("  Solvency Ratio          : %.0f%%\n\n", solvency_ratio))

if (solvency_ratio >= 130) {
  cat("  STATUS: Well capitalised (Solvency Ratio > 130%)\n\n")
} else if (solvency_ratio >= 100) {
  cat("  STATUS: Adequately capitalised (Solvency Ratio 100-130%)\n\n")
} else {
  cat("  STATUS: WARNING — Solvency Ratio below 100%. Capital action required.\n\n")
}


# =============================================================================
# 8. VISUALISATION
# =============================================================================
# Three charts:
#   (a) SCR waterfall by risk module
#   (b) Solvency position (own funds vs SCR)
#   (c) Diversification benefit illustration
# =============================================================================
# --- 8a. Gross Risk Charges by Component (Pre-Diversification) ---
# Shows where risk originates before any aggregation
# Four individual module charges — useful for understanding risk drivers

scr_df <- data.frame(
  Module = c("Premium", "Reserve", "Cat", "Market"),
  SCR    = c(scr_prem, scr_res, scr_cat, scr_market)
)
scr_df$Module <- factor(scr_df$Module, levels = scr_df$Module)

p1a <- ggplot(scr_df, aes(x = Module, y = SCR, fill = Module)) +
  geom_bar(stat = "identity", width = 0.6) +
  geom_text(aes(label = sprintf("£%.1fm", SCR)),
            vjust = -0.5, size = 4, fontface = "bold") +
  scale_fill_manual(values = c(
    Premium  = "blue",
    Reserve  = "orange",
    Cat      = "green",
    Market   = "red"
  )) +
  scale_y_continuous(
    labels = label_comma(prefix = "£", suffix = "m"),
    limits = c(0, max(scr_prem, scr_res, scr_cat, scr_market) * 1.2)
  ) +
  labs(
    title    = sprintf("%s — Gross Risk Charges by Component", syndicate_name),
    subtitle = "Pre-diversification charges | Does not reflect two-step aggregation structure",
    x        = "Risk Component",
    y        = "SCR (£m)",
    caption  = "Note: Premium and Reserve risk are combined into Non-Life UW before top-level aggregation"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title         = element_text(face = "bold", size = 14),
    plot.subtitle      = element_text(colour = "grey"),
    legend.position    = "none",
    panel.grid.major.x = element_blank()
  )

print(p1a)

ggsave("charts/01a_gross_risk_charges.png", plot = p1a,
       width = 10, height = 6, dpi = 150)

# --- 8b. Aggregated SCR by Top-Level Module (Standard Formula Structure) ---
# Shows the three top-level modules after Step 1 inner aggregation
# Consistent with the two-step Standard Formula aggregation in Section 6

scr_top_df <- data.frame(
  Module = c("Non-Life UW\n(Prem + Res)", "Catastrophe", "Market"),
  SCR    = c(scr_nl_prem_res, scr_cat, scr_market)
)
scr_top_df$Module <- factor(scr_top_df$Module, levels = scr_top_df$Module)

p1b <- ggplot(scr_top_df, aes(x = Module, y = SCR, fill = Module)) +
  geom_bar(stat = "identity", width = 0.6) +
  geom_text(aes(label = sprintf("£%.1fm", SCR)),
            vjust = -0.5, size = 4, fontface = "bold") +
  # Add total SCR reference line
  geom_hline(yintercept = scr_total, linetype = "dashed",
             colour = "grey", linewidth = 0.8) +
  annotate("text",
           x     = 3.4,
           y     = scr_total,
           label = sprintf("Total SCR\n£%.1fm", scr_total),
           size  = 3.5, colour = "grey", hjust = 0) +
  scale_fill_manual(values = c(
    "Non-Life UW\n(Prem + Res)" = "blue",
    "Catastrophe"               = "green",
    "Market"                    = "red"
  )) +
  scale_y_continuous(
    labels = label_comma(prefix = "£", suffix = "m"),
    limits = c(0, max(scr_nl_prem_res, scr_cat, scr_market) * 1.3)
  ) +
  labs(
    title    = sprintf("%s — SCR by Top-Level Module", syndicate_name),
    subtitle = "Post Step-1 aggregation | Consistent with Standard Formula two-step structure",
    x        = "Top-Level Module",
    y        = "SCR (£m)",
    caption  = paste0("Total SCR (£", round(scr_total, 1),
                      "m) reflects diversification across all three modules")
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title         = element_text(face = "bold", size = 14),
    plot.subtitle      = element_text(colour = "grey"),
    legend.position    = "none",
    panel.grid.major.x = element_blank()
  )

print(p1b)

ggsave("charts/01b_top_level_modules.png", plot = p1b,
       width = 10, height = 6, dpi = 150)

# --- 8b. Solvency Position (Own Funds vs SCR) ---

solvency_df <- data.frame(
  Category = factor(c("SCR", "Capital Surplus"),
                    levels = c("SCR", "Capital Surplus")),
  Amount   = c(scr_total, capital_surplus)
)

p2 <- ggplot(solvency_df, aes(x = "Own Funds", y = Amount, fill = Category)) +
  geom_bar(stat = "identity", width = 0.4) +
  geom_hline(yintercept = scr_total, linetype = "dashed",
             colour = "red", linewidth = 1) +
  annotate("text", x = 1.3, y = scr_total,
           label = sprintf("SCR: £%.1fm", scr_total),
           colour = "red", size = 4, fontface = "bold") +
  annotate("text", x = 1, y = scr_total / 2,
           label = sprintf("£%.1fm\n(%.0f%%)", scr_total, 100),
           colour = "white", size = 4.5, fontface = "bold") +
  annotate("text", x = 1, y = scr_total + capital_surplus / 2,
           label = sprintf("£%.1fm surplus", capital_surplus),
           colour = "white", size = 4, fontface = "bold") +
  scale_fill_manual(values = c("SCR" = "blue",
                               "Capital Surplus" = "green")) +
  scale_y_continuous(labels = label_comma(prefix = "£", suffix = "m")) +
  labs(
    title    = sprintf("%s — Solvency Position", syndicate_name),
    subtitle = sprintf("Eligible Own Funds vs SCR | Solvency Ratio: %.0f%%",
                       solvency_ratio),
    x        = NULL,
    y        = "Amount (£m)",
    fill     = NULL,
    caption  = "Red dashed line = SCR threshold (minimum capital requirement)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(colour = "grey"),
    legend.position = "bottom"
  )

print(p2)

ggsave("charts/02_solvency_position.png", plot = p2,
       width = 8, height = 7, dpi = 150)

# --- 8c. Diversification Benefit Illustration ---

div_df <- data.frame(
  Scenario = factor(c("Simple Sum\n(No Diversification)", "Total SCR\n(With Correlation)"),
                    levels = c("Simple Sum\n(No Diversification)", "Total SCR\n(With Correlation)")),
  Amount   = c(scr_sum_no_div, scr_total)
)

p3 <- ggplot(div_df, aes(x = Scenario, y = Amount, fill = Scenario)) +
  geom_bar(stat = "identity", width = 0.5) +
  geom_text(aes(label = sprintf("£%.1fm", Amount)),
            vjust = -0.5, size = 4.5, fontface = "bold") +
  annotate("segment",
           x = 1, xend = 2,
           y = scr_sum_no_div * 1.05, yend = scr_sum_no_div * 1.05,
           arrow = arrow(ends = "both", length = unit(0.2, "cm")),
           colour = "grey") +
  annotate("text", x = 1.5, y = scr_sum_no_div * 1.09,
           label = sprintf("Diversification benefit: £%.1fm (%.0f%%)",
                           div_benefit, div_benefit_pct),
           size = 3.8, colour = "grey") +
  scale_fill_manual(values = c(
    "Simple Sum\n(No Diversification)" = "orange",
    "Total SCR\n(With Correlation)"    = "blue"
  )) +
  scale_y_continuous(labels = label_comma(prefix = "£", suffix = "m"),
                     limits = c(0, scr_sum_no_div * 1.25)) +
  labs(
    title    = sprintf("%s — Diversification Benefit", syndicate_name),
    subtitle = "Impact of inter-module correlation on total SCR",
    x        = NULL,
    y        = "SCR (£m)",
    caption  = "Diversification benefit = reduction in SCR from correlation vs simple summation"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title      = element_text(face = "bold", size = 14),
    plot.subtitle   = element_text(colour = "grey"),
    legend.position = "none",
    panel.grid.major.x = element_blank()
  )

print(p3)

ggsave("charts/03_diversification_benefit.png", plot = p3,
       width = 10, height = 6, dpi = 150)

cat("=================================================================\n")
cat("END OF SCRIPT\n")
cat("=================================================================\n")
