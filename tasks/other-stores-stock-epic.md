# Other Stores' Stock Epic

**Status**: ✅ DONE
**Goal**: show every store's stock on the product detail and on receiving, without switching stores

## Overview

When a product is at 0 here, staff need to know whether another store has it so they can ask for a transfer, and when receiving they need the other stores' counts to split the delivery. The api (farmacia-ops `tasks/other-stores-stock-epic.md`) adds `GET /products/:id/stock`, which returns quantities only, for every role. The phone fetches it when a product or receiving line is opened and keeps it out of the delta-synced product list.

API contract (farmacia-ops main, 3f66dbc; in production once Railway deploys): `{ success, data: [{ locationId, locationName, quantity: Int }] }`, open stores sorted by name, current store included (filter or highlight it), 404 "Producto no encontrado" for an unknown id. Don't send `locationId`. Products that don't track stock (Yastás) return `data: []`: an empty list hides the section.

---

## Stock by Store on Product Detail

`ProductDetailView` lists the other stores' quantities under this store's stock. ✅ "En otras tiendas" card under the header (FarmaciaKit `StoreStock.others` / `standsOut`, tested); hidden when empty.

**Requirements**:
- Given a product at 0 here and in stock elsewhere, should make the stores that have it stand out
- Given no network, should hide the section instead of showing an error or stale numbers
- Given a cashier, should show the quantities (they hold no cost)

---

## Stock by Store on Receiving

The receiving form shows each store's quantity for the product being received. ✅ Footnote under Cantidad, "Aquí 7 · Centro 0 · Sur 0" (`StoreStock.summary`, tested); a failed fetch just hides it.

**Requirements**:
- Given a product picked on the receiving form, should show every store's quantity next to the quantity field
- Given the other-store fetch fails, should still let the receiving be saved

---
