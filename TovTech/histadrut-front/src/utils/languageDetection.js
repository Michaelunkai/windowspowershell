/**
 * Language detection utility for Hebrew and English text
 */

// Hebrew Unicode ranges
const HEBREW_RANGES = [
  [0x0590, 0x05ff], // Hebrew block
  [0xfb1d, 0xfb4f] // Hebrew presentation forms
];

// Check if a character is Hebrew
const isHebrewChar = char => {
  const code = char.charCodeAt(0);
  return HEBREW_RANGES.some(([start, end]) => code >= start && code <= end);
};

// Check if a character is English (Latin)
const isEnglishChar = char => {
  const code = char.charCodeAt(0);
  return (
    (code >= 0x0041 && code <= 0x005a) || (code >= 0x0061 && code <= 0x007a)
  );
};

/**
 * Detect the primary language of a text string
 * @param {string} text - The text to analyze
 * @returns {string} - 'hebrew', 'english', or 'mixed'
 */
const detectLanguage = text => {
  if (!text || typeof text !== "string") {
    return "english";
  }

  let hebrewCount = 0;
  let englishCount = 0;
  let totalLetters = 0;

  // Count Hebrew and English characters
  for (let i = 0; i < text.length; i++) {
    const char = text[i];

    if (isHebrewChar(char)) {
      hebrewCount++;
      totalLetters++;
    } else if (isEnglishChar(char)) {
      englishCount++;
      totalLetters++;
    }
  }

  // If no letters found, default to English
  if (totalLetters === 0) {
    return "english";
  }

  // Calculate percentages
  const hebrewPercentage = (hebrewCount / totalLetters) * 100;
  const englishPercentage = (englishCount / totalLetters) * 100;

  // Determine primary language with lower threshold for Hebrew detection
  if (hebrewPercentage > 20 && hebrewPercentage >= englishPercentage) {
    return "hebrew";
  } else if (englishPercentage > 20 && englishPercentage > hebrewPercentage) {
    return "english";
  } else {
    // For mixed content, if there's any Hebrew, treat as Hebrew for proper RTL display
    return hebrewCount > 0 ? "hebrew" : "english";
  }
};

/**
 * Get text direction based on detected language
 * @param {string} text - The text to analyze
 * @returns {string} - 'rtl' for Hebrew, 'ltr' for English/mixed
 */
export const getTextDirection = text => {
  const language = detectLanguage(text);
  return language === "hebrew" ? "rtl" : "ltr";
};

/**
 * Get text alignment based on detected language
 * @param {string} text - The text to analyze
 * @returns {string} - 'right' for Hebrew, 'left' for English/mixed
 */
export const getTextAlignment = text => {
  const language = detectLanguage(text);
  return language === "hebrew" ? "right" : "left";
};
