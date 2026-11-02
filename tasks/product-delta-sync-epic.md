# Product Delta Sync Epic

**Status**: ✅ DONE — `ee381cb`. Release build installed on device 2026-11-02; device check pending.
**Branch**: `feature/product-delta-sync`
**Goal**: Switching to Productos no longer walks the whole catalog. The on-device cache that the barcode scanner uses is brought up to date with only what changed.

## Why

Every time the Productos tab opened, the app walked the whole catalog 50 products at a time (about N ÷ 50 requests) to refresh the cache. Each reload cancelled the walk that was running, so with frequent tab switches it rarely finished. The cleanup of deleted products only ran on a finished walk, and the "Sincronizando catálogo" banner kept coming back.

## API contract (farmacia-ops `main` `3c91391`, migration `20261102120000_product_change_stamp`)

- `GET /products/sync?locationId=&cursor=`, all roles. The response is `{ data: Product[], removedIds, cursor, hasMore }`; `data` rows have the same shape as `GET /products` rows, and cashiers get no costs.
- Postgres triggers stamp each product with the transaction that last changed it: the product, its stock batches (including sales made with raw SQL), its prices, its category and its stores. Deletions leave a removal mark.
- The cursor is opaque: the app stores it and never parses it. The server handles late commits and sends some rows twice by design. A malformed cursor gets a 400.
- Pages are 200 rows and walk in stamp order (a keyset).

## Steps

1. ✅ **FarmaciaKit `ProductSync.run`** walks pages from the stored cursor, or from none for a full walk.
   - Tests: "given no stored cursor and two pages, should walk both…"; "given a stored cursor, should start from it…".
2. ✅ **Merge across pages: the last appearance wins.** A product changed then removed, removed then re-added, or sent twice ends in the state of the last page it's on.
3. ✅ **Rejected cursor:** a 400 on a stored cursor drops it and does a full walk. Any other failure throws, so nothing is saved and the stored cursor stays.
4. ✅ **Prune, `ProductSyncResult.idsToDelete(cached:)`:**
   - A delta deletes the removed ids.
   - A full walk deletes every cached id it didn't return, since products deleted before removal marks existed have none.
5. ✅ **App:**
   - New `.productDeltaSync` endpoint and `ProductSyncResponse`.
   - `ProductCacheManager.applySync` writes the rows, the deletions and the cursor in one save. It drops the result if the cache now belongs to another store.
   - `ProductsViewModel.syncCache` replaces the warm-up walk. A reload doesn't restart a running sync; a store switch does. The banner shows only on a full walk.
   - Removed `CacheSweep`, `sweep` and `markFresh`.

## Decisions

- **One cursor per store, not per role.** The ops note asked for one per store and role, because a cashier's rows have no costs. But the phone's cache never stores cost (`CachedProduct` has no cost field), so every role caches the same rows. The cursor lives in `SyncMetadata` next to the store scope and is cleared with the cache on a store switch (`prepare(for:)`).
- **Pull-to-refresh is a delta too.** A full walk happens only on the first sync at a store or after a rejected cursor.
- **The list's page 1 and the counts still come from `GET /products`.** They carry the server's sort and filters and the owner's costs, so a tab switch is now page 1 plus counts plus one small sync request, instead of page 1 plus counts plus N ÷ 50 pages.

## Open

- [ ] Device check on the production build (or a simulator smoke against the local API on ops `main`), checking each of these:
  - The first open does a full walk and shows the banner.
  - A tab switch makes one sync request and shows no banner.
  - A sale or adjustment shows up after the next switch.
  - The barcode scanner finds a product from the cache.
- [x] Cashier counts bug (fixed in `ae59fef`; `ProductCountsResponse` moved to FarmaciaKit, `ProductCountsTests`), found during this work: for a cashier, `GET /products/counts` leaves out `lowMargin`, but `ProductCountsResponse` requires it. Decoding fails, and the counts fall back to the 50 loaded rows ("50 sincronizados"). Fix: make `lowMargin` optional, with a decoding test in FarmaciaKit.
- [ ] The stats row compares two different queries. "N productos" is the list's total, which includes discontinued products and items that don't track stock. "sincronizados" comes from the counts, which leave those out. That's why the owner sees 3,356 vs 3,351. Take both numbers from the same query.
