import React, { createContext, useContext, useLayoutEffect, useReducer } from "react";

// Language reducer
const languageReducer = (state, action) => {
  switch (action.type) {
    case "SET_LANGUAGE":
      // Save to localStorage when language changes
      try {
        localStorage.setItem("selectedLanguage", action.payload);
      } catch (error) {
        console.warn("Could not save language to localStorage:", error);
      }
      return {
        ...state,
        currentLanguage: action.payload
      };
    case "TOGGLE_LANGUAGE": {
      const newLanguage = state.currentLanguage === "en" ? "he" : "en";
      // Save to localStorage when language toggles
      try {
        localStorage.setItem("selectedLanguage", newLanguage);
      } catch (error) {
        console.warn("Could not save language to localStorage:", error);
      }
      return {
        ...state,
        currentLanguage: newLanguage
      };
    }
    default:
      return state;
  }
};

// Detect browser language from navigator.language
const getBrowserLanguage = () => {
  try {
    const { language } = navigator;
    if (!language) {
      return null;
    }

    // Extract language code (e.g., 'he-IL' -> 'he')
    const langCode = language.split("-")[0].toLowerCase();
    return ["en", "he"].includes(langCode) ? langCode : null;
  } catch (error) {
    console.warn("Could not detect browser language:", error);
    return null;
  }
};

// Initial state - check localStorage first, then browser language, fallback to 'en'
const getInitialLanguage = () => {
  // Check localStorage first
  let saved = null;
  try {
    saved = localStorage.getItem("selectedLanguage");
  } catch (error) {
    console.warn("Could not access localStorage:", error);
  }

  if (saved && ["en", "he"].includes(saved)) {
    return saved;
  }

  // Try browser language detection
  const browserLang = getBrowserLanguage();
  if (browserLang) {
    return browserLang;
  }

  // Default fallback
  return "en";
};

const initialState = {
  currentLanguage: getInitialLanguage(),
  supportedLanguages: ["en", "he"]
};

// Create context
const LanguageContext = createContext();

// Language provider component
export const LanguageProvider = ({ children }) => {
  const [state, dispatch] = useReducer(languageReducer, initialState);

  const setLanguage = language => {
    if (state.supportedLanguages.includes(language)) {
      dispatch({ type: "SET_LANGUAGE", payload: language });
    }
  };

  const toggleLanguage = () => {
    dispatch({ type: "TOGGLE_LANGUAGE" });
  };

  useLayoutEffect(() => {
    if (typeof document !== "undefined") {
      document.documentElement.dir = state.currentLanguage === "he" ? "rtl" : "ltr";
    }
  }, [state.currentLanguage]);

  const value = {
    ...state,
    setLanguage,
    toggleLanguage
  };

  return (
    <LanguageContext.Provider value={value}>
      {children}
    </LanguageContext.Provider>
  );
};

// Custom hook - exported as a function (not a component)
// eslint-disable-next-line react-refresh/only-export-components
export const useLanguage = () => {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error("useLanguage must be used within a LanguageProvider");
  }
  return context;
};
