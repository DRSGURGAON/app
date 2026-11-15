/// DocSafe's fallback fonts (assets/pdf_fonts, built by
/// tool/fonts/build_pdf_fonts.py): Latin subsets of Liberation 2, Carlito and
/// Caladea, renamed as the SIL OFL requires for modified fonts.
const builtInPdfFonts = <String, List<String>>{
  // asset file name -> normalised families it copies glyph-for-glyph
  'DocSafeSans-Regular.ttf': ['liberationsans', 'arimo'],
  'DocSafeSans-Bold.ttf': ['liberationsans', 'arimo'],
  'DocSafeSans-Italic.ttf': ['liberationsans', 'arimo'],
  'DocSafeSans-BoldItalic.ttf': ['liberationsans', 'arimo'],
  'DocSafeSerif-Regular.ttf': ['liberationserif', 'tinos'],
  'DocSafeSerif-Bold.ttf': ['liberationserif', 'tinos'],
  'DocSafeSerif-Italic.ttf': ['liberationserif', 'tinos'],
  'DocSafeSerif-BoldItalic.ttf': ['liberationserif', 'tinos'],
  'DocSafeMono-Regular.ttf': ['liberationmono', 'cousine'],
  'DocSafeMono-Bold.ttf': ['liberationmono', 'cousine'],
  'DocSafeOfficeSans-Regular.ttf': ['carlito'],
  'DocSafeOfficeSans-Bold.ttf': ['carlito'],
  'DocSafeOfficeSans-Italic.ttf': ['carlito'],
  'DocSafeOfficeSans-BoldItalic.ttf': ['carlito'],
  'DocSafeOfficeSerif-Regular.ttf': ['caladea'],
  'DocSafeOfficeSerif-Bold.ttf': ['caladea'],
  'DocSafeOfficeSerif-Italic.ttf': ['caladea'],
  'DocSafeOfficeSerif-BoldItalic.ttf': ['caladea'],
};
