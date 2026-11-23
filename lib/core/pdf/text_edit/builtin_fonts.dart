/// DocSafe's fallback fonts (assets/pdf_fonts, built by
/// tool/fonts/build_pdf_fonts.py): Latin subsets of Liberation 2, Carlito and
/// Caladea, renamed as the SIL OFL requires for modified fonts.
const builtInPdfFonts = <String, List<String>>{
  // asset file name -> normalised families it copies glyph-for-glyph
  'ScannerProSans-Regular.ttf': ['liberationsans', 'arimo'],
  'ScannerProSans-Bold.ttf': ['liberationsans', 'arimo'],
  'ScannerProSans-Italic.ttf': ['liberationsans', 'arimo'],
  'ScannerProSans-BoldItalic.ttf': ['liberationsans', 'arimo'],
  'ScannerProSerif-Regular.ttf': ['liberationserif', 'tinos'],
  'ScannerProSerif-Bold.ttf': ['liberationserif', 'tinos'],
  'ScannerProSerif-Italic.ttf': ['liberationserif', 'tinos'],
  'ScannerProSerif-BoldItalic.ttf': ['liberationserif', 'tinos'],
  'ScannerProMono-Regular.ttf': ['liberationmono', 'cousine'],
  'ScannerProMono-Bold.ttf': ['liberationmono', 'cousine'],
  'ScannerProOfficeSans-Regular.ttf': ['carlito'],
  'ScannerProOfficeSans-Bold.ttf': ['carlito'],
  'ScannerProOfficeSans-Italic.ttf': ['carlito'],
  'ScannerProOfficeSans-BoldItalic.ttf': ['carlito'],
  'ScannerProOfficeSerif-Regular.ttf': ['caladea'],
  'ScannerProOfficeSerif-Bold.ttf': ['caladea'],
  'ScannerProOfficeSerif-Italic.ttf': ['caladea'],
  'ScannerProOfficeSerif-BoldItalic.ttf': ['caladea'],
};
