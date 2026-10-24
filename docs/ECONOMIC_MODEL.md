# Phase 1 economic model

This fictional, closed city is an educational mechanism model. It is not calibrated, empirically validated, or a forecast. One household is one citizen. A technology or owner archetype describes income/behavior; businesses are separate entities and owner households do not own firm equity in this phase.

## Units and accounting authority

Every amount is `Int64` cents. Confidence, stress, behavioral factors, and rates use integer basis points (10,000 = 100%). The ledger alone owns spendable balances. Household/business/treasury balance properties and bank records are derived caches refreshed after each tick. No entity can overdraft.

Opening household deposits, firm deposits, bank lending funds, and treasury funds are explicit day-zero external endowments in `OpeningAllocation`. Opening loans are real settled transfers from bank funding accounts after all allocations exist. No subsequent implicit money creation or external sink exists in Phase 1. Transfers conserve total spendable money. Rejected transfers do not alter balances or create entries.

Each settled transfer has a monotonically assigned ID, day, sender account, recipient account, positive amount, and economic kind. It creates two signed `LedgerEntry` postings (-amount, +amount). Rejected transfers are stored separately with their reason and attempted amount. `reconcile()` reconstructs every account from opening allocations and entries, checks postings against transaction records, checks unique transaction IDs and zero entry sum, and compares opening/current money and nonnegative balances.

## Simplified commercial bank balance sheet

This is deliberately **funded lending with fully backed custody deposits**, rather than fractional-reserve commercial-bank money creation:

- Deposit liabilities D = the bank's household and business deposit accounts.
- Unencumbered bank funding F = the bank's own spendable lending account.
- Reserve assets R = D + F. Deposits are held in custody and fully reserve backed.
- Performing loan claims L = outstanding nondefaulted principal.
- Book equity E = F + L.
- Therefore **R + L = D + E**.

A cross-bank customer transfer moves deposit liabilities and the corresponding derived custodial reserve position together. Within-bank transfers leave aggregate reserves unchanged. Treasury has its own settlement account outside commercial banks.

A funded loan of P moves P from F to the borrower's deposit account: F falls, D rises, R is unchanged, L rises, and E is unchanged. Principal repayment reverses this transfer and reduces L. Interest transfers deposits to F and increases equity. Loan default removes the performing claim from L and E; it does not erase customer deposits or destroy money. Borrower debt is retained as a defaulted obligation; collections/recovery are not modeled. Failed firms retain residual funds in an estate account and may service existing debt.

The Economy screen does not add reserve assets to deposits when measuring money. Total conserved spendable money is household/firm deposits + household cash + bank unencumbered funding + treasury funds. This is a monetary pool, **not aggregate economic wealth**. Physical capital, housing, firm equity ownership, central-bank liabilities, and interbank markets are omitted. Cash accounts are initialized to zero and reserved for future cash withdrawal behavior; Phase 1 household transactions use deposit accounts.

Reserve/deposit coverage is a descriptive custody ratio, not a regulatory capital measure. Bank funding stress combines depleted lending funds and defaulted credit exposure. Stressed banks stop new lending. `intervened` means lending is restricted by the model; no unfunded bailout is invented. The central bank sets the policy rate; its emergency-funding field stays zero in Phase 1. There is no commercial-bank failure/deposit haircut mechanism yet.

## Households and districts

Twelve archetypes cover students, service/technology/industrial/gig workers, business owners, retirees, executives, educators, harbor/retail workers, and graduate researchers. Students/researchers and retirees are outside the labor force. All other households initially have valid employers. Initial assignment favors the household's industry; districts have distinct dominant industries, income multipliers, consumption factors, and business concentration weights. Each household has seeded income/budget variation, bank, employer, district, name, and daily demand variation.

Archetype confidence tends toward a target driven by group stress and the policy rate. Individual confidence adjusts toward that tendency with personal variation and own financial stress. Essential purchases are capped by deposits. Discretionary purchases depend on confidence, policy rates, district demand, and funds remaining above a savings/repayment buffer. Households buy from an active local firm, falling back to another active firm if needed. Shortfalls increase stress. Scores remain in 0...10,000. Decision history records the last 30 days.

## Firms, government, and jobs

Consumption is firm revenue. Firms pay a daily domestic municipal premises/services fee to the treasury, recorded as operating expense. There is no hidden import sink or unrecorded inventory source in accounting; physical production, inventory and price formation are omitted. Revenue, expenses, and profit/loss fields describe the current day, while the account balance carries cash across days.

Payroll is due every 30 days. Active firms may request a bounded funded bridge loan for shortfalls, then pay employees in stable roster order. Insufficient payroll is rejected and the affected employee is dismissed. Successful payroll incurs a 10% household income tax to treasury. Retirees/students receive archetype income as treasury benefits monthly; unemployed workers receive 35% of their reference wage. Treasury transfers fail if funds are unavailable. This closed system deliberately exposes fiscal funding pressure.

Firms accumulate stress when liquidity is below roughly one-third of monthly payroll. Persistent stress causes layoffs every seven days; a severely stressed firm with less than 10,000 cents closes after at least 21 stress days. Unemployed citizens make seeded weekly job searches. Healthy firms with sufficient payroll runway can rehire. Firm credit exposure and payroll obligations are recalculated from real loans and employees.

## Credit and shocks

Loans are at most 2,000,000 cents with at most two outstanding loans per borrower, subject to actual bank funds and bank status. Principal amortizes in twelve installments every 30 days with a final maturity catch-up. Interest is rounded down to cents on current principal using (policy rate + 250 basis-point spread) × 30/365. A payment settles principal and interest only when both are affordable. An unaffordable combined attempted obligation is recorded as a rejected `principal` transaction; no partial settlement occurs. Missed interest is not capitalized or accumulated as arrears. Three consecutive missed installments default the claim; a successful payment clears the missed count. No penalties or compound interest are introduced.

Liquidity-poor employed households may seek a small weekly bridge loan. Firms may borrow before payroll. Bank stress updates after each day's transitions and affects the next day's lending, while funding limits always apply immediately.

Scheduled events can change confidence or the policy rate, close a firm, or grant existing treasury funds to a household. Events apply once in configuration order on their scheduled day. Missing event targets are safely ignored/journaled. Changes alter actual spending, repayments, balance sheets, and employment. The mobile Crisis Lab exposes these four interventions in World B. World A remains an independent baseline. Wider contagion scenarios remain later work.

## Metrics

Employment and unemployment use the employed+unemployed labor force, excluding students and retirees. Transaction volume is the sum of all settled amounts for the displayed day (including financial flows); consumer spending sums essential and discretionary transfers only. Household debt includes defaulted obligations. District activity assigns consumption to the recipient firm's district. Confidence is the population mean. Bank stress is the mean bank funding/credit stress. Simulation financial stress weights household stress 60%, bank stress 20%, and labor-force unemployment 20%. Defaults count households with at least one defaulted loan.

History records day zero and every completed day. Consumer spending is labeled an activity proxy; neither it nor transaction volume is official GDP. No misleading system-wealth measure is published. Empty populations use zero means/percentages. The initial day-zero transaction volume includes funded opening loan advances.

## Crisis extension (Phases 3–5)

The preceding foundation equations remain valid when no crisis or policy is configured. Crisis-specific hooks extend the same economic pipeline; they do not supply precomputed outcomes. See [CRISIS_ENGINE.md](CRISIS_ENGINE.md) for the cash-access formula, shock expiration and policy definitions.

Cash is now active: withdrawals move deposits to household cash; consumption may use both. Fully backed custody deposits cannot become insolvent merely because customers convert them to cash. The bank-run mechanism therefore explicitly limits accessible daily conversion and external payment capacity. Five consecutive days of unmet requests trigger operational settlement resolution. This is a modeled service failure, not a claim that custody assets vanished. Unmet-request totals are cumulative attempts and may include repeat requests; they are not unique losses or destroyed deposits.

Emergency central-bank funding registers an explicit supply entry, advances money to a bank funding account and records a matching public loan. With outstanding central-bank obligation C, **R + L = D + E + C**, and bank equity is F + L − C. The total spendable pool equals day-zero opening allocations plus net issued supply. `Reconciliation.openingMoney` retains its API name but reports that supply-adjusted reference amount. Principal repayment extinguishes issued money; interest transfers to treasury. Treasury relief and business facilities transfer existing funds and cannot overdraft. Fiscal outflow, repayable public credit and household/business losses are distinct quantities.

Variable commercial loan pricing follows policy rates; public facilities retain their contracted rate. Temporary rate shocks restore the prior policy setting when no overlapping rate shock remains. Credit crunches restrict new lending, never delete old debt. Payment outages queue unpaid wages/benefits and retry after recovery; posted sales/revenue count settled transfers only. Financially blocked debt payments do not erase principal.

Financial relationships already encoded by employment, deposits, borrowing and actual purchases transmit cash-flow effects. Direct payment rejections carry transaction/entity IDs. Employment/default observations during crises are labeled observations; graph proximity or timing alone does not prove causation. Public loan repayment and outstanding claims are tracked, but collateral valuation, recovery auctions, interbank markets and official fiscal multipliers are not modeled.

Branch commands enable keyed exogenous draws from the command boundary, using seed/day/citizen/channel, so divergent employment or spending eligibility does not misalign random shocks. A plain Phase 1 configuration retains its original sequential RNG behavior. Replays preserve the keyed boundary in configuration. See [TIME_TRAVEL.md](TIME_TRAVEL.md).

Join the Economy constructs a new initial world, enrolls one additional fictional citizen and uses treasury transfers for its starting preset. It is not a mid-tick injection into an existing ledger. Starting risk/savings preferences are bounded model inputs, not real personal-finance data.
