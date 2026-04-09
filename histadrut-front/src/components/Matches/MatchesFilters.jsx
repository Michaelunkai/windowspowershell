import React, { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";

import { fetchCompanies, fetchRegions } from "../../api";
import { useAuth } from "../../hooks/useAuth";
import { useDebounce } from "../../hooks/useDebounce";
import {
  DEBOUNCE_TIMEOUT,
  REGIONS_DEBOUNCE_TIMEOUT,
  DEFAULT_MIN_RELEVANCE_SCORE,
  FALLBACK_REGIONS,
  REGIONS_DICTIONARY
} from "../../utils/constants";
import { getLocalDateString } from "../../utils/textHelpers";
import { useTranslations } from "../../utils/translations";
import CompanyAutocompleteInput from "../shared/CompanyAutocompleteInput";
import RegionsMultiSelect from "../shared/RegionsMultiSelect";

const MatchesFilters = () => {
  const { isAdmin } = useAuth();
  const isAdminUser = typeof isAdmin === "function" ? isAdmin() : isAdmin;
  const { t, currentLanguage } = useTranslations("matches");
  const [searchParams, setSearchParams] = useSearchParams();
  const [isFiltersVisible, setIsFiltersVisible] = useState(true);
  const [isFiltersOpen, setIsFiltersOpen] = useState(false);
  // Prefer snake_case URL key `company_name` but fallback to legacy `companyName`
  const [localCompanyName, setLocalCompanyName] = useState(
    searchParams.get("company_name") || searchParams.get("companyName") || ""
  );
  const [companyOptions, setCompanyOptions] = useState([]);
  const [regionOptions, setRegionOptions] = useState([]);
  // No longer need showCompanyDropdown, handled by shared component
  const [localOpenSearch, setLocalOpenSearch] = useState(searchParams.get("openSearch") || "");
  const [localJobTitle, setLocalJobTitle] = useState(searchParams.get("job_title") || "");
  const [localCandidateName, setLocalCandidateName] = useState(searchParams.get("candidateName") || "");
  const [localJobId, setLocalJobId] = useState(searchParams.get("job_id") || "");
  const [localAppliedStatus, setLocalAppliedStatus] = useState(searchParams.get("match_status") || "");
  const [localRegion, setLocalRegion] = useState(searchParams.get("regions") || searchParams.get("region") || searchParams.get("locations") || "");
  const [localMmr, setLocalMmr] = useState(searchParams.get("mmr") || "");
  const addedSince = searchParams.get("addedSince") || "";
  const minRelevanceScore = searchParams.get("minRelevanceScore") ? parseFloat(searchParams.get("minRelevanceScore")) : DEFAULT_MIN_RELEVANCE_SCORE;
  const [localMinScore, setLocalMinScore] = useState(minRelevanceScore);

  // Fetch company and region options on mount
  useEffect(() => {
    fetchCompanies().then(data => {
      if (data && typeof data === "object") {
        setCompanyOptions(Object.keys(data));
      }
    });

    fetchRegions().then(data => {
      setRegionOptions(data && Array.isArray(data) && data.length > 0 ? data : FALLBACK_REGIONS);
    });
  }, []);

  // Sync all local state with URL params if they change externally
  useEffect(() => {
    setLocalCompanyName(searchParams.get("company_name") || searchParams.get("companyName") || "");
    setLocalOpenSearch(searchParams.get("openSearch") || "");
    setLocalJobTitle(searchParams.get("job_title") || "");
    setLocalCandidateName(searchParams.get("candidateName") || "");
    setLocalJobId(searchParams.get("job_id") || "");
    setLocalAppliedStatus(searchParams.get("match_status") || "");
    setLocalRegion(searchParams.get("regions") || searchParams.get("region") || searchParams.get("locations") || "");
    setLocalMmr(searchParams.get("mmr") || "");
  }, [searchParams]);

  // Debounced update for each input
  const debouncedSetParam = useDebounce((field, value) => {
    setSearchParams(prev => {
      const params = new URLSearchParams(prev);
      if (value && value !== "") {
        params.set(field, value);
      } else {
        params.delete(field);
      }
      // Remove all empty params
      for (const key of Array.from(params.keys())) {
        if (!params.get(key)) {
          params.delete(key);
        }
      }
      // Always reset page to 1 on filter change
      params.set("page", "1");
      return params;
    });
  }, DEBOUNCE_TIMEOUT);

  // Longer debounce for locations multi-select
  const debouncedSetLocationsParam = useDebounce((field, value) => {
    setSearchParams(prev => {
      const params = new URLSearchParams(prev);
      if (value && value !== "") {
        params.set(field, value);
      } else {
        params.delete(field);
      }
      // Remove all empty params
      for (const key of Array.from(params.keys())) {
        if (!params.get(key)) {
          params.delete(key);
        }
      }
      // Always reset page to 1 on filter change
      params.set("page", "1");
      return params;
    });
  }, REGIONS_DEBOUNCE_TIMEOUT);

  const handleCompanyNameChange = company => {
    setLocalCompanyName(company);
    // Use snake_case query key for URLs
    debouncedSetParam("company_name", company);
  };
  const handleOpenSearchChange = e => {
    setLocalOpenSearch(e.target.value);
    debouncedSetParam("openSearch", e.target.value);
  };
  const handleJobTitleChange = e => {
    setLocalJobTitle(e.target.value);
    debouncedSetParam("job_title", e.target.value);
  };
  const handleCandidateNameChange = e => {
    setLocalCandidateName(e.target.value);
    debouncedSetParam("candidateName", e.target.value);
  };
  const handleJobIdChange = e => {
    setLocalJobId(e.target.value);
    debouncedSetParam("job_id", e.target.value);
  };
  const handleAppliedStatusChange = e => {
    setLocalAppliedStatus(e.target.value);
    debouncedSetParam("match_status", e.target.value);
  };
  const handleRegionChange = value => {
    setLocalRegion(value);
    debouncedSetLocationsParam("regions", value);
  };
  const handleMmrChange = e => {
    setLocalMmr(e.target.value);
    debouncedSetParam("mmr", e.target.value);
  };
  // Handle date and slider changes for addedSince and minRelevanceScore
  const handleInputChange = (field, value) => {
    if (field === "addedSince") {
      setSearchParams(prev => {
        const params = new URLSearchParams(prev);
        if (value && value !== "") {
          params.set(field, value);
        } else {
          params.delete(field);
        }
        // Remove all empty params
        for (const key of Array.from(params.keys())) {
          if (!params.get(key)) {
            params.delete(key);
          }
        }
        params.set("page", "1");
        return params;
      });
    }
    if (field === "minRelevanceScore") {
      setLocalMinScore(parseFloat(value));
    }
  };

  // Debounce updating the URL param for minRelevanceScore
  useEffect(() => {
    const handler = setTimeout(() => {
      if (localMinScore !== minRelevanceScore) {
        setSearchParams(prev => {
          const params = new URLSearchParams(prev);
          if (localMinScore !== "" && localMinScore !== null) {
            params.set("minRelevanceScore", localMinScore);
          } else {
            params.delete("minRelevanceScore");
          }
          params.set("page", "1");
          return params;
        });
      }
    }, 300);
    return () => clearTimeout(handler);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [localMinScore]);

  // Keep localMinScore in sync with URL param if it changes externally
  useEffect(() => {
    setLocalMinScore(minRelevanceScore);
  }, [minRelevanceScore]);

  // Clear individual field
  const clearField = field => {
    switch (field) {
      case "openSearch":
        setLocalOpenSearch("");
        handleInputChange("openSearch", "");
        break;
      case "companyName":
        setLocalCompanyName("");
        // Remove both legacy and new query params and reset page
        setSearchParams(prev => {
          const params = new URLSearchParams(prev);
          params.delete("company_name");
          params.delete("companyName");
          params.set("page", "1");
          return params;
        });
        break;
      case "jobTitle":
        setLocalJobTitle("");
        handleInputChange("job_title", "");
        break;
      case "candidateName":
        setLocalCandidateName("");
        handleInputChange("candidateName", "");
        break;
      case "jobId":
        setLocalJobId("");
        handleInputChange("job_id", "");
        break;
      case "appliedStatus":
        setLocalAppliedStatus("");
        handleInputChange("match_status", "");
        break;
      case "addedSince":
        handleInputChange("addedSince", "");
        break;
      case "minRelevanceScore":
        setLocalMinScore(DEFAULT_MIN_RELEVANCE_SCORE);
        handleInputChange("minRelevanceScore", DEFAULT_MIN_RELEVANCE_SCORE);
        break;
      case "region":
        setLocalRegion("");
        setSearchParams(prev => {
          const params = new URLSearchParams(prev);
          params.delete("regions");
          params.delete("region");
          params.set("page", "1");
          return params;
        });
        break;
      case "mmr":
        setLocalMmr("");
        setSearchParams(prev => {
          const params = new URLSearchParams(prev);
          params.delete("mmr");
          params.set("page", "1");
          return params;
        });
        break;
    }
  };

  // Check if any filters are active
  const hasActiveFilters = () => {
    return localOpenSearch ||
           localCompanyName ||
           localJobTitle ||
           localCandidateName ||
           localJobId ||
           localAppliedStatus ||
           localRegion ||
           localMmr ||
           localMinScore !== 8.5;
  };

  const getActiveFiltersCount = () => {
    let count = 0;
    if (localOpenSearch) {
      count++;
    }
    if (localCompanyName) {
      count++;
    }
    if (localJobTitle) {
      count++;
    }
    if (localCandidateName) {
      count++;
    }
    if (localJobId) {
      count++;
    }
    if (localAppliedStatus) {
      count++;
    }
    if (localRegion) {
      count++;
    }
    if (localMmr) {
      count++;
    }
    if (localMinScore !== 7.0) {
      count++;
    }
    return count;
  };

  // Clear all filters
  const clearAllFilters = () => {
    if (!hasActiveFilters()) {
      return;
    } // Don't clear if no filters are active

    setLocalOpenSearch("");
    setLocalCompanyName("");
    setLocalJobTitle("");
    setLocalCandidateName("");
    setLocalJobId("");
    setLocalAppliedStatus("");
    setLocalRegion("");
    setLocalMmr("");
    setLocalMinScore(7.0);

    setSearchParams(new URLSearchParams({ page: "1" }));
  };

  const activeCount = getActiveFiltersCount();

  return (
    <section
      className={`match-filters ${isFiltersOpen ? "match-filters--open" : ""}`}
      aria-label={t("filters.title")}
      key={currentLanguage}
    >
      {/* Mobile-only toggle button — hidden on desktop via CSS */}
      <button
        className="matches-filters-mobile__toggle"
        onClick={() => setIsFiltersOpen(o => !o)}
      >
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M2 4h16M5 10h10M8 16h4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
        <span>{t("filtersTitle")}</span>
        {activeCount > 0 && (
          <span className="matches-filters-mobile__badge">{activeCount}</span>
        )}
      </button>

      {/* Overlay — rendered only when drawer is open */}
      {isFiltersOpen && (
        <div
          className="matches-filters-mobile__overlay"
          onClick={() => setIsFiltersOpen(false)}
        />
      )}

      {/* The panel — inline on desktop, drawer on mobile */}
      <div className="match-filters__panel">
        {/* Unified header — collapse toggle on desktop, close button on mobile */}
        <div className="match-filters__header">
          <h2 className="match-filters__title">
            {t("filtersTitle")}
            {activeCount > 0 && (
              <span className="match-filters__badge">{activeCount}</span>
            )}
          </h2>
          <button
            className="match-filters__toggle"
            onClick={() => setIsFiltersVisible(!isFiltersVisible)}
            aria-expanded={isFiltersVisible}
            aria-controls="filters-form"
            title={isFiltersVisible ? t("hideFilters") : t("showFilters")}
          >
            <span className={`match-filters__toggle-icon ${isFiltersVisible ? "expanded" : ""}`}>
              <svg width="12" height="8" viewBox="0 0 12 8" fill="none">
                <path d="M1 1L6 6L11 1" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </span>
          </button>
          <button
            type="button"
            className="match-filters__close"
            onClick={() => setIsFiltersOpen(false)}
            aria-label={t("filters.close") || "Close filters"}
          >
            ×
          </button>
        </div>

        {/* Filter fields — shared for both desktop and mobile */}
        <form
          id="filters-form"
          className={`match-filters__form ${isFiltersVisible ? "visible" : "hidden"}`}
          role="search"
          aria-label="Filter jobs"
          onSubmit={e => e.preventDefault()}
        >
          <div className="match-filters__grid">
            <div className="match-filters__field">
              <label className="match-filters__label" htmlFor="openSearch">
                {t("filters.openSearch")}
              </label>
              <div className="match-filters__input-container">
                <input
                  id="openSearch"
                  type="text"
                  className="match-filters__input"
                  placeholder={t("filters.openSearchPlaceholder")}
                  value={localOpenSearch}
                  onChange={handleOpenSearchChange}
                />
                {localCompanyName && (
                  <button
                    type="button"
                    className="match-filters__clear"
                    onClick={() => clearField("companyName")}
                    title={t("filters.clear")}
                  >
                    &times;
                  </button>
                )}
              </div>
            </div>

            <div className="match-filters__field">
              <CompanyAutocompleteInput
                value={localCompanyName}
                onChange={handleCompanyNameChange}
                options={companyOptions}
                label={t("filters.companyName")}
                placeholder={t("filters.companyNamePlaceholder")}
                inputId="companyName"
                className=""
                filterType="match"
              />
            </div>

            <div className="match-filters__field">
              <label className="match-filters__label" htmlFor="jobTitle">
                {t("filters.jobTitle")}
              </label>
              <div className="match-filters__input-container">
                <input
                  id="jobTitle"
                  type="text"
                  className="match-filters__input"
                  placeholder={t("filters.jobTitlePlaceholder")}
                  value={localJobTitle}
                  onChange={handleJobTitleChange}
                />
                {localJobTitle && (
                  <button
                    type="button"
                    className="match-filters__clear"
                    onClick={() => clearField("jobTitle")}
                    title={t("filters.clear")}
                  >
                    &times;
                  </button>
                )}
              </div>
            </div>

            {isAdminUser && (
              <div className="match-filters__field">
                <label className="match-filters__label" htmlFor="candidateName">
                  {t("filters.candidateName")}
                </label>
                <div className="match-filters__input-container">
                  <input
                    id="candidateName"
                    type="text"
                    className="match-filters__input"
                    placeholder={t("filters.candidateNamePlaceholder")}
                    value={localCandidateName}
                    onChange={handleCandidateNameChange}
                  />
                  {isAdminUser && localCandidateName && (
                    <button
                      type="button"
                      className="match-filters__clear"
                      onClick={() => clearField("candidateName")}
                      title={t("filters.clear")}
                    >
                      &times;
                    </button>
                  )}
                </div>
              </div>
            )}

            <div className="match-filters__field">
              <label className="match-filters__label" htmlFor="jobId">
                {t("filters.jobId")}
              </label>
              <div className="match-filters__input-container">
                <input
                  id="jobId"
                  type="text"
                  className="match-filters__input"
                  placeholder={t("filters.jobIdPlaceholder")}
                  value={localJobId}
                  onChange={handleJobIdChange}
                />
                {localJobId && (
                  <button
                    type="button"
                    className="match-filters__clear"
                    onClick={() => clearField("jobId")}
                    title={t("filters.clear")}
                  >
                    &times;
                  </button>
                )}
              </div>
            </div>

            <div className="match-filters__field">
              <label className="match-filters__label" htmlFor="appliedStatus">
                {t("filters.appliedStatus")}
              </label>
              <div className="match-filters__input-container">
                <select
                  id="appliedStatus"
                  className="match-filters__input match-filters__input--select"
                  value={localAppliedStatus}
                  onChange={handleAppliedStatusChange}
                  aria-describedby="appliedStatus-help"
                >
                  <option value="">{t("filters.allStatuses")}</option>
                  <option value="pending">{t("filters.pending")}</option>
                  <option value="sent">{t("filters.sent")}</option>
                </select>
                {localAppliedStatus && (
                  <button
                    type="button"
                    className="match-filters__clear"
                    onClick={() => clearField("appliedStatus")}
                    title={t("filters.clear")}
                  >
                    &times;
                  </button>
                )}
              </div>
              <small id="appliedStatus-help" className="match-filters__help-text">
                {isAdminUser
                  ? t("filters.appliedStatusHelpAdmin")
                  : t("filters.appliedStatusHelp")
                }
              </small>
            </div>

            <div className="match-filters__field">
              <label className="match-filters__label" htmlFor="mmr">
                {t("filters.meetingMMR")}
              </label>
              <div className="match-filters__input-container">
                <select
                  id="mmr"
                  className="match-filters__input match-filters__input--select"
                  value={localMmr}
                  onChange={handleMmrChange}
                >
                  <option value="">{t("filters.allMMR")}</option>
                  <option value="true">{t("filters.positiveMMR")}</option>
                  <option value="false">{t("filters.negativeMMR")}</option>
                </select>
                {localMmr && (
                  <button
                    type="button"
                    className="match-filters__clear"
                    onClick={() => clearField("mmr")}
                    title={t("filters.clear")}
                  >
                    &times;
                  </button>
                )}
              </div>
            </div>

            <div className="match-filters__field">
              <label className="match-filters__label" htmlFor="addedSince">
                {t("filters.postedAfter")}
              </label>
              <div className="match-filters__input-container">
                <input
                  id="addedSince"
                  type="date"
                  className="match-filters__input match-filters__input--date"
                  value={addedSince}
                  max={getLocalDateString()}
                  onChange={e => handleInputChange("addedSince", e.target.value)}
                  aria-describedby="addedSince-help"
                />
                {addedSince && (
                  <button
                    type="button"
                    className="match-filters__clear"
                    onClick={() => clearField("addedSince")}
                    title={t("filters.clear")}
                  >
                    &times;
                  </button>
                )}
              </div>
              <small id="addedSince-help" className="match-filters__help-text">
                {t("filters.postedAfterHelp")}
              </small>
            </div>

            <div className="match-filters__field">
              <div className="match-filters__label">
                <span>{t("filters.minRelevanceScore", { score: minRelevanceScore.toFixed(1) })}</span>
                <button
                  type="button"
                  className="match-filters__clear--inline"
                  onClick={() => clearField("minRelevanceScore")}
                  title={t("filters.clear")}
                  disabled={localMinScore === DEFAULT_MIN_RELEVANCE_SCORE}
                >
                  {t("filters.clear")}
                </button>
              </div>
              <div className="match-filters__slider-container">
                <input
                  type="range"
                  className="match-filters__slider"
                  min="0"
                  max="10"
                  step="0.1"
                  value={localMinScore}
                  onChange={e => handleInputChange("minRelevanceScore", e.target.value)}
                />
                <div className="match-filters__slider-track">
                  <span>{t("filters.scoreRange")[0]}</span>
                  <span>{t("filters.scoreRange")[1]}</span>
                </div>
              </div>
            </div>

            <div className="match-filters__field">
              <RegionsMultiSelect
                value={localRegion}
                onChange={handleRegionChange}
                options={regionOptions}
                label={t("filters.regions")}
                placeholder={t("filters.regionPlaceholder", {
                  examples: regionOptions
                    .slice(0, 3)
                    .map(r => currentLanguage === "he" && REGIONS_DICTIONARY[r] ? REGIONS_DICTIONARY[r] : r)
                    .join(", ")
                })}
                inputId="region"
                className="match-filters__input"
              />
            </div>
          </div>

          <div className="match-filters__actions">
            <button
              type="button"
              className={`match-filters__clear-all ${!hasActiveFilters() ? "disabled" : ""}`}
              onClick={clearAllFilters}
              title={t("filters.clearAll")}
              disabled={!hasActiveFilters()}
            >
              {t("filters.clearAll")}
            </button>
          </div>
        </form>

        {/* Mobile-only apply button — hidden on desktop via CSS */}
        <div className="match-filters__mobile-footer">
          <button
            type="button"
            className="match-filters__apply"
            onClick={() => setIsFiltersOpen(false)}
          >
            {t("filters.applyFilters") || "Apply"}
          </button>
        </div>
      </div>
    </section>
  );
};

export default MatchesFilters;
