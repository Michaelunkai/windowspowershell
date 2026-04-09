// Debounce timeouts
export const DEBOUNCE_TIMEOUT = 500; // Standard debounce for text inputs
export const REGIONS_DEBOUNCE_TIMEOUT = 1000; // Longer debounce for multi-select

// Pagination defaults
export const DEFAULT_PAGE_SIZE = 20;

// Relevance score defaults
export const DEFAULT_MIN_RELEVANCE_SCORE = 8.5;

// Age category thresholds (in days)
export const AGE_THRESHOLDS = {
  NEW: 1,
  FRESH: 5,
  STALE: 14
};

// Age categories for filtering
export const AGE_CATEGORIES = {
  ALL: "All Statuses",
  ONE_DAY: "1 day",
  TWO_TO_FIVE: "2-5 days",
  SIX_TO_FOURTEEN: "6-14 days",
  FIFTEEN_PLUS: "15+ days"
};

// Sorting directions
export const SORT_DIRECTION = {
  ASC: "asc",
  DESC: "desc"
};

// Session timeout settings
export const SESSION_EXPIRED_COUNTDOWN = 5; // seconds before redirect

// Region dictionary for localization
const REGIONS = {
  NORTH: "North",
  CENTER: "Center",
  SOUTH: "South",
  JERUSALEM: "Jerusalem"
};

// Hebrew region translations
const REGIONS_HE = {
  NORTH: "צפון",
  CENTER: "מרכז",
  SOUTH: "דרום",
  JERUSALEM: "ירושלים"
};

// Combined region dictionary for easy lookup
export const REGIONS_DICTIONARY = {
  [REGIONS.NORTH]: REGIONS_HE.NORTH,
  [REGIONS.CENTER]: REGIONS_HE.CENTER,
  [REGIONS.SOUTH]: REGIONS_HE.SOUTH,
  [REGIONS.JERUSALEM]: REGIONS_HE.JERUSALEM
};

// Fallback region list used when the server is unavailable
export const FALLBACK_REGIONS = Object.values(REGIONS);
