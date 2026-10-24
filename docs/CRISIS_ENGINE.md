# Crisis engine and financial accounting

`CrisisEngine` is a set of transitions inside the existing `EconomicKernel` daily pipeline, not another simulation clock. `CrisisPlan` and `PolicyPlan` are Codable typed events in the existing configuration journal. Numerical bounds, entity references, event uniqueness and future application days are validated before scheduling.

## Bank run

The original economy holds fully backed custody deposits. A deposit run cannot honestly create balance-sheet insolvency simply by transferring those deposits. The extension therefore models an **accessible daily cash-conversion and interbank settlement window**:

`capacity = unencumbered bank funding + deposit liabilities × (10000 − severity) / 100000`

Each depositor requests `deposit balance × effective severity / 20000` per crisis day. A time-limited guarantee reduces effective request severity to one quarter. Requests settle only if the account is affordable and the accessible window has capacity. A settled withdrawal transfers household deposits to that household's real cash account. It does not destroy money. Cash can fund essential/discretionary purchases; merchants receive corresponding deposits. Cash can be redeposited for scheduled loan servicing.

Unfilled requests are rejected attempts with actual IDs, amounts and days, not successful transactions or an invented loss. Five consecutive days of unmet withdrawal obligations cause **settlement resolution/suspension**, recorded in crisis state. This is an operational condition, not a claim of regulatory insolvency. During the active run, further settlement remains limited to available unencumbered funds. Crisis expiration restores normal settlement rules; financial consequences already incurred remain.

Outbound cross-bank deposit transfers consume the window. Same-bank transfers remain possible. Actual reduced sales, payment delays, credit restrictions, financial stress and payroll effects propagate through the existing consumption, credit and employment mechanisms. No account is forced negative.

## Other crises

- **Interest rate shock:** changes the variable commercial-loan policy component, spending incentives and resulting cash flows. The shock restores the prior base rate at expiration; subsequent explicit rate policies update that base. Public facility loans keep their contracted fixed rate.
- **Mass layoffs:** deterministically selects currently employed citizens in the requested district/industry, removes employer roster entries and payroll obligations, and records actual employment changes.
- **Recession:** lowers confidence during its duration and restricts rehiring. Original bounded consumption, revenue, delinquency and firm-health rules calculate consequences.
- **Credit crunch:** blocks new commercial-loan originations in scope. Existing loan claims remain.
- **Payment outage:** blocks scoped deposit accounts. Payroll and benefits create explicit queued obligations; affected loan payments retry without incorrectly extinguishing principal. Recovery reattempts queued payments, with real settlement entries, expenses, taxes and benefits posted only on success. Insufficient funding can leave obligations outstanding after the network recovers.

## Public interventions

**Emergency liquidity:** a zero-balance central-bank settlement account is registered. A `MoneySupplyChange` explicitly records issuance; a settled transfer moves reserves into bank funding. A `PublicLoan` records the bank's obligation and central bank's claim. Principal repayments transfer back to the central-bank account and explicitly extinguish issued money; interest is remitted to the treasury.

For each bank, with F unencumbered funding, D custody deposits, L performing commercial loans and C central-bank debt:

`R = D + F`, `E = F + L − C`, and **`R + L = D + E + C`**.

This extension does not mislabel custody coverage as regulatory capital. Central-bank support increases liquidity and debt; it is not automatically money saved or a fiscal loss avoided.

**Deposit guarantee:** a timed confidence assurance lowers modeled run demand, with no automatic monetary transfer or uncosted real-world insurance claim.

**Policy rate:** an explicit policy change affects eligible variable-rate commercial loan servicing and consumption.

**Household relief:** bounded transfers from existing treasury funds to eligible low-liquidity/unemployed households. Unspent budget is not recorded as expenditure.

**Business credit:** treasury-funded repayable loans to eligible firms with insufficient payroll liquidity. Claims, repayments, interest, arrears and business exposure are recorded. Displayed fiscal outflow is gross funded outflow, not net fiscal loss.

The ledger reconciles every account from opening allocations, explicit net money-supply changes and two-sided transfer entries. Thus current spendable money equals opening endowments plus issuance minus extinguishment. Rejected and queued requests never contribute successful transaction volume.

## Evidence and limits

Direct disruption records identify the crisis, account owner, day, attempted amount and related transaction. Employment/default events observed during a crisis are explicitly labeled as observations; timing alone does not establish counterfactual causation. Crisis records retain the latest 600 entries; the complete financial ledger remains auditable.

The model omits reserve-asset pricing, liquidation losses, deposit haircuts, regulatory capital rules, collateral auctions and interbank credit markets. Settlement resolution must not be marketed as a validated real bank-failure forecast. Policy outcomes depend on initial conditions; only controlled fixtures assert particular improvements.
