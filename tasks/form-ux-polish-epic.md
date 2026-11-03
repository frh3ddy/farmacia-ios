# Epic: form UX polish (pilots: Nuevo Producto, Recibir Inventario)

**Branch:** `feature/form-ux-polish`

## Decisions

- Optional fields go under a collapsible **Más detalles** (progressive disclosure). Essentials stay visible.
  While closed but holding something, the row says "Con datos" (`MoreDetailsLabel`).
- Pilots now; the other forms (Gastos, Ajuste, Editar Precio, Agregar Empleado, Ajustar turno) move
  to the shared form kit when a later task touches them.
- Initial stock has no switch: most new products arrive with stock, so the fields are always shown and a
  quantity is what creates it (Shopify's product form pattern).
- SKU sits with the essentials, "Automático" when empty, so a missing SKU is visible at a glance.

## Patterns followed

- Grouped rows with the label on the left and the value on the right (iOS Settings/Contacts style), single column.
- Every field has a visible label; placeholders only give examples or say what an empty value means.
- Essentials first (Square's create-item order: name, SKU, price); no "(Opcional)" on every header.
- Spanish everywhere.

## Logic (FarmaciaKit, TDD)

1. [x] `ProductDraft.hasDetails` (description, stores, Square; not the SKU).
2. [x] `ReceivingDraft.hasDetails` (price update, invoice, batch, notes; not the expiry).
3. [x] `ProductDraft.canSave` / `createsInitialStock`: name and price; a quantity creates stock and then needs
   its cost (0 is fine); a cost without a quantity blocks saving instead of being dropped.

## UI

4. [x] Nuevo Producto: photo → Nombre, SKU, Precio → Inventario inicial (Cantidad, Costo, Proveedor) → Margen →
   Más detalles (Descripción, Sucursales, Square). Spanish copy.
5. [x] Recibir Inventario: product summary (photo, name, SKU, stock, price) → Cantidad, Costo, Costo total →
   Proveedor → Vencimiento (kept visible: expiry matters for a pharmacy) → Más detalles (Actualizar precio,
   Factura, Lote, Notas).
6. [ ] Device smoke: both forms (user). Then README + this epic; `graphify update .`.

## Ideas (documented, not built)

### A. Scan button in the SKU row — on hold

A barcode button at the trailing edge of the SKU row that opens the scanner and fills the SKU, without leaving
the form. Small and cheap (reuses `BarcodeScannerSheet` / CodeScanner). On hold because idea B can fill the
SKU from the product photo the user already takes, which makes a separate scan step mostly redundant.

### B. Fill the form from the product photo — preferred next feature

The user already photographs the product (camera → crop → background removal). Read that same photo and
**suggest** name, presentation and SKU, instead of typing them:

- **Barcode → SKU.** Vision `VNDetectBarcodesRequest` on the photo (EAN-13/UPC are on almost every box).
  Fills SKU when it's empty. Highest value, most reliable.
- **Text → name and presentation.** Vision `VNRecognizeTextRequest` (on device, Spanish + English) returns
  the printed lines with their size and position. A pure rule in FarmaciaKit (TDD) turns them into suggestions:
  - name: the largest/most prominent line(s), e.g. "ASPIRINA EFERVESCENTE";
  - strength: patterns like `500 mg`, `5 ml`, `0.1 %`;
  - content: patterns like `20 tabletas`, `caja con 10`, `120 ml`;
  - suggested product name = name + strength + content ("Aspirina efervescente 500 mg 20 tabletas").
- **Optional, newer devices:** on iOS 26 devices with Apple Intelligence, the on-device Foundation Models
  framework can structure the recognized text more reliably (guided generation into a `ProductSuggestion`).
  The shop's iPhone 13 Pro doesn't support Apple Intelligence, so the Vision + rules path must stand alone.
- **UX:** never overwrite what the user typed. After the photo step, show the suggestions in a small card
  ("Sugerencias de la foto: Nombre · SKU · Presentación") with Usar / Ignorar per field, or fill only empty
  fields with a subtle "de la foto" tag the user can clear. Runs on device: no network, no cost, works offline.
- **Split:** Vision calls in the app (UIKit image in, recognized lines/barcodes out); the parsing of lines into
  name/strength/content and the "only fill empty fields" rule in FarmaciaKit, test-first
  (first test: given the lines of an aspirin box, should suggest "Aspirina efervescente 500 mg").
- **Risks:** curved or glossy packaging, small print, brand vs. product name ambiguity — hence suggestions,
  never automatic overwrites; measure with real photos from the shop before tuning the rules.
