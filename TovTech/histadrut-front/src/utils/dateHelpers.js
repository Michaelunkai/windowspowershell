export const getRelativeDays = (postedDate, currentLanguage, labelToday) => {
  if (!postedDate) {
    return "";
  }

  const parsePostedDate = value => {
    if (typeof value !== "string") {
      return new Date(value);
    }

    const trimmed = value.trim();
    const ddmmyyyy = /^(\d{2})\/(\d{2})\/(\d{4})$/;
    const match = trimmed.match(ddmmyyyy);
    if (match) {
      const day = Number(match[1]);
      const month = Number(match[2]) - 1;
      const year = Number(match[3]);
      return new Date(year, month, day);
    }

    return new Date(trimmed);
  };

  const date = parsePostedDate(postedDate);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const now = new Date();
  const diffMs = date - now;

  const absoluteSeconds = Math.round(diffMs / 1000);

  // Define units in descending order
  const units = [
    ["year", 60 * 60 * 24 * 365],
    ["month", 60 * 60 * 24 * 30],
    ["week", 60 * 60 * 24 * 7],
    ["day", 60 * 60 * 24],
    ["hour", 60 * 60],
    ["minute", 60],
    ["second", 1]
  ];

  const rtf = new Intl.RelativeTimeFormat(currentLanguage, { numeric: "auto" });

  for (const [unit, unitSeconds] of units) {
    const value = Math.trunc(absoluteSeconds / unitSeconds);
    if (value !== 0) {
      return rtf.format(value, unit);
    }
  }

  return labelToday;
};
