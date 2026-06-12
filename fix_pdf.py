import re

files = [
    '/root/Snap_Khata/frontend/public/receipt.html',
    '/root/Snap_Khata/mobile/web/receipt.html'
]

pdf_export_css = """
        /* ── PDF Export Styles (Mirrors Print Styles for Sharing) ── */
        body.pdf-export { background: #fff !important; }
        .pdf-export .scaled-container { padding: 0 !important; width: 800px !important; margin: 0 auto !important; }
        .pdf-export .inv-page { padding: 0 !important; width: 100% !important; }
        .pdf-export .inv-doc { box-shadow: none !important; border: 1.2px solid #000000 !important; margin: 0 !important; }
        .pdf-export .inv-header-bar { border-bottom: 1.2px solid #000000 !important; }
        .pdf-export .inv-meta-strip { border-bottom: 1.2px solid #000000 !important; }
        .pdf-export .inv-bill-to { border-right: 1.2px solid #000000 !important; }
        .pdf-export .inv-table { border: 1.2px solid #000000 !important; }
        .pdf-export .inv-table th { border-bottom: 1.2px solid #000000 !important; border-right: 1.2px solid #000000 !important; }
        .pdf-export .inv-table td { border-bottom: 1.2px solid #000000 !important; border-right: 1.2px solid #000000 !important; }
        .pdf-export .inv-summary-grid { border-top: 1.2px solid #000000 !important; border-bottom: 1.2px solid #000000 !important; }
        .pdf-export .inv-summary-left { border-right: 1.2px solid #000000 !important; }
        .pdf-export .inv-totals-row { border-bottom: 1.2px solid #000000 !important; }
        .pdf-export .inv-amount-words { border-top: 1.2px solid #000000 !important; }
        .pdf-export .inv-upi-section { border-top: 1.2px solid #000000 !important; }
        .pdf-export .inv-terms { border-top: 1.2px solid #000000 !important; }
        .pdf-export .inv-footer { border-top: 1.2px solid #000000 !important; }
        .pdf-export .inv-footer-left { border-right: 1.2px solid #000000 !important; }
        .pdf-export .inv-logo, .pdf-export .inv-logo-initials { display: block !important; visibility: visible !important; opacity: 1 !important; }
        .pdf-export .fab-print { display: none !important; }
        .pdf-export .inv-table tr { page-break-inside: avoid !important; }
"""

for filepath in files:
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        continue

    # Add the CSS right before /* ── Auto Print Overlay ── */
    if "/* ── PDF Export Styles (Mirrors Print Styles for Sharing) ── */" not in content:
        content = content.replace("        /* ── Auto Print Overlay ── */", pdf_export_css + "\n        /* ── Auto Print Overlay ── */")

    # Replace shareAsPdf
    js_target = """                if (!document.getElementById('spin-style')) {
                    const style = document.createElement('style');
                    style.id = 'spin-style';
                    style.innerHTML = `@keyframes spin { to { transform: rotate(360deg); } }`;
                    document.head.appendChild(style);
                }

                const element = document.querySelector('.scaled-container') || document.getElementById('content-wrap');
                const filename = (window._pdfFilename || 'receipt') + '.pdf';

                const opt = {
                    margin:       [10, 10, 10, 10],
                    filename:     filename,
                    image:        { type: 'jpeg', quality: 0.98 },
                    html2canvas:  { scale: 2, useCORS: true, logging: false },
                    jsPDF:        { unit: 'mm', format: 'a4', orientation: 'portrait' }
                };

                const pdfBlob = await html2pdf().from(element).set(opt).outputPdf('blob');
                const file = new File([pdfBlob], filename, { type: 'application/pdf' });"""
    
    js_replacement = """                if (!document.getElementById('spin-style')) {
                    const style = document.createElement('style');
                    style.id = 'spin-style';
                    style.innerHTML = `@keyframes spin { to { transform: rotate(360deg); } }`;
                    document.head.appendChild(style);
                }

                document.body.classList.add('pdf-export');
                await new Promise(r => setTimeout(r, 50));

                const element = document.querySelector('.scaled-container') || document.getElementById('content-wrap');
                const filename = (window._pdfFilename || 'receipt') + '.pdf';

                const opt = {
                    margin:       [10, 10, 10, 10],
                    filename:     filename,
                    image:        { type: 'jpeg', quality: 0.98 },
                    html2canvas:  { scale: 2, useCORS: true, logging: false, windowWidth: 800 },
                    jsPDF:        { unit: 'mm', format: 'a4', orientation: 'portrait' }
                };

                const pdfBlob = await html2pdf().from(element).set(opt).outputPdf('blob');
                
                document.body.classList.remove('pdf-export');

                const file = new File([pdfBlob], filename, { type: 'application/pdf' });"""

    if js_target in content:
        content = content.replace(js_target, js_replacement)
    
    # Also fix the catch block to remove the class just in case
    catch_target = """            } catch (err) {
                console.error('Failed to share PDF:', err);
                alert('Could not generate PDF. Please try Print instead.');
            } finally {"""
    
    catch_replacement = """            } catch (err) {
                console.error('Failed to share PDF:', err);
                document.body.classList.remove('pdf-export');
                alert('Could not generate PDF. Please try Print instead.');
            } finally {"""
            
    if catch_target in content:
        content = content.replace(catch_target, catch_replacement)
        
    with open(filepath, 'w') as f:
        f.write(content)
        print(f"Updated {filepath}")

