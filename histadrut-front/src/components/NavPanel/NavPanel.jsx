import { LayoutDashboard, Briefcase, ClipboardList, Users, ClipboardCheck, BarChart3, CircleUser } from "lucide-react";
import React, { useState, useEffect } from "react";
import { NavLink, useNavigate } from "react-router-dom";

import { backendLogout } from "../../api";
import { useLanguage } from "../../contexts/LanguageContext";
import { useViewport } from "../../contexts/ViewportContext";
import { useAuth } from "../../hooks/useAuth";
import { capitalizeName } from "../../utils/textHelpers";
import { useTranslations } from "../../utils/translations";
import "./NavPanel.css";

const NavPanel = () => {
  const { logout, user, isAdminOrDemo } = useAuth();
  const navigate = useNavigate();
  const { t } = useTranslations("navigation");
  const { currentLanguage } = useLanguage();
  const { isMobile } = useViewport();
  const [isMobileExpanded, setIsMobileExpanded] = useState(false);
  const [isDesktopExpanded, setIsDesktopExpanded] = useState(false);
  const isRtl = currentLanguage === "he";
  const isExpanded = isMobile ? isMobileExpanded : isDesktopExpanded;

  const isAdmin = isAdminOrDemo();

  // Reset both drawer states when crossing the mobile/desktop breakpoint
  useEffect(() => {
    setIsMobileExpanded(false);
    setIsDesktopExpanded(false);
  }, [isMobile]);

  const handleToggleExpansion = () => {
    if (isMobile) {
      setIsMobileExpanded(expanded => !expanded);
    } else {
      setIsDesktopExpanded(expanded => !expanded);
    }
  };

  const handleLogout = async () => {
    try {
      await backendLogout();
    } catch {
      // Ignore backend logout errors, still proceed with frontend logout
    }
    logout();
    navigate("/login");
  };

  return (
    <>
      {/* Mobile hamburger button when nav is closed */}
      {isMobile && !isExpanded && (
        <button
          className="nav-panel__mobile-toggle"
          onClick={handleToggleExpansion}
          aria-label={t("openNav")}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M3 12H21M3 6H21M3 18H21" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
          </svg>
        </button>
      )}

      {/* Mobile overlay */}
      {isMobile && isExpanded && (
        <div
          className="nav-overlay nav-overlay--visible"
          onClick={() => setIsMobileExpanded(false)}
        />
      )}

      <aside
        className={`nav-panel ${isExpanded ? "nav-panel--expanded" : "nav-panel--collapsed"} ${isMobile ? "nav-panel--mobile" : "nav-panel--desktop"}`}
        role="navigation"
        aria-label="Main navigation"
      >
        <div className={`nav-panel__header ${!isExpanded ? "nav-panel__header--collapsed" : ""}`}>
          <div className="nav-panel__header-text">
            <h2 className="nav-panel__title">{t("title")}</h2>
            <p className="nav-panel__user">{t("welcome")}, {capitalizeName(user?.name)}</p>
          </div>
          <button
            className="nav-panel__toggle"
            onClick={handleToggleExpansion}
            aria-label={isExpanded ? t("collapseNav") : t("expandNav")}
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <path d="M3 7H17M3 13H17" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
            </svg>
          </button>
        </div>
        <nav className="nav-panel__nav" aria-label="Main navigation">
          <ul className="nav-panel__list">
            {isAdmin ? (
              <>
                <li className="nav-panel__item">
                  <NavLink
                    to="/overview"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("overview") : undefined}
                  >
                    <LayoutDashboard className="nav-panel__icon" aria-label="Overview Dashboard" />
                    {isExpanded && <span className="nav-panel__text">{t("overview")}</span>}
                  </NavLink>
                </li>
                <li className="nav-panel__item">
                  <NavLink
                    to="/admin/users"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("users") : undefined}
                  >
                    <Users className="nav-panel__icon" aria-label="Users" />
                    {isExpanded && <span className="nav-panel__text">{t("users")}</span>}
                  </NavLink>
                </li>
                <li className="nav-panel__item">
                  <NavLink
                    to="/jobs-listings"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("jobsListings") : undefined}
                  >
                    <Briefcase className="nav-panel__icon" aria-label="Jobs Listings" />
                    {isExpanded && <span className="nav-panel__text">{t("jobsListings")}</span>}
                  </NavLink>
                </li>
                <li className="nav-panel__item">
                  <NavLink
                    to="/admin/matches"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("jobMatches") : undefined}
                  >
                    <ClipboardCheck className="nav-panel__icon" aria-label="Job Matches" />
                    {isExpanded && <span className="nav-panel__text">{t("jobMatches")}</span>}
                  </NavLink>
                </li>
                <li className="nav-panel__item">
                  <NavLink
                    to="/companies"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("companies") : undefined}
                  >
                    <ClipboardList className="nav-panel__icon" aria-label="Companies" />
                    {isExpanded && <span className="nav-panel__text">{t("companies")}</span>}
                  </NavLink>
                </li>
                <li className="nav-panel__item">
                  <NavLink
                    to="/reporting"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("reporting") : undefined}
                  >
                    <BarChart3 className="nav-panel__icon" aria-label="Reporting" />
                    {isExpanded && <span className="nav-panel__text">{t("reporting")}</span>}
                  </NavLink>
                </li>
              </>
            ) : (
              <>
                <li className="nav-panel__item">
                  <NavLink
                    to="/jobs-listings"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("jobsListings") : undefined}
                  >
                    <Briefcase className="nav-panel__icon" aria-label="Jobs Listings" />
                    {isExpanded && <span className="nav-panel__text">{t("jobsListings")}</span>}
                  </NavLink>
                </li>
                <li className="nav-panel__item">
                  <NavLink
                    to="/user/matches"
                    className={({ isActive }) =>
                      `nav-panel__link ${isActive ? "nav-panel__link--active" : ""}`
                    }
                    title={!isExpanded ? t("jobMatches") : undefined}
                  >
                    <ClipboardCheck className="nav-panel__icon" aria-label="Job Matches" />
                    {isExpanded && <span className="nav-panel__text">{t("jobMatches")}</span>}
                  </NavLink>
                </li>
              </>
            )}
          </ul>
        </nav>

        <div className={`nav-panel__footer ${!isExpanded ? "nav-panel__footer--collapsed" : ""}`}>
          <NavLink
            to="/profile"
            className={({ isActive }) =>
              `nav-panel__link nav-panel__profile-link ${
                isActive ? "nav-panel__link--active" : ""
              }`
            }
            title={!isExpanded ? t("profile") : undefined}
            style={{ display: "flex", alignItems: "center", marginBottom: isExpanded ? 12 : 8 }}
          >
            <CircleUser className="nav-panel__icon" aria-label="Profile" />
            {isExpanded && <span className="nav-panel__text">{t("profile")}</span>}
          </NavLink>

          <button
            onClick={handleLogout}
            className={`nav-panel__logout ${!isExpanded && !isMobile ? "nav-panel__logout--icon" : ""}`}
            title={!isExpanded ? t("logout") : undefined}
            aria-label={t("logout")}
          >
            {(!isExpanded && !isMobile) ? (
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" className="nav-panel__logout-icon">
                <path d="M9 17H5C3.89543 17 3 16.1046 3 15V5C3 3.89543 3.89543 3 5 3H9M15 13L17 11M17 11L15 9M17 11H9" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            ) : null}
            <span className={`nav-panel__text ${!isExpanded && !isMobile ? "nav-panel__logout-text--hidden" : ""}`}>
              {t("logout")}
            </span>
          </button>
        </div>
      </aside>
    </>
  );
};

export default NavPanel;
