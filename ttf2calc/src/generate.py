''' DO NOT IMPORT THIS SCRIPT.

This is a standalone script intended to regenerate encodings.json

JSON object format:
{
    "encoding_name": {
        "calculator_codepoint": "unicode_character",
        ...
    },
    ...
}
For example:
{
    "Just The Letter A": {
        "0x41": "A"
    },
    "Just The Letter B": {
        "0x42": "B"
    },
    "ASCII Numerals": {
        "0x30": "0",
        "0x31": "1",
        "0x32": "2",
        "0x33": "3",
        "0x34": "4",
        "0x35": "5",
        "0x36": "6",
        "0x37": "7",
        "0x38": "8",
        "0x39": "9"
    }
}

IMPORTANT NOTE:
None of the encodings are true ASCII, though there is significant overlap.
For the 0x20-0x7F range, here are the differences:
- 0x24: '$' is replaced with U+2074 (Superscript Four)
- 0x5B: '[' is replaced with U+03B8 (Greek small letter theta)
- NOTE: '[' was relocated to 0xC1


'''

''' This script is intended to be run as a standalone script to regenerate 
encodings.json. It is not meant to be imported by other scripts. 
The encodings.json file contains mappings of calculator codepoints 
to Unicode characters for various character encodings used in the 
application.

The encodings this needs to generate are:
    "Alphanumeric characters only",
    "All ASCII characters",
    "TI-84 Plus CE character set",
    "Custom"

"Custom" is user-editable. If it has to be regenerated, it will be reset
to the default mapping of the TI-84 Plus CE character set.

'''

import json
from pathlib import Path


# Wikipedia reference used for TI-84 Plus CE character set:
# https://en.wikipedia.org/wiki/TI_calculator_character_sets
#
# IMPORTANT:
# - Where small-font and large-font glyphs differ, the large-font glyph is used.
# - Code points without a Unicode-equivalent glyph are intentionally omitted.


def _build_ti84_plus_ce_rows():
    """Return row-wise TI-84 Plus CE mapping table (0x00-0xFF).

    Each row contains 16 entries and may use None for omitted code points.
    """
    return {
        0x00: [
            None, "𝘯", "u", "v", "w", "▶", "⬆", "⬇", "∫", "×", "▫", "˖", "·", "ᴛ", "³", "𝗙"
        ],
        0x10: [
            "√", "⁻¹", "²", "∠", "°", "ʳ", "ᵀ", "≤", "≠", "≥", "˗", "ᴇ", "→", "⏨", "↑", "↓"
        ],
        0x20: [
            " ", "!", '"', "#", "⁴", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/"
        ],
        0x30: [
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?"
        ],
        0x40: [
            "@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"
        ],
        0x50: [
            "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "θ", "\\", "]", "^", "_"
        ],
        0x60: [
            "`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o"
        ],
        0x70: [
            "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "{", "|", "}", "~", "="
        ],
        0x80: [
            "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉", "Á", "À", "Â", "Ä", "á", "à"
        ],
        0x90: [
            "â", "ä", "É", "È", "Ê", "Ë", "é", "è", "ê", "ë", "Í", "Ì", "Î", "Ï", "í", "ì"
        ],
        0xA0: [
            "î", "ï", "Ó", "Ò", "Ô", "Ö", "ó", "ò", "ô", "ö", "Ú", "Ù", "Û", "Ü", "ú", "ù"
        ],
        0xB0: [
            "û", "ü", "Ç", "ç", "Ñ", "ñ", "´", "`", "¨", "¿", "¡", "α", "β", "γ", "Δ", "δ"
        ],
        0xC0: [
            "ε", "[", "λ", "μ", "π", "ρ", "Σ", "σ", "τ", "φ", "Ω", "x̅", "y̅", "˟", "…", "◀"
        ],
        0xD0: [
            "■", "∕", "‐", "²", "°", "³", None, "𝑖", "P̂", "χ", "𝙵", "𝑒", "ʟ", "𝗡", "⸩", "➧"
        ],
        0xE0: [
            "█", "⇧", "🅰", "🅰", "_", "↥", "A̲", "a̲", None, None, "◥", "◣", None, None, None, "⬆"
        ],
        0xF0: [
            "⬇", "▒", "$", "⬆", "ß", "␣", "⁄", "⬚", None, "▪", None, None, None, None, None, None
        ],
    }


OMITTED_CODEPOINT_NOTES = {
    0x00: "No documented displayable glyph in the TI-84 Plus CE table.",
    0xD6: "LF token/control marker, not a printable single Unicode glyph.",
    0xE8: "LINE graph style token, not a character.",
    0xE9: "THICK LINE graph style token, not a character.",
    0xEC: "GRAPH PATH token, not a character.",
    0xED: "GRAPH ANIMATE token, not a character.",
    0xEE: "GRAPH DOT token, not a character.",
    0xF8: "THICK GRAPH DOT token, no clear single-character Unicode equivalent.",
    0xFA: "Undocumented/blank in TI-84 Plus CE table.",
    0xFB: "Undocumented/blank in TI-84 Plus CE table.",
    0xFC: "Undocumented/blank in TI-84 Plus CE table.",
    0xFD: "Undocumented/blank in TI-84 Plus CE table.",
    0xFE: "Undocumented/blank in TI-84 Plus CE table.",
    0xFF: "Undocumented/blank in TI-84 Plus CE table.",
}


def _build_ti84_plus_ce_mapping():
    rows = _build_ti84_plus_ce_rows()
    mapping = {}

    for row_base in range(0x00, 0x100, 0x10):
        row = rows[row_base]
        for low_nibble, glyph in enumerate(row):
            codepoint = row_base + low_nibble
            if glyph is None:
                continue
            mapping[f"0x{codepoint:02X}"] = glyph

    # Large/small discrepancy note:
    # 0xDF is ᴇ in the small font table and ➧ in the large font table.
    # We prefer the large font glyph (➧), per project requirement.
    return mapping


def _build_all_ascii_mapping():
    """Map printable ASCII chars to their TI-84 Plus CE code points.

    This encoding includes all printable ASCII characters (0x20-0x7E), but uses
    TI-native placements where they differ from ASCII indexing:
      - '$' is at 0xF2 (0x24 is superscript four)
      - '[' is at 0xC1 (0x5B is theta)
    """
    mapping = {}
    for codepoint in range(0x20, 0x7F):
        character = chr(codepoint)
        if character == "$":
            ti_codepoint = 0xF2
        elif character == "[":
            ti_codepoint = 0xC1
        else:
            ti_codepoint = codepoint

        mapping[f"0x{ti_codepoint:02X}"] = character

    return mapping


def _build_alphanumeric_mapping():
    all_ascii = _build_all_ascii_mapping()
    return {
        codepoint: character
        for codepoint, character in all_ascii.items()
        if character.isalnum()
    }


def generate_encodings():
    ti84_full = _build_ti84_plus_ce_mapping()
    all_ascii = _build_all_ascii_mapping()
    alphanumeric = _build_alphanumeric_mapping()

    return {
        "Alphanumeric characters only": alphanumeric,
        "All ASCII characters": all_ascii,
        "TI-84 Plus CE character set": ti84_full,
        "Custom": dict(ti84_full),
    }


def main():
    encodings = generate_encodings()
    output_path = Path(__file__).with_name("encodings.json")

    with output_path.open("w", encoding="utf-8") as output_file:
        json.dump(encodings, output_file, indent=4, ensure_ascii=False)
        output_file.write("\n")

    print(f"Wrote {output_path}")
    print(f"Omitted {len(OMITTED_CODEPOINT_NOTES)} TI code points with no Unicode equivalent.")
    for codepoint, reason in sorted(OMITTED_CODEPOINT_NOTES.items()):
        print(f"  0x{codepoint:02X}: {reason}")


if __name__ == "__main__":
    main()






