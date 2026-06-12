"""
PDF generation route for receipt sharing.
Generates a clean, properly-formatted PDF from receipt data using reportlab.
Called by receipt.html's Share PDF button on mobile PWA (Android & iOS).
"""

import io
import logging
import os
from typing import Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

from database import get_database_client

logger = logging.getLogger(__name__)

router = APIRouter()


def _fmt_money(val) -> str:
    """Format a number as Indian currency string."""
    try:
        num = float(val or 0)
        if num == int(num):
            return f"\u20b9{int(num):,}"
        return f"\u20b9{num:,.2f}"
    except Exception:
        return "\u20b90"


def _fmt_qty(val) -> str:
    try:
        num = float(val or 0)
        if num == int(num):
            return str(int(num))
        return f"{num:.2f}"
    except Exception:
        return "0"


def _number_to_words(n: float) -> str:
    """Convert number to Indian words (e.g. 1555 → 'One Thousand Five Hundred Fifty Five')."""
    ones = [
        '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
        'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
        'Seventeen', 'Eighteen', 'Nineteen'
    ]
    tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']

    n = int(n)
    if n == 0:
        return 'Zero'

    def below1000(num):
        if num < 20:
            return ones[num]
        if num < 100:
            return tens[num // 10] + (' ' + ones[num % 10] if num % 10 else '')
        return ones[num // 100] + ' Hundred' + (' ' + below1000(num % 100) if num % 100 else '')

    result = ''
    crore = n // 10000000;    n %= 10000000
    lakh = n // 100000;       n %= 100000
    thousand = n // 1000;     n %= 1000
    rest = n

    if crore:    result += below1000(crore) + ' Crore '
    if lakh:     result += below1000(lakh) + ' Lakh '
    if thousand: result += below1000(thousand) + ' Thousand '
    if rest:     result += below1000(rest)
    return result.strip()


def _build_pdf(data: dict) -> bytes:
    """Build the PDF bytes from receipt data using reportlab."""
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        SimpleDocTemplate, Table, TableStyle, Paragraph,
        Spacer, HRFlowable
    )
    from reportlab.lib.enums import TA_LEFT, TA_RIGHT, TA_CENTER

    buf = io.BytesIO()

    # ── Colours (match HTML design) ──────────────────────────────────────────
    DARK_NAVY  = colors.HexColor('#1e3a5f')
    TEXT_DARK  = colors.HexColor('#0f172a')
    TEXT_MID   = colors.HexColor('#334155')
    TEXT_MUTED = colors.HexColor('#64748b')
    BORDER     = colors.HexColor('#d1d9e0')
    BORDER_STR = colors.HexColor('#1e293b')
    RED        = colors.HexColor('#991b1b')
    RED_BG     = colors.HexColor('#fee2e2')
    GREEN      = colors.HexColor('#15803d')
    GREEN_BG   = colors.HexColor('#dcfce7')
    AMBER      = colors.HexColor('#92400e')
    AMBER_BG   = colors.HexColor('#fef3c7')
    WHITE      = colors.white
    LIGHT_GRAY = colors.HexColor('#f8fafc')
    HEADER_BG  = colors.HexColor('#f1f5f9')
    ACCENT_LIGHT = colors.HexColor('#e8f0fe')

    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=14 * mm,
        rightMargin=14 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
        title=data.get('shop_name', 'Receipt') + ' - Receipt',
    )

    styles = getSampleStyleSheet()
    W = A4[0] - 28 * mm  # usable width

    def style(name, **kwargs):
        return ParagraphStyle(name, fontName='Helvetica', **kwargs)

    # ── Paragraph styles ──────────────────────────────────────────────────────
    ST_SHOP = style('shop', fontSize=14, fontName='Helvetica-Bold', textColor=DARK_NAVY, leading=18)
    ST_LABEL = style('label', fontSize=8, textColor=TEXT_MUTED, leading=12, letterSpacing=0.8)
    ST_VALUE = style('value', fontSize=10, textColor=TEXT_DARK, leading=14)
    ST_VALUE_BOLD = style('value_b', fontSize=10, fontName='Helvetica-Bold', textColor=TEXT_DARK, leading=14)
    ST_SMALL = style('small', fontSize=8, textColor=TEXT_MID, leading=12)
    ST_TITLE = style('title', fontSize=9, fontName='Helvetica-Bold', textColor=TEXT_MUTED,
                     letterSpacing=2, alignment=TA_CENTER)
    ST_TOTAL_LABEL = style('tl', fontSize=10, textColor=TEXT_MID, leading=14)
    ST_TOTAL_VALUE = style('tv', fontSize=11, fontName='Helvetica-Bold', textColor=TEXT_DARK,
                           alignment=TA_RIGHT, leading=14)
    ST_BAL_VALUE = style('bv', fontSize=13, fontName='Helvetica-Bold', textColor=RED,
                         alignment=TA_RIGHT, leading=18)
    ST_OUTSTANDING_VALUE = style('ov', fontSize=11, fontName='Helvetica-Bold', textColor=RED,
                                 alignment=TA_RIGHT, leading=14)
    ST_WORDS = style('words', fontSize=8, textColor=TEXT_MID, leading=12, alignment=TA_RIGHT)
    ST_FOOTER = style('footer', fontSize=8, textColor=TEXT_MUTED, leading=12)
    ST_FOOTER_LINK = style('footer_link', fontSize=8, textColor=colors.HexColor('#2563eb'), leading=12)
    ST_TERMS_TITLE = style('terms_t', fontSize=8, fontName='Helvetica-Bold', textColor=TEXT_MUTED,
                           letterSpacing=0.8)
    ST_TERMS_TEXT = style('terms_tx', fontSize=9, textColor=TEXT_MID, leading=13)
    ST_TH = style('th', fontSize=9, fontName='Helvetica-Bold', textColor=DARK_NAVY, leading=13)
    ST_TH_R = style('th_r', fontSize=9, fontName='Helvetica-Bold', textColor=DARK_NAVY,
                    leading=13, alignment=TA_RIGHT)
    ST_TH_C = style('th_c', fontSize=9, fontName='Helvetica-Bold', textColor=DARK_NAVY,
                    leading=13, alignment=TA_CENTER)
    ST_TD = style('td', fontSize=9, textColor=TEXT_DARK, leading=13)
    ST_TD_R = style('td_r', fontSize=9, textColor=TEXT_DARK, leading=13, alignment=TA_RIGHT)
    ST_TD_C = style('td_c', fontSize=9, textColor=TEXT_DARK, leading=13, alignment=TA_CENTER)
    ST_TD_TOTAL = style('td_tot', fontSize=9, fontName='Helvetica-Bold', textColor=TEXT_DARK, leading=13)
    ST_TD_TOTAL_R = style('td_tot_r', fontSize=9, fontName='Helvetica-Bold', textColor=TEXT_DARK,
                          leading=13, alignment=TA_RIGHT)

    story = []

    # ─────────────────────────────────────────────────────────────────────────
    # Helper: outer box (border around entire receipt)
    # We build everything inside a single Table row to simulate the inv-doc border
    # ─────────────────────────────────────────────────────────────────────────

    shop_name    = data.get('shop_name', 'Our Shop')
    shop_addr    = data.get('shop_address', '')
    shop_phone   = data.get('shop_phone', '')
    shop_gst     = data.get('shop_gst', '')
    cust_name    = data.get('customer_name', 'Walk-in Customer')
    cust_phone   = data.get('customer_phone', '')
    receipt_no   = data.get('id', '')
    created_at   = data.get('created_at', '')
    status       = data.get('status', 'UNPAID')
    items        = data.get('items', [])
    total_amount = float(data.get('total_amount') or 0)
    recv_amount  = float(data.get('received_amount') or 0)
    balance_due  = float(data.get('balance_due') or 0)
    ledger_bal   = data.get('ledger_balance_due')
    custom_terms = data.get('custom_terms', '') or 'Thank you for doing business with us.'

    # Format date
    import re
    date_str = ''
    if created_at:
        try:
            from datetime import datetime
            if re.match(r'^\d{2}-\d{2}-\d{4}$', str(created_at)):
                dd, mm_n, yyyy = str(created_at).split('-')
                dt = datetime(int(yyyy), int(mm_n), int(dd))
            else:
                dt = datetime.fromisoformat(str(created_at).replace('Z', '+00:00'))
            months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
            date_str = f"{dt.day:02d} {months[dt.month-1]} {dt.year}"
        except Exception:
            date_str = str(created_at)

    # ── DOCUMENT TITLE ────────────────────────────────────────────────────────
    story.append(Paragraph("ORDER SUMMARY", ST_TITLE))
    story.append(Spacer(1, 6))

    inner_content = []  # rows inside the outer border table

    # ── HEADER BAR (shop name left | ORDER SUMMARY right) ────────────────────
    header_left = [
        Paragraph(shop_name, ST_SHOP),
    ]
    if shop_addr:
        header_left.append(Spacer(1, 2))
        header_left.append(Paragraph(shop_addr, ST_SMALL))
    if shop_phone:
        header_left.append(Paragraph(f"Ph: {shop_phone}", ST_SMALL))
    if shop_gst:
        header_left.append(Paragraph(f"GSTIN: {shop_gst}", ST_SMALL))

    header_right = [
        Paragraph("ORDER", style('ord', fontSize=18, fontName='Helvetica-Bold',
                                 textColor=DARK_NAVY, alignment=TA_RIGHT, leading=22)),
        Paragraph("SUMMARY", style('sum', fontSize=8, fontName='Helvetica-Bold',
                                   textColor=TEXT_MUTED, alignment=TA_RIGHT,
                                   letterSpacing=2, leading=12)),
    ]

    header_tbl = Table(
        [[header_left, header_right]],
        colWidths=[W * 0.6, W * 0.4],
    )
    header_tbl.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LINEBELOW', (0,0), (-1,-1), 0.5, BORDER_STR),
    ]))

    inner_content.append(['header', header_tbl])

    # ── META STRIP (Bill To | Order Details) ─────────────────────────────────
    bill_left = [
        Paragraph("BILL TO", style('bt', fontSize=8, fontName='Helvetica-Bold',
                                   textColor=TEXT_MUTED, letterSpacing=0.8, leading=12)),
        Spacer(1, 4),
        Paragraph(cust_name, style('cn', fontSize=12, fontName='Helvetica-Bold',
                                   textColor=TEXT_DARK, leading=16)),
    ]
    if cust_phone:
        bill_left.append(Paragraph(
            f"Ph: {cust_phone}",
            style('cp', fontSize=9, textColor=colors.HexColor('#2563eb'), leading=14)
        ))

    # Status badge colour
    if status == 'PAID':
        badge_fg, badge_bg = GREEN, GREEN_BG
    elif status == 'PARTIAL':
        badge_fg, badge_bg = AMBER, AMBER_BG
    else:
        badge_fg, badge_bg = RED, RED_BG

    order_details = [
        [Paragraph("ORDER DETAILS", style('od', fontSize=8, fontName='Helvetica-Bold',
                                          textColor=TEXT_MUTED, letterSpacing=0.8, leading=12)), ''],
        [Paragraph("No.", ST_LABEL), Paragraph(f"#{receipt_no}", ST_VALUE_BOLD)],
        [Paragraph("Date", ST_LABEL), Paragraph(date_str, ST_VALUE)],
    ]
    od_tbl = Table(order_details, colWidths=[28, W * 0.35])
    od_tbl.setStyle(TableStyle([
        ('SPAN', (0,0), (1,0)),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 1),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1),
    ]))

    # Status badge as a small table cell
    status_badge_tbl = Table(
        [[Paragraph(status, style('sb', fontSize=9, fontName='Helvetica-Bold',
                                  textColor=badge_fg, alignment=TA_CENTER))]],
        colWidths=[56],
    )
    status_badge_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), badge_bg),
        ('ROUNDEDCORNERS', [4, 4, 4, 4]),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('BOX', (0,0), (-1,-1), 0.5, badge_fg),
    ]))

    meta_right = [od_tbl, Spacer(1, 6), status_badge_tbl]

    meta_tbl = Table(
        [[bill_left, meta_right]],
        colWidths=[W * 0.55, W * 0.45],
    )
    meta_tbl.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (0,-1), 0),
        ('RIGHTPADDING', (0,0), (0,-1), 8),
        ('LEFTPADDING', (1,0), (1,-1), 8),
        ('RIGHTPADDING', (1,0), (1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LINEBEFORE', (1,0), (1,-1), 0.5, BORDER),
        ('LINEBELOW', (0,0), (-1,-1), 0.5, BORDER_STR),
    ]))

    inner_content.append(['meta', meta_tbl])

    # ── ITEMS TABLE ───────────────────────────────────────────────────────────
    col_w = [20, W * 0.44, 55, 70, 70]

    tbl_data = [[
        Paragraph('#', ST_TH_C),
        Paragraph('Item Name', ST_TH),
        Paragraph('Quantity', ST_TH_C),
        Paragraph('Price/Unit (₹)', ST_TH_R),
        Paragraph('Amount (₹)', ST_TH_R),
    ]]

    total_qty = 0.0
    for i, item in enumerate(items):
        qty = float(item.get('quantity') or item.get('qty') or 1)
        rate = float(item.get('rate') or 0)
        amt = float(item.get('amount') or 0)
        total_qty += qty
        tbl_data.append([
            Paragraph(str(i + 1), ST_TD_C),
            Paragraph(str(item.get('name', 'Item')), ST_TD),
            Paragraph(_fmt_qty(qty), ST_TD_C),
            Paragraph(_fmt_money(rate), ST_TD_R),
            Paragraph(_fmt_money(amt), ST_TD_R),
        ])

    # Total row
    tbl_data.append([
        Paragraph('', ST_TD),
        Paragraph('TOTAL', ST_TD_TOTAL),
        Paragraph(_fmt_qty(total_qty), style('tq', fontSize=9, fontName='Helvetica-Bold',
                                              textColor=TEXT_DARK, alignment=TA_CENTER)),
        Paragraph('', ST_TD),
        Paragraph(_fmt_money(total_amount), ST_TD_TOTAL_R),
    ])

    items_tbl = Table(tbl_data, colWidths=col_w, repeatRows=1)

    item_style = [
        # Header row
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
        ('LINEBELOW', (0, 0), (-1, 0), 0.5, BORDER_STR),
        ('TOPPADDING', (0, 0), (-1, 0), 8),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
        # All cells
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 1), (-1, -2), 7),
        ('BOTTOMPADDING', (0, 1), (-1, -2), 7),
        # Grid lines between data rows
        ('LINEBELOW', (0, 1), (-1, -2), 0.3, BORDER),
        ('LINEAFTER', (0, 0), (-2, -1), 0.3, BORDER),
        # Total row
        ('LINEABOVE', (0, -1), (-1, -1), 1.5, BORDER_STR),
        ('LINEBELOW', (0, -1), (-1, -1), 1.5, BORDER_STR),
        ('TOPPADDING', (0, -1), (-1, -1), 8),
        ('BOTTOMPADDING', (0, -1), (-1, -1), 8),
        ('BACKGROUND', (0, -1), (-1, -1), LIGHT_GRAY),
        # Outer border
        ('BOX', (0, 0), (-1, -1), 0.5, BORDER_STR),
    ]
    items_tbl.setStyle(TableStyle(item_style))

    inner_content.append(['items', items_tbl])

    # ── SUMMARY GRID ──────────────────────────────────────────────────────────
    # Left side: blank (notes area) | Right side: totals
    totals_rows = [
        [Paragraph('Total', ST_TOTAL_LABEL), Paragraph(_fmt_money(total_amount), ST_TOTAL_VALUE)],
    ]
    if recv_amount > 0:
        totals_rows.append([
            Paragraph('Amount Received', ST_TOTAL_LABEL),
            Paragraph(_fmt_money(recv_amount), ST_TOTAL_VALUE),
        ])

    totals_rows.append([
        Paragraph('Balance Due', style('bl', fontSize=11, fontName='Helvetica-Bold',
                                       textColor=RED, leading=16)),
        Paragraph(_fmt_money(balance_due), style('bv2', fontSize=13, fontName='Helvetica-Bold',
                                                  textColor=RED, alignment=TA_RIGHT, leading=18)),
    ])

    totals_tbl = Table(totals_rows, colWidths=[W * 0.3, W * 0.2])
    totals_tbl.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-2), 5),
        ('BOTTOMPADDING', (0,0), (-1,-2), 5),
        ('LINEBELOW', (0,0), (-1,-2), 0.3, BORDER),
        ('TOPPADDING', (0,-1), (-1,-1), 8),
        ('BOTTOMPADDING', (0,-1), (-1,-1), 8),
        ('LINEABOVE', (0,-1), (-1,-1), 0.5, BORDER),
    ]))

    # Outstanding balance row
    outstanding_rows = []
    if ledger_bal is not None and float(ledger_bal) > 0:
        outstanding_rows = [
            [Paragraph('Total Outstanding Balance', style('ob', fontSize=10, fontName='Helvetica-Bold',
                                                           textColor=RED, leading=14)),
             Paragraph(_fmt_money(ledger_bal), style('obv', fontSize=11, fontName='Helvetica-Bold',
                                                      textColor=RED, alignment=TA_RIGHT, leading=14))],
            [Paragraph(_number_to_words(float(ledger_bal)) + ' Rupees Due',
                       style('ow', fontSize=8, textColor=TEXT_MID, leading=12)),
             Paragraph('', ST_SMALL)],
        ]

    words_rows = []
    if balance_due > 0:
        words_rows = [
            Paragraph(_number_to_words(balance_due) + ' Rupees Due',
                      style('ww', fontSize=8, textColor=TEXT_MID, alignment=TA_RIGHT, leading=12)),
        ]

    # Build right-side column (totals panel)
    right_col_items = [totals_tbl]
    if words_rows:
        right_col_items.append(Spacer(1, 4))
        for w in words_rows:
            right_col_items.append(w)
    if outstanding_rows:
        right_col_items.append(Spacer(1, 8))
        outstanding_tbl = Table(outstanding_rows, colWidths=[W * 0.3, W * 0.2])
        outstanding_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), RED_BG),
            ('BOX', (0,0), (-1,-1), 0.5, RED),
            ('TOPPADDING', (0,0), (-1,-1), 5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 5),
            ('LEFTPADDING', (0,0), (-1,-1), 8),
            ('RIGHTPADDING', (0,0), (-1,-1), 8),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ]))
        right_col_items.append(outstanding_tbl)

    summary_tbl = Table(
        [[Paragraph('', ST_SMALL), right_col_items]],
        colWidths=[W * 0.5, W * 0.5],
    )
    summary_tbl.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LINEBEFORE', (1,0), (1,-1), 0.5, BORDER),
        ('LINEBELOW', (0,0), (-1,-1), 0.5, BORDER_STR),
    ]))

    inner_content.append(['summary', summary_tbl])

    # ── TERMS ─────────────────────────────────────────────────────────────────
    terms_content = [
        Paragraph("TERMS &amp; CONDITIONS", ST_TERMS_TITLE),
        Spacer(1, 4),
        Paragraph(custom_terms, ST_TERMS_TEXT),
    ]

    inner_content.append(['terms', terms_content])

    # ── FOOTER (left: powered by | right: signature) ──────────────────────────
    footer_left = [
        Paragraph("This is a digital order summary.", ST_FOOTER),
        Paragraph("Powered by <b>SnapKhata</b>", style('pl', fontSize=8,
                                                         textColor=colors.HexColor('#2563eb'),
                                                         leading=12)),
    ]
    footer_right = [
        HRFlowable(width=100, thickness=0.5, color=BORDER_STR),
        Spacer(1, 4),
        Paragraph(f"For {shop_name}", style('sig', fontSize=8, textColor=TEXT_MUTED,
                                             alignment=TA_CENTER, leading=12)),
        Paragraph("Authorised Signature", style('as', fontSize=8, textColor=TEXT_MUTED,
                                                alignment=TA_CENTER, leading=12)),
    ]

    footer_tbl = Table(
        [[footer_left, footer_right]],
        colWidths=[W * 0.55, W * 0.45],
    )
    footer_tbl.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
        ('LEFTPADDING', (0,0), (0,-1), 0),
        ('RIGHTPADDING', (0,0), (0,-1), 8),
        ('LEFTPADDING', (1,0), (1,-1), 8),
        ('RIGHTPADDING', (1,0), (1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('LINEBEFORE', (1,0), (1,-1), 0.5, BORDER),
    ]))

    inner_content.append(['footer', footer_tbl])

    # ── Assemble all sections into outer border table ─────────────────────────
    # Each section is wrapped with padding; outer box = border
    HPAD = 14  # horizontal padding inside border

    def wrap(content, top=10, bottom=10):
        """Wrap content in a single-cell table with border padding."""
        tbl = Table([[content]], colWidths=[W - 0])
        tbl.setStyle(TableStyle([
            ('LEFTPADDING', (0,0), (-1,-1), HPAD),
            ('RIGHTPADDING', (0,0), (-1,-1), HPAD),
            ('TOPPADDING', (0,0), (-1,-1), top),
            ('BOTTOMPADDING', (0,0), (-1,-1), bottom),
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ]))
        return tbl

    outer_rows = []
    for key, content in inner_content:
        if key == 'header':
            outer_rows.append([wrap(content, top=12, bottom=12)])
        elif key == 'meta':
            outer_rows.append([wrap(content, top=10, bottom=10)])
        elif key == 'items':
            outer_rows.append([wrap(content, top=0, bottom=0)])
        elif key == 'summary':
            outer_rows.append([wrap(content, top=0, bottom=0)])
        elif key == 'terms':
            outer_rows.append([wrap(content, top=10, bottom=10)])
        elif key == 'footer':
            outer_rows.append([wrap(content, top=10, bottom=12)])

    outer_tbl = Table(outer_rows, colWidths=[W])
    outer_style = [
        ('BOX', (0, 0), (-1, -1), 1, BORDER_STR),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ]
    # Add internal dividers between rows
    for i in range(len(outer_rows) - 1):
        outer_style.append(('LINEBELOW', (0, i), (-1, i), 0.5, BORDER_STR))

    outer_tbl.setStyle(TableStyle(outer_style))
    story.append(outer_tbl)

    doc.build(story)
    return buf.getvalue()


@router.get("/receipts/{receipt_number:path}/pdf")
async def get_receipt_pdf(
    receipt_number: str,
    u: Optional[str] = None,
):
    """
    Generate and return a PDF for a receipt.
    Called from receipt.html Share PDF button.
    No auth required (same as the public receipt JSON endpoint).
    """
    import httpx

    # ── Fetch receipt data from the public receipts API ───────────────────────
    api_base = os.getenv("SELF_API_BASE", "http://localhost:8000")
    params = {"u": u} if u else {}

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.get(
                f"{api_base}/api/public/receipts/{receipt_number}",
                params=params,
            )
        if resp.status_code == 404:
            raise HTTPException(status_code=404, detail="Receipt not found")
        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to fetch receipt data")
        data = resp.json()
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching receipt data for PDF {receipt_number}: {e}")
        raise HTTPException(status_code=500, detail="Failed to load receipt data")

    # ── Build PDF ─────────────────────────────────────────────────────────────
    try:
        pdf_bytes = _build_pdf(data)
    except Exception as e:
        logger.error(f"Error generating PDF for {receipt_number}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Failed to generate PDF")

    shop_name = str(data.get('shop_name', 'Receipt')).replace(' ', '_')
    filename = f"{shop_name}_{receipt_number}.pdf"

    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(pdf_bytes)),
            "Cache-Control": "no-store",
            "Access-Control-Allow-Origin": "*",
        },
    )
