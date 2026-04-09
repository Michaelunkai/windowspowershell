import React, { createContext, useContext, useEffect, useLayoutEffect, useReducer, useState } from "react";

const themeReducer = (state, action) => {
  switch (action.type) {
    case "SET_THEME": {
      try {
        localStorage.setItem("selectedTheme", action.payload);
      } catch (error) {
        console.warn("Could not save theme to localStorage:", error);
      }
      return { ...state, theme: action.payload };
    }
    default:
      return state;
  }
};

const getInitialTheme = () => {
  try {
    const saved = localStorage.getItem("selectedTheme");
    if (saved && ["light", "dark", "auto"].includes(saved)) {
      return saved;
    }
  } catch (_e) {
    // ignore
  }
  return "auto";
};

const ThemeContext = createContext();

export const ThemeProvider = ({ children }) => {
  const [state, dispatch] = useReducer(themeReducer, undefined, () => ({ theme: getInitialTheme() }));

  const [systemDark, setSystemDark] = useState(
    () => typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches
  );

  // Subscribe to OS color scheme changes so auto mode stays reactive
  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = e => setSystemDark(e.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  const isDark =
    state.theme === "dark" || (state.theme === "auto" && systemDark);

  const setTheme = newTheme => {
    if (["light", "dark", "auto"].includes(newTheme)) {
      dispatch({ type: "SET_THEME", payload: newTheme });
    }
  };

  useLayoutEffect(() => {
    if (typeof document === "undefined") return;
    const root = document.documentElement;
    if (state.theme === "auto") {
      root.removeAttribute("data-theme");
    } else {
      root.setAttribute("data-theme", state.theme);
    }
  }, [state.theme]);

  return (
    <ThemeContext.Provider value={{ theme: state.theme, setTheme, isDark }}>
      {children}
    </ThemeContext.Provider>
  );
};

// eslint-disable-next-line react-refresh/only-export-components
export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
};
