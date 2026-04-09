// Text formatting helper functions

export const capitalizeName = name => {
  if (!name) {
    return name;
  }
  return name
    .split(" ")
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
};

// Get today's date in local time formatted as YYYY-MM-DD (for HTML date input max/min)
export const getLocalDateString = () => {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};
