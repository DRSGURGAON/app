package com.seedhachat.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PhoneUtilsTest {
    @Test fun plainTenDigitGetsDefaultCode() =
        assertEquals("919485519555", PhoneUtils.normalize("9485519555", "91"))

    @Test fun spacesDashesBracketsAreIgnored() =
        assertEquals("919876543210", PhoneUtils.normalize(" (98765) 432-10 ", "91"))

    @Test fun explicitPlusWinsOverDefaultCode() =
        assertEquals("447911123456", PhoneUtils.normalize("+44 7911 123456", "91"))

    @Test fun doubleZeroInternationalPrefix() =
        assertEquals("919876543210", PhoneUtils.normalize("0091 98765 43210", "91"))

    @Test fun leadingTrunkZeroDropped() =
        assertEquals("919876543210", PhoneUtils.normalize("09876543210", "91"))

    @Test fun alreadyHasCountryCodeWithoutPlus() =
        assertEquals("919876543210", PhoneUtils.normalize("919876543210", "91"))

    @Test fun indianMobileStartingWith91IsNotMistakenForCode() =
        assertEquals("919123456789", PhoneUtils.normalize("9123456789", "91"))

    @Test fun otherDefaultCountry() =
        assertEquals("971501234567", PhoneUtils.normalize("050 123 4567", "+971"))

    @Test fun rejectsEmptyTooShortTooLong() {
        assertNull(PhoneUtils.normalize("", "91"))
        assertNull(PhoneUtils.normalize("abc", "91"))
        assertNull(PhoneUtils.normalize("12345", ""))
        assertNull(PhoneUtils.normalize("+1234567890123456", "91"))
    }

    @Test fun extractsNumberFromMessage() =
        assertEquals("9485519555", PhoneUtils.extractFirst("Order ke liye call karein 94855 19555, dhanyavaad"))

    @Test fun extractKeepsPlus() =
        assertEquals("+919876543210", PhoneUtils.extractFirst("Contact: +91-98765-43210 (Ramesh)"))

    @Test fun extractPrefersLongNumberOverDate() =
        assertEquals("9876543210", PhoneUtils.extractFirst("Date 2026-11-15, mob 98765 43210"))

    @Test fun extractReturnsNullWithoutNumber() =
        assertNull(PhoneUtils.extractFirst("koi number nahi hai, sirf 123"))

    @Test fun linkWithoutMessage() =
        assertEquals("https://wa.me/919485519555", PhoneUtils.waLink("919485519555", "  "))

    @Test fun linkEncodesHindiAndSpaces() =
        assertEquals(
            "https://wa.me/919485519555?text=%E0%A4%A8%E0%A4%AE%E0%A4%B8%E0%A5%8D%E0%A4%A4%E0%A5%87%20ji%20%26%20hi",
            PhoneUtils.waLink("919485519555", "नमस्ते ji & hi"),
        )

    @Test fun prettyFormatsIndianNumbers() {
        assertEquals("+91 94855 19555", PhoneUtils.pretty("919485519555"))
        assertEquals("+447911123456", PhoneUtils.pretty("447911123456"))
    }
}
