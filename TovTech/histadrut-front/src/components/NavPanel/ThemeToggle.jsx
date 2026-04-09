import { Sun, Moon, Monitor } from "lucide-react";
import React from "react";

import { useTheme } from "../../contexts/ThemeContext";
import { useTranslations } from "../../utils/translations";
import "./ThemeToggle.css";

const THEMES = [
  { key: "light", Icon: Sun },
  { key: "dark", Icon: Moon },
  { key: "auto", Icon: Monitor }
];

const ThemeToggle = ({ isExpanded }) => {
  const { theme, setTheme } = useTheme();
  const { t } = useTranslations("navigation");

  if (!isExpanded) {
    const activeIndex = THEMES.findIndex(item => item.key === theme);
    const { Icon } = THEMES[activeIndex >= 0 ? activeIndex : 2];
    const nextTheme = THEMES[(activeIndex + 1) % THEMES.length].key;

    return (
      <button
        className="theme-toggle__cycle-btn"
        onClick={() => setTheme(nextTheme)}
        title={t(`theme_${theme}`)}
        aria-label={t(`theme_${theme}`)}
      >
        <Icon className="theme-toggle__cycle-icon" />
      </button>
    );
  }

  return (
    <div className="theme-toggle" role="group" aria-label={t("themeLabel")}>
      {THEMES.map(item => (
        <button
          key={item.key}
          className={`theme-toggle__btn ${theme === item.key ? "theme-toggle__btn--active" : ""}`}
          onClick={() => setTheme(item.key)}
          aria-pressed={theme === item.key}
          aria-label={t(`theme_${item.key}`)}
        >
          <item.Icon className="theme-toggle__btn-icon" />
          <span className="theme-toggle__btn-label">{t(`theme_${item.key}`)}</span>
        </button>
      ))}
    </div>
  );
};

export default ThemeToggle;
