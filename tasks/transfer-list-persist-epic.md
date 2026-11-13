# Transfer List Persist Epic

**Branch**: `feature/transfer-list-persist`
**API**: farmacia-ops `POST /transfers/stock` (49cf384, in production as deploy 87d816b0).

Más → Transferencias: the list stays on the phone until it's sent or cleared.

## Decisions

- **One list per employee and store**, saved in `UserDefaults`. Switching back to a store brings its list back. Logout leaves it saved.
- **The request id is saved with the list**, so a resend after a restart can't ship twice.
- **Stock refreshes when the list loads**, in one call. A note names what changed. On failure (or an older server) the saved numbers stay, with a note that they may be old.
- **Changing a list after a timed-out Enviar warns** that it could arrive twice (it goes as a new shipment).
- **"Vaciar lista"** (destructive, with confirmation) clears the list.

## Steps

1. ✅ `TransferDraft` and `Line` are `Codable`.
2. ✅ `TransferDraftStore`: a key per employee and store (nil without either, since logout clears the store first), load and save (an empty list removes the saved one; unreadable data loads empty).
3. ✅ `refreshAvailable(_:)` and `TransferStockChange.notice(_:)` (three changes, then "y N más"). `stockRequest(locationId:)` asks for at most 100 ids.
4. ✅ `markMayHaveSent()` and `sendWarning`: only after an edit (an unedited resend replays safely). Not cleared by a renewed id; cleared by `reset()`.
5. ✅ `sendIssue(refreshingStock:)`: Enviar waits for the refresh.
6. ✅ `TransfersView`: save on change, load on open and store switch (not on a nil store), refresh with a store-switch guard, notices, the warning (also in the Enviar confirmation), Vaciar.
7. ✅ Simulator (local API): the list survives a relaunch; the old local server answered 404, so the "No se pudieron actualizar" note showed; Vaciar cleared it.

## /tdd-review fixes

1. ✅ A send that finishes after a store switch updates the list it sent (`TransferDraftStore.update`), not the store now on screen.
2. ✅ Saved data without the may-have-sent fields still loads (`decodeIfPresent`), so a later field doesn't lose saved lists.
3. ✅ Coming back to the screen (e.g. a tab switch) doesn't reload: `.task(id: draftKey)` and a loaded-key guard. Checked in the simulator: no new note after Inicio → Más.
4. ✅ Unreadable saved data: `load` throws, the list starts empty with "No se pudo recuperar la lista guardada.", and the bad data is removed. Unit-tested only: editing the simulator's plist on disk didn't reach the app (cfprefsd kept its copy).
5. ✅ `TransferStockRequest` JSON keys pinned (a characterization test: it passed at once).

## Still to check on a phone

- The "Cambiaron las existencias" note, against an API with the endpoint.
- Switching stores and back restores each store's list.
- The timeout warning (a timeout can't be forced locally).
