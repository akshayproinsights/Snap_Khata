"""
Pydantic validation models for vendor invoice extraction.
Phase 1: SnapKhata v2.1 OCR Upgrade — handles real-world Indian B2B invoices.

Tax variability:   IGST | CGST+SGST | COMBINED_GST (single column) | NONE
Discount variety:  % only | amount only | both | none
Missing totals:    printed_total_amount = 0 means vendor didn't print it
"""

from pydantic import BaseModel, Field, validator
from typing import Literal, Optional, List


# ---------------------------------------------------------------------------
# Line-item model
# ---------------------------------------------------------------------------

class ExtractedItem(BaseModel):
    """
    Single line item from the vendor invoice.
    AI extracts raw values; backend does all math.
    """
    description: str = ""
    hsn_code: Optional[str] = "N/A"
    unit: str = "NOS"

    # Quantities & pricing
    quantity: float = Field(..., gt=0)
    rate: float = Field(..., ge=0)   # ge=0 to allow FOC/free goods lines

    # Discount — AI extracts ONLY what is visually present
    disc_percent: float = Field(default=0, ge=0, le=100)
    disc_amount: float = Field(default=0, ge=0)

    # Tax fields — only the relevant ones will be non-zero
    cgst_percent: float = Field(default=0, ge=0)
    sgst_percent: float = Field(default=0, ge=0)
    igst_percent: float = Field(default=0, ge=0)
    combined_gst_percent: float = Field(default=0, ge=0)  # single GST% column

    # Tax type as extracted by AI
    tax_type: Literal["IGST", "CGST_SGST", "COMBINED_GST", "NONE", "UNKNOWN"] = "UNKNOWN"

    # Printed total — 0 means vendor did NOT print a line total (trust our math)
    printed_total_amount: float = Field(default=0, ge=0)

    @validator('tax_type')
    def validate_tax_consistency(cls, v, values):
        """Ensure the declared tax_type is consistent with extracted rates."""
        cgst = values.get('cgst_percent', 0)
        sgst = values.get('sgst_percent', 0)
        igst = values.get('igst_percent', 0)

        if v == "IGST" and (cgst > 0 or sgst > 0):
            raise ValueError('IGST tax_type cannot have CGST/SGST values — check extraction')
        if v == "CGST_SGST" and igst > 0:
            raise ValueError('CGST_SGST tax_type cannot have IGST value — check extraction')
        return v


# ---------------------------------------------------------------------------
# Header-level adjustment (footer discounts, round-off, scheme, etc.)
# ---------------------------------------------------------------------------

class HeaderAdjustment(BaseModel):
    """
    Invoice-level adjustments shown at the footer/summary section.

    Examples seen on Indian vendor invoices:
      - "Cash Discount Rs.500" -> HEADER_DISCOUNT
      - "Round Off +Rs.0.30"   -> ROUND_OFF
      - "Scheme / Promo"       -> SCHEME
    """
    adjustment_type: Literal["HEADER_DISCOUNT", "ROUND_OFF", "SCHEME", "OTHER"]
    amount: float          # positive = addition, negative = deduction
    description: Optional[str] = ""


# ---------------------------------------------------------------------------
# Full invoice
# ---------------------------------------------------------------------------

class ExtractedInvoice(BaseModel):
    """
    Complete validated invoice as extracted by Gemini and validated before math.
    """
    invoice_number: str = ""
    invoice_date: str = ""
    vendor_name: str = ""
    vendor_gstin: Optional[str] = None      # 15-char GSTIN; None if not on invoice
    place_of_supply: Optional[str] = None

    # Invoice-level tax type (drives routing logic)
    tax_type: Literal["IGST", "CGST_SGST", "COMBINED_GST", "NONE", "UNKNOWN"] = "UNKNOWN"

    items: List[ExtractedItem] = []
    header_adjustments: List[HeaderAdjustment] = []
