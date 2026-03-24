import re

with open('frontend/public/receipt.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace CSS
css_start_marker = "/* ─────────────────────────────────────────────────────\n           PREMIUM DOCUMENT STYLES\n        ───────────────────────────────────────────────────── */"
css_end_marker = "/* ── FAB Print ── */"
new_css = """/* ─────────────────────────────────────────────────────
           TABULAR DOCUMENT STYLES
        ───────────────────────────────────────────────────── */
        .inv-page {
            width: 100%;
            margin: 0 auto;
            color: var(--text-primary);
        }

        .inv-doc-title {
            text-align: center;
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 20px;
            color: #334155;
        }

        .inv-doc {
            background: #fff;
            border: 1px solid var(--border-strong);
            width: 100%;
            margin-bottom: 24px;
        }

        .inv-header-grid {
            display: grid;
            grid-template-columns: 1fr;
            border-bottom: 1px solid var(--border-strong);
        }

        .inv-shop-info {
            padding: 16px;
            border-bottom: 1px solid var(--border-strong);
        }

        .inv-shop-name {
            font-size: 20px;
            font-weight: 700;
            color: #1e293b;
            text-transform: uppercase;
            margin-bottom: 8px;
        }

        .inv-shop-detail, .inv-gst-number {
            font-size: 13px;
            color: #334155;
        }

        .inv-meta-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
        }

        .inv-bill-to {
            padding: 12px 16px;
            border-right: 1px solid var(--border-strong);
        }

        .inv-invoice-details {
            padding: 12px 16px;
        }

        .inv-col-label {
            font-size: 13px;
            font-weight: 700;
            color: #1e293b;
            margin-bottom: 8px;
        }

        .inv-col-val {
            font-size: 13px;
            color: #334155;
            line-height: 1.5;
        }

        .inv-col-val strong {
            font-weight: 600;
            color: #1e293b;
        }

        .inv-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
            border-bottom: 1px solid var(--border-strong);
        }

        .inv-table th {
            padding: 8px;
            font-weight: 700;
            color: #1e293b;
            border-bottom: 1px solid var(--border-strong);
            border-right: 1px solid var(--border-strong);
            text-align: left;
        }

        .inv-table th:last-child {
            border-right: none;
        }

        .inv-table td {
            padding: 8px;
            color: #334155;
            border-right: 1px solid var(--border-strong);
            vertical-align: top;
        }

        .inv-table td:last-child {
            border-right: none;
        }

        .inv-table .right { text-align: right; }
        .inv-table .center { text-align: center; }

        .inv-summary-grid {
            display: grid;
            grid-template-columns: 1fr 320px;
            border-bottom: 1px solid var(--border-strong);
        }

        .inv-empty-left {
            padding: 12px 16px;
            border-right: 1px solid var(--border-strong);
        }

        .inv-totals-wrap {
            padding: 0;
        }

        .inv-totals-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }

        .inv-totals-table td {
            padding: 6px 12px;
            color: #334155;
            border-bottom: 1px solid var(--border-strong);
        }

        .inv-totals-table tr:last-child td {
            border-bottom: none; /* Let the container border handle it */
        }

        .inv-totals-table td.label-col {
            border-right: 1px solid var(--border-strong);
            font-weight: 600;
        }
        
        .inv-totals-table td.amount-col {
            text-align: right;
            font-weight: 600;
            color: #1e293b;
        }
        
        .inv-amount-words-title {
            font-weight: 600;
            color: #1e293b;
        }

        .inv-amount-words {
            color: #334155;
            margin-top: 4px;
        }

        .inv-terms {
            padding: 8px 16px;
            border-bottom: 1px solid var(--border-strong);
            font-size: 13px;
            color: #334155;
        }

        .inv-terms-title {
            font-weight: 700;
            color: #1e293b;
            margin-bottom: 4px;
        }

        .inv-footer-grid {
            display: grid;
            grid-template-columns: 1fr 320px;
        }

        .inv-footer-left {
            padding: 16px;
            border-right: 1px solid var(--border-strong);
            display: flex;
            flex-direction: column;
            justify-content: flex-end;
        }

        .inv-footer-note {
            font-size: 12px;
            color: var(--text-secondary);
        }

        .inv-footer-brand {
            font-size: 12px;
            font-weight: 600;
            color: var(--text-muted);
            margin-top: 8px;
        }

        .inv-footer-brand span { color: var(--accent); }

        .inv-sign-block {
            padding: 16px;
            padding-top: 64px; /* Space for signature */
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: flex-end;
        }

        .inv-sign-line {
            width: 160px;
            height: 1px;
            background: var(--text-muted);
            margin: 0 0 8px 0;
        }

        .inv-sign-label {
            font-size: 12px;
            color: var(--text-muted);
        }

        """

start_idx = content.find(css_start_marker)
end_idx = content.find(css_end_marker)
if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_css + content[end_idx:]

# Replace renderOrderSummary
os_start = content.find("function renderOrderSummary(data) {")
os_end = content.find("        // ─────────────────────────────────────────────────────────────────────\n        // GST INVOICE renderer")

new_os = """function renderOrderSummary(data) {
            document.title = `Order Summary #${data.id || '—'} • SnapKhata`;

            const items = Array.isArray(data.items) ? data.items : [];
            const isPaid = data.status === 'PAID';

            const taxableItems = items.filter(i => {
                const t = String(i.type || '').toLowerCase();
                return t !== 'labor' && t !== 'labour' && t !== 'service';
            });
            const nonTaxableItems = items.filter(i => {
                const t = String(i.type || '').toLowerCase();
                return t === 'labor' || t === 'labour' || t === 'service';
            });

            const partsSubtotal = taxableItems.reduce((s, i) => s + Number(i.amount || 0), 0);
            const laborSubtotal = nonTaxableItems.reduce((s, i) => s + Number(i.amount || 0), 0);
            const subtotal = partsSubtotal + laborSubtotal;
            const grandTotal = Number(data.total_amount) || subtotal;

            let itemsHtml = '';
            
            if (taxableItems.length > 0) {
                taxableItems.forEach((item, idx) => {
                    const qty = Number(item.qty || 1);
                    const rate = Number(item.rate || 0);
                    const amount = Number(item.amount || 0);
                    itemsHtml += `
                    <tr>
                        <td class="center">${idx + 1}</td>
                        <td>${item.name || 'Spare Part'}</td>
                        <td class="center">${qty}</td>
                        <td class="right">${fmtMoney(rate > 0 ? rate : amount / qty)}</td>
                        <td class="right">${fmtMoney(amount)}</td>
                    </tr>`;
                });
            }

            if (nonTaxableItems.length > 0) {
                nonTaxableItems.forEach((item, idx) => {
                    const qty = Number(item.qty || 1);
                    const rate = Number(item.rate || 0);
                    const amount = Number(item.amount || 0);
                    itemsHtml += `
                    <tr>
                        <td class="center">${taxableItems.length + idx + 1}</td>
                        <td>${item.name || 'Servicing'}</td>
                        <td class="center">${qty}</td>
                        <td class="right">${fmtMoney(rate > 0 ? rate : amount / qty)}</td>
                        <td class="right">${fmtMoney(amount)}</td>
                    </tr>`;
                });
            }
            
            let totalQty = items.reduce((sum, item) => sum + Number(item.qty || 1), 0);
            itemsHtml += `
            <tr>
               <td></td>
               <td style="font-weight:700;">Total</td>
               <td class="center" style="font-weight:700;">${totalQty}</td>
               <td></td>
               <td class="right" style="font-weight:700;">${fmtMoney(grandTotal)}</td>
            </tr>`;

            const wordsTotal = numberToWords(Math.round(grandTotal));

            const html = `
            <div class="scaled-container">
                <div class="inv-page">
                    <div class="inv-doc-title">Order Summary</div>
                    <div class="inv-doc">
                        <div class="inv-header-grid">
                            <div class="inv-shop-info">
                                <div class="inv-shop-name">${data.shop_name || 'Business Name'}</div>
                                <div class="inv-shop-detail">
                                    Phone: ${data.shop_phone ? `+91 ${String(data.shop_phone).replace('+91', '').trim()}` : ''}
                                </div>
                            </div>
                            <div class="inv-meta-grid">
                                <div class="inv-bill-to">
                                    <div class="inv-col-label">Bill To:</div>
                                    <div class="inv-col-val">
                                        <div><strong>${data.customer_name || 'Walk-in Customer'}</strong></div>
                                        ${data.customer_phone ? `<div>Contact No: +91 ${String(data.customer_phone).replace('+91', '').trim()}</div>` : ''}
                                        ${data.vehicle_number ? `<div style="margin-top:4px;">Vehicle: ${data.vehicle_number}</div>` : ''}
                                        ${data.odometer_reading ? `<div>Odometer: ${data.odometer_reading} km</div>` : ''}
                                    </div>
                                </div>
                                <div class="inv-invoice-details">
                                    <div class="inv-col-label">Order Details:</div>
                                    <div class="inv-col-val">
                                        <div>No: ${data.id || '—'}</div>
                                        <div>Date: ${fmtDate(data.created_at)}</div>
                                        <div style="margin-top:6px;font-weight:700;color:${data.status === 'PAID' ? '#16a34a' : '#ea580c'}">${data.status}</div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <table class="inv-table">
                            <thead>
                                <tr>
                                    <th class="center" style="width:5%">#</th>
                                    <th style="width:45%">Item Name</th>
                                    <th class="center" style="width:10%">Quantity</th>
                                    <th class="right" style="width:20%">Price/ Unit (₹)</th>
                                    <th class="right" style="width:20%">Amount(₹)</th>
                                </tr>
                            </thead>
                            <tbody>${itemsHtml}</tbody>
                        </table>

                        <div class="inv-summary-grid">
                            <div class="inv-empty-left">
                                <!-- empty left side under totals -->
                                ${laborSubtotal > 0.01 ? `<div style="font-size:11px;color:#64748b;">Spare Parts: ${fmtMoney(partsSubtotal)} | Servicing: ${fmtMoney(laborSubtotal)}</div>` : ''}
                            </div>
                            <div class="inv-totals-wrap">
                                <table class="inv-totals-table">
                                    <tr>
                                        <td class="label-col">Sub Total</td>
                                        <td class="amount-col">${fmtMoney(subtotal)}</td>
                                    </tr>
                                    <tr>
                                        <td class="label-col">Total</td>
                                        <td class="amount-col">${fmtMoney(grandTotal)}</td>
                                    </tr>
                                    <tr>
                                        <td colspan="2" style="border-bottom: 1px solid var(--border-strong);">
                                            <div class="inv-amount-words-title">Order Amount In Words :</div>
                                            <div class="inv-amount-words">${wordsTotal} Rupees only</div>
                                        </td>
                                    </tr>
                                    ${(data.received_amount !== undefined && data.received_amount !== null) ? `
                                    <tr>
                                        <td class="label-col">Received ${data.payment_mode ? `(${data.payment_mode})` : ''}</td>
                                        <td class="amount-col">${fmtMoney(data.received_amount)}</td>
                                    </tr>
                                    ` : ''}
                                    ${(data.balance_due !== undefined && data.balance_due !== null) ? `
                                    <tr>
                                        <td class="label-col">Balance</td>
                                        <td class="amount-col">${fmtMoney(data.balance_due)}</td>
                                    </tr>
                                    ` : ''}
                                </table>
                            </div>
                        </div>
                        
                        <div class="inv-terms">
                            <div class="inv-terms-title">Terms And Conditions:</div>
                            <div>Thank you for doing business with us.</div>
                        </div>

                        <div class="inv-footer-grid">
                            <div class="inv-footer-left">
                                <div class="inv-footer-note">This is a digital order summary and does not require a signature.</div>
                                <div class="inv-footer-brand">Powered by <span>SnapKhata</span></div>
                            </div>
                            <div class="inv-sign-block">
                                <div class="inv-sign-line"></div>
                                <div class="inv-sign-label">Authorised Signature</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>`;

            $('content-wrap').innerHTML = html;
            $('content-wrap').style.display = 'block';
            $('fabPrint').style.display = 'block';
            hide('loader');
        }

"""
content = content[:os_start] + new_os + content[os_end:]

# Replace renderGstInvoice
os_start = content.find("function renderGstInvoice(data, gstMode) {")
os_end = content.find("        async function init() {")

new_os = """function renderGstInvoice(data, gstMode) {
            document.title = `Tax Invoice #${data.id || '—'} • SnapKhata`;

            const items = Array.isArray(data.items) ? data.items : [];
            const isPaid = data.status === 'PAID';

            const taxableItems = items.filter(i => {
                const t = String(i.type || '').toLowerCase();
                return t !== 'labor' && t !== 'labour' && t !== 'service';
            });
            const nonTaxableItems = items.filter(i => {
                const t = String(i.type || '').toLowerCase();
                return t === 'labor' || t === 'labour' || t === 'service';
            });

            const partsSubtotal = taxableItems.reduce((s, i) => s + Number(i.amount || 0), 0);
            const laborSubtotal = nonTaxableItems.reduce((s, i) => s + Number(i.amount || 0), 0);

            let gstAmt, grandTotal;
            if (gstMode === 'included') {
                gstAmt = partsSubtotal * 18 / 118;
                grandTotal = Number(data.total_amount) || (partsSubtotal + laborSubtotal);
            } else { // excluded
                gstAmt = partsSubtotal * 0.18;
                grandTotal = Number(data.total_amount) || (partsSubtotal + gstAmt + laborSubtotal);
            }

            const taxableValue = gstMode === 'included' ? partsSubtotal - gstAmt : partsSubtotal;

            let itemsHtml = '';

            if (taxableItems.length > 0) {
                taxableItems.forEach((item, idx) => {
                    const qty = Number(item.qty || 1);
                    const rate = Number(item.rate || 0);
                    const amount = Number(item.amount || 0);
                    // Base amount is without GST. Total amount includes GST.
                    const baseAmt = gstMode === 'included' ? amount * 100 / 118 : amount;
                    // Note: baseRate differs for included vs excluded
                    const baseRate = rate > 0 ? (gstMode === 'included' ? rate * 100 / 118 : rate) : baseAmt / qty;
                    const gstAmountForItem = baseAmt * 0.18;
                    const totalForItem = baseAmt + gstAmountForItem;

                    // the image shows columns: Quantity | Price/ Unit (₹) | GST(₹) | Amount(₹)
                    itemsHtml += `
                    <tr>
                        <td class="center">${idx + 1}</td>
                        <td>${item.name || 'Spare Part'}</td>
                        <td class="center">${qty}</td>
                        <td class="right">${fmtMoney(baseRate)}</td>
                        <td class="right">${fmtMoney(gstAmountForItem)} (18%)</td>
                        <td class="right">${fmtMoney(totalForItem)}</td>
                    </tr>`;
                });
            }

            if (nonTaxableItems.length > 0) {
                nonTaxableItems.forEach((item, idx) => {
                    const qty = Number(item.qty || 1);
                    const rate = Number(item.rate || 0);
                    const amount = Number(item.amount || 0);
                    itemsHtml += `
                    <tr>
                        <td class="center">${taxableItems.length + idx + 1}</td>
                        <td>${item.name || 'Servicing'}</td>
                        <td class="center">${qty}</td>
                        <td class="right">${fmtMoney(rate > 0 ? rate : amount / qty)}</td>
                        <td class="right">—</td>
                        <td class="right">${fmtMoney(amount)}</td>
                    </tr>`;
                });
            }
            
            let totalQty = items.reduce((sum, item) => sum + Number(item.qty || 1), 0);
            let totalGstAmt = gstAmt;
            itemsHtml += `
            <tr>
               <td></td>
               <td style="font-weight:700;">Total</td>
               <td class="center" style="font-weight:700;">${totalQty}</td>
               <td></td>
               <td class="right" style="font-weight:700;">${fmtMoney(gstAmt)}</td>
               <td class="right" style="font-weight:700;">${fmtMoney(grandTotal)}</td>
            </tr>`;

            const wordsTotal = numberToWords(Math.round(grandTotal));

            const html = `
            <div class="scaled-container">
                <div class="inv-page">
                    <div class="inv-doc-title">Tax Invoice</div>
                    <div class="inv-doc">
                        <div class="inv-header-grid">
                            <div class="inv-shop-info">
                                <div class="inv-shop-name">${data.shop_name || 'Business Name'}</div>
                                <div class="inv-shop-detail">
                                    Phone: ${data.shop_phone ? `+91 ${String(data.shop_phone).replace('+91', '').trim()}` : ''}
                                </div>
                                ${data.shop_gst ? `<div class="inv-gst-number">GSTIN: ${data.shop_gst}</div>` : ''}
                            </div>
                            <div class="inv-meta-grid">
                                <div class="inv-bill-to">
                                    <div class="inv-col-label">Bill To:</div>
                                    <div class="inv-col-val">
                                        <div><strong>${data.customer_name || 'Walk-in Customer'}</strong></div>
                                        ${data.customer_phone ? `<div>Contact No: +91 ${String(data.customer_phone).replace('+91', '').trim()}</div>` : ''}
                                        ${data.vehicle_number ? `<div style="margin-top:4px;">Vehicle: ${data.vehicle_number}</div>` : ''}
                                        ${data.odometer_reading ? `<div>Odometer: ${data.odometer_reading} km</div>` : ''}
                                    </div>
                                </div>
                                <div class="inv-invoice-details">
                                    <div class="inv-col-label">Invoice Details:</div>
                                    <div class="inv-col-val">
                                        <div>No: ${data.id || '—'}</div>
                                        <div>Date: ${fmtDate(data.created_at)}</div>
                                        <div style="margin-top:6px;font-weight:700;color:${data.status === 'PAID' ? '#16a34a' : '#ea580c'}">${data.status}</div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <table class="inv-table">
                            <thead>
                                <tr>
                                    <th class="center" style="width:5%">#</th>
                                    <th style="width:31%">Item Name</th>
                                    <th class="center" style="width:10%">Quantity</th>
                                    <th class="right" style="width:16%">Price/ Unit (₹)</th>
                                    <th class="right" style="width:18%">GST(₹)</th>
                                    <th class="right" style="width:20%">Amount(₹)</th>
                                </tr>
                            </thead>
                            <tbody>${itemsHtml}</tbody>
                        </table>

                        <div class="inv-summary-grid">
                            <div class="inv-empty-left">
                                <!-- empty left side under totals -->
                                ${laborSubtotal > 0.01 ? `<div style="font-size:11px;color:#64748b;">Spare Parts: ${fmtMoney(partsSubtotal)} | Servicing: ${fmtMoney(laborSubtotal)}</div>` : ''}
                            </div>
                            <div class="inv-totals-wrap">
                                <table class="inv-totals-table">
                                    <tr>
                                        <td class="label-col">Sub Total</td>
                                        <td class="amount-col">${fmtMoney(grandTotal)}</td>
                                    </tr>
                                    <tr>
                                        <td class="label-col">Total</td>
                                        <td class="amount-col">${fmtMoney(grandTotal)}</td>
                                    </tr>
                                    <tr>
                                        <td colspan="2" style="border-bottom: 1px solid var(--border-strong);">
                                            <div class="inv-amount-words-title">Invoice Amount In Words :</div>
                                            <div class="inv-amount-words">${wordsTotal} Rupees only</div>
                                        </td>
                                    </tr>
                                    ${(data.received_amount !== undefined && data.received_amount !== null) ? `
                                    <tr>
                                        <td class="label-col">Received ${data.payment_mode ? `(${data.payment_mode})` : ''}</td>
                                        <td class="amount-col">${fmtMoney(data.received_amount)}</td>
                                    </tr>
                                    ` : ''}
                                    ${(data.balance_due !== undefined && data.balance_due !== null) ? `
                                    <tr>
                                        <td class="label-col">Balance</td>
                                        <td class="amount-col">${fmtMoney(data.balance_due)}</td>
                                    </tr>
                                    ` : ''}
                                </table>
                            </div>
                        </div>
                        
                        <div class="inv-terms">
                            <div class="inv-terms-title">Terms And Conditions:</div>
                            <div>Thank you for doing business with us.</div>
                        </div>

                        <div class="inv-footer-grid">
                            <div class="inv-footer-left">
                                <div class="inv-footer-note">This is a computer-generated invoice and does not require a signature.</div>
                                <div class="inv-footer-brand">Powered by <span>SnapKhata</span></div>
                            </div>
                            <div class="inv-sign-block">
                                <div class="inv-sign-line"></div>
                                <div class="inv-sign-label">Authorised Signature</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>`;

            $('content-wrap').innerHTML = html;
            $('content-wrap').style.display = 'block';
            $('fabPrint').style.display = 'block';
            hide('loader');
        }

"""
content = content[:os_start] + new_os + content[os_end:]

with open('frontend/public/receipt.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated frontend/public/receipt.html successfully!")
