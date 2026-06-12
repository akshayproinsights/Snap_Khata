"""
PDF generation route for receipt sharing.
Generates a clean, perfectly formatted PDF using Playwright headless browser
to take a perfect screenshot of the HTML frontend, providing 100% accurate styling.
"""

import logging
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response
from playwright.async_api import async_playwright
import tempfile
import os
import asyncio

router = APIRouter()
logger = logging.getLogger(__name__)

async def generate_pdf_from_html(receipt_number: str, username: str = None) -> bytes:
    """Uses Playwright to render the exact HTML receipt as a PDF."""
    async with async_playwright() as p:
        # Launch Chromium headless
        browser = await p.chromium.launch(headless=True, args=['--no-sandbox', '--disable-dev-shm-usage'])
        page = await browser.new_page()
        
        # Determine the URL - we hit our own frontend
        # Use localhost to fetch the local updated receipt.html directly
        base_url = "http://localhost:3000"
        
        url = f"{base_url}/receipt.html?i={receipt_number}"
        if username:
            url += f"&u={username}"
            
        # Add pdf=1 to let the frontend know it's being rendered for a PDF
        url += "&pdf=1"
        
        logger.info(f"Generating PDF for URL: {url}")
        
        # Load the page, wait for all network requests (API calls) to finish
        try:
            await page.goto(url, wait_until="networkidle", timeout=15000)
            
            # Additional wait to ensure dynamic JS components render correctly
            await page.wait_for_timeout(1500)

            # Explicitly set print media - this ensures @media print CSS fires
            # (page.pdf() also does this internally but we do it early so JS can see print styles)
            await page.emulate_media(media="print")
            
            # Inject CSS + JS to fix all visual issues before PDF capture
            await page.evaluate("""
                () => {
                    // Force the PDF export class to apply frontend styling
                    document.body.classList.add('pdf-export');

                    // 1. HIDE the Share PDF floating button absolutely
                    const elementsToHide = document.querySelectorAll(
                        '#fabPrint, .fab-print, .btn-share-pdf, [id="fabPrint"]'
                    );
                    elementsToHide.forEach(el => { el.style.setProperty('display', 'none', 'important'); });

                    // 2. Also hide by text content search (belt-and-suspenders)
                    document.querySelectorAll('button').forEach(btn => {
                        if (btn.textContent && btn.textContent.toLowerCase().includes('share pdf')) {
                            btn.style.setProperty('display', 'none', 'important');
                            if (btn.parentElement) btn.parentElement.style.setProperty('display', 'none', 'important');
                        }
                    });
                    
                    // 3. Hide any overlays
                    document.querySelectorAll('[style*="z-index"]').forEach(el => {
                        const z = parseInt(el.style.zIndex || 0);
                        if (z > 1000) el.style.setProperty('display', 'none', 'important');
                    });

                    // 4. Inject a <style> to fix border issues
                    const style = document.createElement('style');
                    style.textContent = `
                        /* Hide ORDER SUMMARY / TAX INVOICE / ACCOUNT STATEMENT title above the doc */
                        .inv-doc-title {
                            display: none !important;
                        }

                        /* Ensure header and meta-strip bottom borders are visible (Bill To above border line) */
                        .inv-header-bar {
                            border-bottom: 1px solid #d1d9e0 !important;
                        }
                        .inv-meta-strip {
                            border-bottom: 1px solid #d1d9e0 !important;
                        }
                        .inv-bill-to {
                            border-right: 1px solid #d1d9e0 !important;
                        }

                        /* Remove thick 2px borders from TOTAL row - use uniform 1px */
                        .inv-total-row td {
                            border-top: 1px solid #d1d9e0 !important;
                            border-bottom: 1px solid #d1d9e0 !important;
                        }

                        /* Remove thick 2px border-top from grand total panel row */
                        .inv-totals-row.grand {
                            border-top: 1px solid #d1d9e0 !important;
                        }

                        /* Remove redundant top border from summary grid */
                        .inv-summary-grid {
                            border-top: none !important;
                        }

                        /* Clean outer border on the document */
                        .inv-doc {
                            border: 1px solid #d1d9e0 !important;
                            box-shadow: none !important;
                            border-radius: 4px !important;
                            overflow: hidden !important;
                        }

                        /* Hide fab and print buttons absolutely */
                        #fabPrint, .fab-print, .btn-share-pdf {
                            display: none !important;
                        }
                    `;
                    document.head.appendChild(style);
                }
            """)
            
            # Generate the PDF
            # A4 dimensions are typically 8.27 × 11.69 inches
            pdf_bytes = await page.pdf(
                format="A4",
                print_background=True,
                margin={"top": "10mm", "right": "10mm", "bottom": "10mm", "left": "10mm"}
            )
            
        except Exception as e:
            logger.error(f"Playwright PDF generation failed: {e}")
            raise e
        finally:
            await browser.close()
            
        return pdf_bytes

@router.get("/receipts/{receipt_number:path}/pdf")
async def get_receipt_pdf(receipt_number: str, u: str = Query(None, description="Username (optional)")):
    """
    Generate a PDF of the receipt using Playwright.
    """
    logger.info(f"Generating perfect PDF for receipt {receipt_number}")
    
    try:
        # Just use playwright to fetch the URL directly
        pdf_bytes = await generate_pdf_from_html(receipt_number, u)
        
        filename = f"receipt_{receipt_number}.pdf"
        
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={filename}"
            }
        )
    except Exception as e:
        logger.error(f"Error generating PDF for {receipt_number}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
