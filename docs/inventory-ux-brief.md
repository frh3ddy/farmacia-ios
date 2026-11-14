# Claude Code brief: Inventory, POS, costing, and data-entry UX

## 1. Objective

Review the existing project and use the research below to improve or design an inventory and POS experience, with particular emphasis on **fast, accurate data entry**.

The product areas of interest are:

- Inventory and stock movements
- POS checkout
- Receiving and purchase orders
- Lots, batches, and expiration dates
- FIFO and other inventory costing methods
- COGS and profitability reporting
- Inventory adjustments and reconciliation

## 2. Instructions before changing code

1. Inspect the existing codebase, framework, design system, routes, domain models, and tests.
2. Identify what already exists and reuse established components, patterns, and conventions.
3. Present a short implementation plan and note any product or accounting assumptions.
4. Prioritize the requested screens and workflows; do not implement an entire ERP unless explicitly asked.
5. If the application already calculates inventory or money, preserve existing behavior unless a change is explicitly approved and covered by tests.
6. If backend functionality is missing, distinguish **working functionality** from **mock UI**. Do not imply that a simulated transaction has posted or that a financial calculation is authoritative.
7. Check licenses before reusing assets or code from external templates.

---

## 3. Research summary

### Main finding

Portfolio sites provide many visual references for inventory dashboards, POS screens, warehouse interfaces, and generic forms. However, the research found far fewer directly inspectable examples for **FIFO costing selectors, cost layers, landed-cost allocation, or COGS drill-downs**.

The most useful detailed workflow reference is Qoblex’s lot-tracking example, while warehouse-receiving case studies and enterprise software documentation provide stronger operational context than generic dashboard shots. Katana’s valuation article discusses FIFO and LIFO but states that its software uses moving average cost; it **does not demonstrate a FIFO/LIFO selector**. [Qoblex](https://qoblex.com/lot-tracking/) · [Katana](https://katanamrp.com/inventory-valuation-methods/)

**Evidence limitation:** Several Dribbble and Figma pages could not be retrieved by the research crawler. Treat those links as visual references to inspect, not as proof that they contain any particular screen or interaction.

---

## 4. Visual references

### Inventory and warehouse

| Reference | Use it to investigate |
|---|---|
| [Dribbble: inventory management](https://dribbble.com/tags/inventory-management) | General inventory visual language, tables, navigation, product cards |
| [Dribbble: inventory forms](https://dribbble.com/search/inventory-form) | Add/edit product and data-entry layouts |
| [Dribbble: stock adjustments](https://dribbble.com/search/stock-adjustment) | Adjustment and quantity-editing inspiration |
| [Dribbble: cycle count](https://dribbble.com/search/cycle-count) | Counting and variance-review concepts |
| [Dribbble: warehouse dashboard](https://dribbble.com/search/warehouse-dashboard) | Warehouse overview and operational status |
| [Dribbble: barcode scanner](https://dribbble.com/tags/barcode-scanner) | Mobile scanning interactions |
| [Behance: inventory-management UX](https://www.behance.net/search/projects/inventory%20management%20software%20ux?locale=en_US) | Case studies and longer design narratives |
| [Figma: inventory management system](https://www.figma.com/community/file/1127492454021442790/inventory-management-system) | Potential editable inventory design reference |
| [Figma: inventory-management UI kit](https://www.figma.com/community/file/1600906592952390163/inventory-management-ui-kit) | Potential reusable component and screen inspiration |

### POS and finance

| Reference | Use it to investigate |
|---|---|
| [Dribbble: POS systems](https://dribbble.com/tags/pos-system) | Checkout layouts and touch-oriented POS screens |
| [Figma: DreamsPOS](https://www.figma.com/community/file/1539254003639832214/dreamspos-pos-inventory-management-admin-dashboard-react-vue-angular-laravel) | Combined POS and inventory dashboard inspiration |
| [Figma: POS System Web UI](https://www.figma.com/community/file/1378764578696265467/pos-system-web-ui) | POS screen and checkout inspiration |
| [Rossul: retail POS case study](https://www.rossul.com/portfolio/retail-pos-system-ux/) | Tablet POS combining checkout, inventory, and domain-specific checks |
| [Dribbble: cost breakdown](https://dribbble.com/search/cost-breakdown) | Cost detail and breakdown visual patterns |
| [Dribbble: cost allocation](https://dribbble.com/search/cost-allocation) | Generic allocation patterns—not necessarily landed-cost screens |
| [Eleken: financial dashboards](https://www.eleken.co/blog-posts/financial-dashboard-examples) | P&L, trends, variances, and finance dashboard hierarchy |

---

## 5. UX principles to apply

### A. Optimize for the transaction, not the dashboard

Prioritize the workflows users repeat throughout the day:

1. Find or scan an item.
2. Enter or verify quantities.
3. Understand what will change.
4. Resolve exceptions.
5. Save a draft or post the transaction.
6. See a clear confirmation and resulting status.

A visually attractive dashboard is useful, but it must not slow down receiving, checkout, stock counts, or corrections.

### B. Design data entry for speed and error recovery

- Use persistent, descriptive field labels—not placeholder-only labels.
- Group related fields and follow the user’s natural workflow.
- Use sensible defaults, autocomplete, and scanner input where appropriate.
- Show units beside quantities and currencies beside monetary values.
- Calculate straightforward values instead of making users do mental math.
- Explain errors next to the affected field and tell users how to fix them.
- Support keyboard navigation and preserve entered values after validation errors.
- Use progressive disclosure for infrequent advanced fields.
- Make **Save draft** distinct from **Post**, **Complete sale**, or other consequential actions.

For general forms, a single-column layout is a strong starting point; transaction line-item grids can be a justified exception when users need to compare and edit multiple rows. [Nielsen Norman Group](https://www.nngroup.com/articles/web-form-design/) · [CXL](https://cxl.com/blog/form-design-best-practices/)

### C. Treat tables as working surfaces

For inventory and transaction tables:

- Use a recognizable product name or SKU as the primary identifier.
- Keep related columns next to each other.
- Support search, useful filters, sorting, and visible active filters.
- Freeze headers and, where needed, identifying columns in wide tables.
- Right-align numeric values and use consistent decimal formatting.
- Provide clear selection and bulk actions when appropriate.
- Use inline editing for simple, low-risk changes; use a detail panel or review step for more consequential edits.
- Preserve context when opening a record.

These patterns address common table tasks: finding, comparing, editing, and acting on records. [Nielsen Norman Group](https://www.nngroup.com/articles/data-tables/) · [Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)

### D. Make the financial consequences visible

Before posting any transaction that changes inventory or financial values, show a concise review:

- What items and quantities change
- Which location is affected
- Applicable cost or allocation information
- Any unresolved validation issues
- Whether the operation is a draft, pending, or posted transaction

Do not make sensitive financial changes look like ordinary cosmetic edits.

---

## 6. Recommended workflows and screen concepts

> The following are **proposed patterns based on the research**, not claims that an existing product implements them exactly.

### 6.1 Product creation and editing

**Primary fields**

- Product name
- SKU and barcode
- Category
- Unit of measure
- Selling price
- Stock tracking on/off
- Default supplier or location, if supported

**Advanced or conditional fields**

- Costing configuration, if controlled at item level
- Lot or serial tracking
- Expiration tracking
- Reorder thresholds
- Tax treatment

**Suggested interaction**

```text
Product details
────────────────────────────────
Product name      [________________]
SKU               [________________]
Barcode           [________________] [Scan]
Category          [Select category]
Unit of measure   [Select unit]

Pricing
────────────────────────────────
Selling price     [________] USD

Inventory tracking
────────────────────────────────
[✓] Track stock
[ ] Track lots or batches
[ ] Track expiration dates

[Save draft]                  [Save product]
```

Do not imply that the costing method can be configured per product unless the actual application and accounting rules support it.

---

### 6.2 Purchase receiving

**Recommended workflow**

1. Select a purchase order or begin an allowed manual receipt.
2. Show ordered items, expected quantities, and previously received quantities.
3. Scan or select a product.
4. Enter received and rejected quantities.
5. If applicable, record lot number, quantity, and expiration.
6. Validate totals and discrepancies.
7. Save draft or review and post the receipt.

**Helpful data-entry behavior**

- Show quantity conversion when a case or carton contains multiple base units.
- Calculate `number of boxes × units per box` automatically.
- Keep users in context when adding multiple lots.
- Make partial receipts and rejected quantities explicit if supported.
- Prevent accidental duplicate submission.

A warehouse-receiving case study describes scanning packaged products, capturing received and rejected quantities, converting packaging units to base units, and validating the receipt. Another describes reducing mental math through box-count calculations and scan-based labels. [Warehouse receiving case study](https://medium.com/@vish.shah13/ui-ux-designing-a-receiving-operation-at-the-warehouse-b1c3aa0c751b) · [The Art of Warehouse Receiving](https://medium.com/@levibait/the-art-of-warehouse-receiving-c35e96d3c744)

```text
Receive purchase order PO-1042
─────────────────────────────────────────────────────────
Product       Ordered   Received previously   Receive now
Olive oil       200             0              [200]

Lot details
Lot / batch        Quantity        Expiration
[OL-2607____]      [120___]        [________]
[OL-2609____]      [80____]        [________]

200 of 200 received units assigned to lots

[Save draft]                          [Review receipt]
```

**Validation example:** If the item requires lot tracking, show a clear message when the sum of lot quantities does not match the received quantity. Qoblex describes this approach in its receiving workflow. [Qoblex](https://qoblex.com/lot-tracking/)

---

### 6.3 Lot tracking and picking

**Observed reference:** Qoblex presents a lot list with batch, expiration, on-hand, and reserved quantities. Its example receiving flow captures a batch number, quantity, and expiration, while its picking flow offers the nearest-expiring lot first and allows a line to be split across lots. Its trace view links stock movements back to underlying documents. [Qoblex](https://qoblex.com/lot-tracking/)

**Recommended product behavior**

- Show lot, location, expiration, on-hand, reserved, and available quantities.
- Surface expiring or expired status with both text and visual indicators.
- Provide lot-level movement history and links to related receipts and sales.
- If supported, suggest FEFO when picking perishable items.
- Allow authorized overrides with a reason where the business requires them.

**Important distinction:** Physical picking rules such as **FEFO** and accounting valuation methods such as **FIFO** are related but not interchangeable. Do not assume that the physical lot picked always determines the accounting cost layer unless the system’s accounting policy says so.

---

### 6.4 POS checkout

**Suggested flow**

```text
Scan/search product → Review cart → Apply permitted changes
→ Take payment → Confirm result → Issue receipt
```

**Recommended interface**

- Keep product lookup, cart, quantity, price, and total visible.
- Make barcode input fast and keyboard-friendly.
- Support touch targets for tablet workflows.
- Keep discounts, tax, and payment status understandable.
- Show stock warnings where relevant without interrupting every sale unnecessarily.
- Clearly distinguish payment pending, payment failed, and completed sale.
- Confirm what happens if inventory is unavailable, payment fails, or connectivity drops; do not invent an offline guarantee.

The Rossul case study illustrates a tablet-oriented POS bringing checkout, inventory, and regulatory checks into one workflow. Its compliance requirements are specific to its domain and should not be copied as universal POS rules. [Rossul](https://www.rossul.com/portfolio/retail-pos-system-ux/)

---

### 6.5 Stock adjustments and reconciliation

**Suggested workflow**

1. Select product and location.
2. Show current recorded quantity.
3. Enter a counted quantity or an adjustment amount—clearly indicate which.
4. Show the resulting variance.
5. Require a reason where business rules call for it.
6. Review the change and obtain approval if applicable.
7. Post the adjustment and retain an audit trail.

```text
Stock count: Main warehouse
────────────────────────────────────────────────────────────
Product       System qty   Counted qty   Difference
Coffee beans       42          [39]          -3

Reason             [Damaged stock ▼]
Notes              [Optional details______________]

[Save draft]                           [Review adjustment]
```

A reconciliation flow should investigate and document discrepancies before records are updated. The process may need to account for transactions occurring during the count; confirm existing concurrency and posting rules before implementing. [Fishbowl](https://www.fishbowlinventory.com/blog/inventory-reconciliation) · [Nominal](https://nominal.so/blog/inventory-reconciliation/)

---

### 6.6 Costing-method configuration

**Recommended design—not a verified screenshot of another product:**

```text
Inventory costing method
─────────────────────────────────────────────────────
( ) FIFO
    Assign older eligible costs to outgoing inventory first.

( ) Moving weighted average
    Use the applicable moving average cost.

( ) LIFO
    Assign newer eligible costs first where supported
    and permitted by the applicable accounting framework.

[Preview impact]                         [Continue]
```

**Implementation safeguards**

- Determine whether the method is configured by company, location, product, or another scope in the existing system.
- Explain the applicable scope and effective date.
- Do not silently recalculate historical transactions when a setting changes.
- Require an explicit review and appropriate authorization for consequential changes.
- Treat method availability and changes as accounting-policy decisions, not just UI preferences.
- Do not imply that LIFO is valid everywhere: it is not permitted under IFRS. Confirm jurisdiction and policy with the business’s accountant before enabling it. [Investopedia](https://www.investopedia.com/articles/02/060502.asp)

**Example for test fixtures only**

Assume two purchases, then a single sale after both receipts:

- 100 units at $10
- 100 units at $12
- Sell 120 units

| Method | Illustrative COGS | Remaining inventory |
|---|---:|---:|
| FIFO | $1,240 | $960 |
| LIFO | $1,400 | $800 |
| Weighted average | $1,320 | $880 |

The example assumes no additional costs, adjustments, returns, or rounding differences. [Sage](https://www.sage.com/en-us/blog/fifo-vs-lifo/)

---

### 6.7 Landed costs

If “P&L” includes landed costs, confirm scope before implementation.

**Suggested allocation workflow**

1. Select a receipt or eligible inventory transaction.
2. Add cost lines, such as freight or duties, according to business policy.
3. Choose an allocation basis supported by the system: quantity, value, weight, volume, or another approved method.
4. Preview the allocation per item and the resulting unit cost.
5. Validate that the allocated amounts reconcile to the amount being allocated.
6. Review and post using the system’s actual accounting rules.

```text
Additional cost: Freight       $120.00
Allocate by:                  [Quantity ▼]

Item        Units    Allocated cost    Cost per unit
Item A       20          $80.00             $4.00
Item B       10          $40.00             $4.00
───────────────────────────────────────────────────
Total                    $120.00
```

This is a simplified UX example, **not accounting advice**. Finale’s guide discusses allocation bases including quantity, value, weight, volume, and equal distribution. [Finale Inventory](https://www.finaleinventory.com/guides/accounting-and-inventory-software/inventory-costing-methods/)

---

### 6.8 COGS and profitability

**Suggested hierarchy**

1. Period and location filters.
2. Summary: revenue, COGS, gross profit, gross margin.
3. Trend or comparison.
4. Detailed table by product, category, location, or transaction.
5. Drill-down to the supporting transactions or cost components when available.

```text
Period: [This month ▼]  Location: [All ▼]

Revenue          COGS            Gross profit      Gross margin
$20,000          $12,000         $8,000            40%

Product          Revenue         COGS              Gross profit
Coffee beans      $8,000         $5,200            $2,800
Olive oil         $6,000         $3,600            $2,400
```

Definitions for this illustrative example:

```text
Gross profit = revenue − COGS
Gross margin = gross profit ÷ revenue
```

A common simplified periodic inventory formula is:

```text
COGS = opening inventory + purchases − closing inventory
```

Actual production, adjustments, returns, and accounting policies may require additional treatment. Show whether figures are estimates, actuals, or include expected costs. Microsoft’s valuation documentation distinguishes actual and expected costs in its reporting. [Katana](https://katanamrp.com/cost-of-goods-sold/) · [Microsoft Learn](https://learn.microsoft.com/en-us/dynamics365/business-central/design-details-inventory-valuation)

---

## 7. Accessibility and interaction requirements

Use existing project standards, but aim for:

- Full keyboard access and visible focus states.
- Programmatically associated labels and understandable error messages.
- Sufficient color contrast and status labels that do not rely on color alone.
- Touch-friendly controls on warehouse and POS screens.
- Responsive layouts: prioritize essential fields on small screens rather than merely shrinking a desktop table.
- Clear loading, empty, error, success, and permission-denied states.
- Confirmation and recovery paths for consequential operations.

For mobile tables, consider visible identifiers, selective columns, and clear horizontal-scroll cues where a table is still the right component. [Nielsen Norman Group](https://www.nngroup.com/articles/mobile-tables/)

### Detail screens (from the product detail review — `docs/product-detail-findings.md`)

- **Money is ink, green is state.** Amounts are primary-colored, tabular (`MoneyText`); green/amber/red only say
  whether something is fine. Textual green is the accessible `Tone.positive` (light `#0F7B3F`, 5.35:1), never systemGreen.
- **One number, one place, with provenance.** A cost appears once per screen, labelled with where it comes from
  ("Simi · compra 1 nov"). Margin is shown in pesos as well as percent.
- **One formatter per type.** Money `ReportFormat.currency` ("$220.00", currency code stated once per block);
  dates `DisplayDate.day` ("24 sep 2026"); timestamps `DisplayDate.timestamp` ("2 nov · 2:57 a.m.").
- **Names never truncate.** Product names wrap; the card grows.
- **Neutral by default.** A healthy state is neutral, not green; only problems escalate (amber → red). A branch that
  doesn't carry an item shows a neutral `0 uds`.
- **Stock alerts only for regular sellers** (`docs/stock-alerts-design.md`). "Agotado" when a product that sells most
  weeks is at 0; "Bajo" when its stock covers fewer than 14 days at its own sales rate *and* sits under its normal
  level. Slow movers at 0–3 stay quiet. Alertas ranks them by sales lost a day and says why ("Vende ~3 al día",
  "· alcanza para ~4 días"); its counts aren't Productos' chips of the same name, so the list says what it counts.
- **Pausado is not discontinued.** An owner or manager pauses a product per store with a reason (the supplier can't
  restock it, replaced by an equivalent, sells little…); it stops alerting and resumes itself on any receiving or
  received transfer at that store. It shows as "Pausado · <motivo>" with that hint, never as an alert. Pausing is
  never automatic: suggestions (later) only propose it.
- **Empty states are one 44pt row** ("Sin movimientos aún · Historial ›"); tall cards are for content.
- **No meaning by color alone** — every tone carries a glyph and words.
- **No unresolved placeholders, no dead menus.** Hide links that lead to what's already on screen (one supplier).

---

## 8. Acceptance criteria

Adapt these to the actual scope and existing application behavior:

- [ ] Users can complete the selected primary workflow without entering unnecessary fields.
- [ ] Required fields, units, and validation errors are visible and understandable.
- [ ] Draft and posted states are distinguishable.
- [ ] Data survives validation errors and appropriate navigation interruptions.
- [ ] A posted or completed transaction cannot be duplicated by repeated clicks.
- [ ] Lot quantities reconcile with the received quantity when lot tracking is required.
- [ ] Physical picking logic is not conflated with accounting cost-flow logic.
- [ ] Inventory, pricing, and reporting use the application’s real source of truth—or are clearly labeled as mock data.
- [ ] Financial examples and calculations have automated tests where implemented.
- [ ] Keyboard and responsive behavior are tested.
- [ ] Existing functionality and tests remain intact.

## 9. Suggested delivery order

1. **Audit:** Report what already exists, what is missing, and any ambiguity around “L&P.”
2. **Design:** Identify the highest-impact data-entry workflow and show proposed changes.
3. **Implement:** Make the smallest useful set of changes using the existing stack.
4. **Validate:** Run relevant tests and check error, draft, and success states.
5. **Report:** List changed files, implemented behavior, assumptions, and remaining gaps.
