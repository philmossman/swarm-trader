# AutoResearch: Trading Strategy Evolution

*Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch). You are an autonomous strategy researcher. You modify `strategy.py`, run a backtest, and iterate.*

---

## Current Strategy State (as of 2026-03-26)

**⚠️ This section should be reviewed and updated weekly. After 2026-04-07, the VWAP 10.0 warning below may no longer apply — the rolling 10-day data window will contain entirely different market conditions. Re-test before treating any parameter as permanently bad.**

**Current fitness: 6.046** (fitness=6.046322, win_rate=0.6875, 16 trades, Sharpe 4.48, Sortino 15.92)

**Historical context:** All-time best was **fitness=10.074** (Mar 18, 91.3% win rate, 23 trades) with VWAP multiplier 10.0 on Mar 4–18 data. The current 6.046 reflects different market conditions in the rolling 10-day window — not strategy regression. Parameters that score poorly now may recover as the data window shifts.

**Key changes already kept in strategy.py (relative to Mar 18 baseline):**
- `TARGET_MULTIPLIER = 3.6` (was 3.3 — kept Mar 25, improved fitness from degraded ~4.96 baseline)
- `MACD_SIGNAL_PERIOD = 5` (was 7 — kept Mar 25, fitness 5.86→6.05)
- `dev * 9.0` in VWAP scoring (was 10.0 — kept Mar 24; do NOT revert before 2026-04-07)

**⚠️ DO NOT attempt to revert VWAP multiplier to 10.0 before 2026-04-07:**
This was tried 10+ consecutive times and produced fitness=4.926 every time on current market data. The 10.0 value performed poorly because the rolling 10-day window now covers a different market regime. After 2026-04-07 (when the window fully rotates), it may be worth retrying. Other VWAP multiplier values (e.g. 8.5, 9.5) have NOT been tried — those are valid experiments.

**Unexplored directions (prioritise these):**
- `TARGET_MULTIPLIER` above 3.6 (e.g. 3.8, 4.0)
- `MACD_FAST`/`MACD_SLOW` period tuning (currently 8/21)
- VWAP multiplier alternatives: 8.5 or 9.5 (NOT 10.0 until after 2026-04-07)
- `SWING_TARGET_MULTIPLIER` (currently 2.5, not recently optimised)
- `NO_TRADE_OPEN_MINUTES` (currently 5 — briefly tried 4 with higher baseline, worth retry)
- SPY/QQQ alignment bonus multipliers (currently 1.05)

---

## Known Failure Modes (read before iterating)

**1. Volatile regime + MIN_CONFIDENCE interaction**
The volatile regime multiplier scales raw confidence down before checking MIN_CONFIDENCE. If `volatile_mult * max_raw_confidence < MIN_CONFIDENCE`, no signals pass in volatile markets → < 10 trades penalty (-15 fitness). When changing MIN_CONFIDENCE or REGIME_MULTIPLIER["volatile"], verify: `MIN_CONFIDENCE / volatile_mult ≤ 95.0` (the max achievable confidence). Current values: MIN_CONFIDENCE=58.0, volatile_mult=0.65 → requires raw_conf ≥ 89.2, which is achievable.

**2. < 10 trades penalty is severe (-15 fitness)**
Any parameter change that reduces signal frequency can trigger this cliff. Before widening VWAP_NEAR_BAND_PCT, raising MIN_CONFIDENCE, or increasing NO_TRADE_OPEN_MINUTES, check that the current strategy generates ≥ 10 trades. If you see fitness jumps of ~-15, this is almost certainly the cause.

**3. Confidence weight changes must sum to 1.0**
CONF_WEIGHT_RSI + CONF_WEIGHT_VWAP + CONF_WEIGHT_VOLUME + CONF_WEIGHT_MACD must equal 1.0 exactly. Changing one weight requires adjusting others. Violating this silently biases scores.

**4. Baseline metric ranges (healthy intraday strategy)**
- Sharpe: 1.0–3.0 is good; > 4.0 is suspicious (possible overfit)
- Win rate: 45–65% is typical for these signals
- Trades per 10-day window: 10–50 (< 10 = penalty, > 200 = penalty)
- Max drawdown: < 8% is good, 8–15% is marginal, > 15% = -20 penalty

---

## Your Job

You are evolving a **pure-Python trading strategy** in one of two modes. No LLM calls — just math, indicators, and rules.

The `MODE` variable at the top of `strategy.py` controls which logic path is active:
- `MODE = 'day'`  — intraday 5-min bars, VWAP/RSI/MACD signals, flatten at close
- `MODE = 'swing'` — daily bars, moving average crossovers + RSI trend, overnight holding

The evolution system (`evolve.py`) passes `--mode day|swing` to the backtester, which passes `mode` via `market_context`. Your changes to `strategy.py` should match the current `MODE`.

## Files

| File | Role | Who modifies |
|------|------|-------------|
| `strategy.py` | The strategy — signals, indicators, parameters, MODE. **This is the only file you touch.** | You (the agent) |
| `backtest_fast.py` | Runs strategy.py against historical data, outputs fitness metrics. Fixed. | Nobody |
| `evolve.py` | The loop that orchestrates you. Fixed. | Nobody |
| `program.md` | These instructions. | Human |

## The Loop

1. Read the current `strategy.py` and the experiment log (`experiments/log.jsonl`)
2. Analyze what's been tried, what worked, what didn't
3. Form a hypothesis — one clear change with a reason
4. Modify `strategy.py` (you may change anything in it: parameters, indicator logic, signal rules, entry/exit conditions, position sizing)
5. The system runs `backtest_fast.py` and measures fitness
6. If fitness improves → your change is kept. If not → reverted.
7. Repeat.

## Fitness Metric

### Day Mode Fitness (Sharpe/win-rate focused)

```
fitness = (sharpe_ratio * 0.35) + (sortino_ratio * 0.25) + (total_return_pct * 0.20) + (win_rate * 0.10) + (profit_factor * 0.10)
```

Day mode balances risk-adjusted returns, absolute performance, and consistency. High trade count and win rate matter because there are many intraday opportunities.

**Day penalties:**
- Max drawdown > 15% → -20
- Win rate < 30% → -10
- Fewer than 10 trades → -15 (too little signal)
- More than 200 trades → -5 (overtrading)

### Swing Mode Fitness (return/drawdown focused)

```
fitness = (total_return_pct * 0.35) + (sortino_ratio * 0.25) + (sharpe_ratio * 0.20) + (profit_factor * 0.12) + (win_rate * 0.08)
```

Swing mode prioritizes capturing multi-day trends (total return) and avoiding large drawdowns (overnight gap risk). Fewer trades are expected — 3+ in 30 days is fine.

**Swing penalties:**
- Max drawdown > 20% → -25 (overnight gaps amplify losses)
- Max drawdown 15–20% → -10
- Win rate < 25% → -10
- Fewer than 3 trades → -15
- More than 100 trades → -5

## Strategy Rules (Immutable)

These are hard constraints that always apply regardless of mode:
- Every entry MUST have a stop loss and profit target
- Position size must not exceed 15% of portfolio

**Day mode only:**
- Must respect daily loss limit of 3% (circuit breaker)
- No holding overnight (all positions close by 3:45 PM ET)
- Only trade liquid mega-cap + momentum tickers

**Swing mode only:**
- Positions may be held overnight and across multiple days
- Use SWING_UNIVERSE tickers (includes leveraged ETFs, moonshots)
- No intraday time-of-day filters

## What You Can Change in strategy.py

**Mode selection:**
- Set `MODE = 'day'` or `MODE = 'swing'` to evolve the appropriate logic path

**Day trading parameters (MODE = 'day'):**
- RSI thresholds, VWAP deviation bands, volume multipliers
- Stop loss percentage (`STOP_PCT`), target multiplier (`TARGET_MULTIPLIER`)
- Confidence thresholds (`MIN_CONFIDENCE`), confidence weights (`CONF_WEIGHT_*`)
- Time-of-day filters (`NO_TRADE_OPEN_MINUTES`, `MARKET_CLOSE_CUTOFF`)
- Regime multipliers (`REGIME_MULTIPLIER`)
- MACD periods (`MACD_FAST`, `MACD_SLOW`, `MACD_SIGNAL_PERIOD`)

**Swing trading parameters (MODE = 'swing'):**
- Moving average periods (`SMA_FAST`, `SMA_SLOW`)
- Trend strength threshold (`TREND_STRENGTH_THRESHOLD`)
- Swing RSI thresholds (`SWING_RSI_OVERSOLD`, `SWING_RSI_OVERBOUGHT`)
- Swing stop/target (`SWING_STOP_PCT`, `SWING_TARGET_MULTIPLIER`)
- Swing confidence threshold (`SWING_MIN_CONFIDENCE`)
- Swing confidence weights (`SWING_CONF_WEIGHT_*`)

**Indicator logic (both modes):**
- Add/remove/modify technical indicators
- Change indicator periods (RSI 14 → RSI 9, SMA 50 → SMA 100, etc.)
- Add new derived signals (e.g., ATR-based stops for swing, VWAP slope for day)

**Signal rules (both modes):**
- Entry conditions (what triggers a buy/sell)
- Regime filters (when to trade vs sit out)
- Multi-timeframe confirmation

## How to Think

1. **Start simple, add complexity only when it helps.** The best strategies are often the simplest.
2. **One change at a time.** Compound changes make it impossible to learn what worked.
3. **Read the log.** Don't repeat failed experiments. Build on what worked.
4. **Reason about WHY** a change should help before making it. Random search is wasteful.
5. **Markets have regimes.** A strategy that works in trending markets may fail in chop. Consider adaptivity.
6. **Overfitting is the enemy.** If you're tuning to specific dates in the backtest data, you're not discovering real alpha.

## Output Format

When you modify strategy.py, include a comment block at the top:

```python
# EXPERIMENT: <short name>
# HYPOTHESIS: <why this change should improve fitness>
# CHANGE: <what you modified>
```

This gets logged for future experiments to reference.
