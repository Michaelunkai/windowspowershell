import React, { useState, useEffect } from "react";

import { fetchCompanies, fetchRegions } from "../../api";
import { useControlledInput } from "../../hooks/useControlledInput";
import { REGIONS_DICTIONARY, FALLBACK_REGIONS } from "../../utils/constants";
import { getLocalDateString } from "../../utils/textHelpers";
import { useTranslations } from "../../utils/translations";
import CompanyAutocompleteInput from "../shared/CompanyAutocompleteInput";
import RegionsMultiSelect from "../shared/RegionsMultiSelect";

const JobListingsFilters = ({
  jobTitleTerm,
  onJobTitleChange,
  jobDescriptionTerm,
  onJobDescriptionChange,
  jobIdTerm,
  onJobIdChange,
  selectedCompany,
  onCompanyChange,
  selectedRegions,
  onRegionsChange,
  postedAfter,
  onPostedAfterChange,
  onClearAll
}) => {
  const { t, currentLanguage } = useTranslations("jobListings");
  const [companyOptions, setCompanyOptions] = useState([]);
  const [regionOptions, setRegionOptions] = useState([]);
  const [localCompany, setLocalCompany] = useControlledInput(selectedCompany);
  const [isFiltersVisible, setIsFiltersVisible] = useState(true);
  const [isFiltersOpen, setIsFiltersOpen] = useState(false);

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

  // Sync localCompany with prop when selectedCompany changes
  useEffect(() => {
    setLocalCompany(selectedCompany || "");
  }, [selectedCompany, setLocalCompany]);

  const handleCompanyChange = company => {
    setLocalCompany(company);
    onCompanyChange(company);
  };

  // Clear individual field
  const clearField = field => {
    switch (field) {
      case "jobTitle":
        onJobTitleChange("");
        break;
      case "jobDescription":
        onJobDescriptionChange("");
        break;
      case "jobId":
        onJobIdChange("");
        break;
      case "company":
        setLocalCompany("");
        onCompanyChange("");
        break;
      case "regions":
        onRegionsChange("");
        break;
      case "postedAfter":
        onPostedAfterChange("");
        break;
    }
  };

  const hasActiveFilters = () => {
    return jobTitleTerm ||
      jobDescriptionTerm ||
      jobIdTerm ||
      localCompany ||
      selectedRegions ||
      postedAfter;
  };

  const getActiveFiltersCount = () => {
    let count = 0;
    if (jobTitleTerm) {
      count++;
    }
    if (jobDescriptionTerm) {
      count++;
    }
    if (jobIdTerm) {
      count++;
    }
    if (localCompany) {
      count++;
    }
    if (selectedRegions) {
      count++;
    }
    if (postedAfter) {
      count++;
    }
    return count;
  };

  // Clear all filters
  const clearAllFilters = () => {
    if (!hasActiveFilters()) {
      return;
    }
    setLocalCompany("");
    if (onClearAll) {
      onClearAll();
    }
  };

  const activeCount = getActiveFiltersCount();

  return (
    <section
      className={`job-filters ${isFiltersOpen ? "job-filters--open" : ""}`}
      aria-label={t("filters.title")}
      key={currentLanguage}
    >
      {/* Mobile-only toggle button — hidden on desktop via CSS */}
      <button
        type="button"
        className="job-filters-mobile__toggle"
        onClick={() => setIsFiltersOpen(o => !o)}
      >
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M2 4h16M5 10h10M8 16h4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
        <span>{t("filters.title")}</span>
        {activeCount > 0 && (
          <span className="job-filters-mobile__badge">{activeCount}</span>
        )}
      </button>

      {/* Overlay — rendered only when drawer is open */}
      {isFiltersOpen && (
        <button
          type="button"
          className="job-filters-mobile__overlay"
          aria-label={t("filters.closeDrawer")}
          onClick={() => setIsFiltersOpen(false)}
        />
      )}

      {/* The panel — inline on desktop, drawer on mobile */}
      <div className="job-filters__panel">
        {/* Unified header — collapse toggle on desktop, close button on mobile */}
        <div className="job-filters__header">
          <h2 className="job-filters__title">
            {t("filters.title")}
            {activeCount > 0 && (
              <span className="job-filters__badge">{activeCount}</span>
            )}
          </h2>
          <button
            className="job-filters__toggle"
            onClick={() => setIsFiltersVisible(!isFiltersVisible)}
            aria-expanded={isFiltersVisible}
            aria-controls="filters-form"
            title={isFiltersVisible ? t("filters.hideFilters") : t("filters.showFilters")}
          >
            <span className={`job-filters__toggle-icon ${isFiltersVisible ? "expanded" : ""}`}>
              <svg width="12" height="8" viewBox="0 0 12 8" fill="none">
                <path d="M1 1L6 6L11 1" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </span>
          </button>
          <button
            type="button"
            className="job-filters__close"
            onClick={() => setIsFiltersOpen(false)}
            aria-label={t("filters.close") || "Close filters"}
          >
            ×
          </button>
        </div>

        {/* Filter fields — shared for both desktop and mobile */}
        <form
          id="filters-form"
          className={`job-filters__form ${isFiltersVisible ? "visible" : "hidden"}`}
          role="search"
          aria-label="Filter jobs"
          onSubmit={e => e.preventDefault()}
        >
          <div className="job-filters__grid">
            <div className="job-filters__field">
              <label className="job-filters__label" htmlFor="job-title-search">
                {t("filters.searchJobTitle")}
              </label>
              <div className="job-filters__input-container">
                <input
                  id="job-title-search"
                  type="text"
                  className="job-filters__input"
                  placeholder={t("filters.jobTitlePlaceholder")}
                  value={jobTitleTerm}
                  onChange={e => onJobTitleChange(e.target.value)}
                />
                {jobTitleTerm && (
                  <button
                    type="button"
                    className="job-filters__clear"
                    onClick={() => clearField("jobTitle")}
                    title={t("filters.clear")}
                  >
                    ×
                  </button>
                )}
              </div>
            </div>

            <div className="job-filters__field">
              <label className="job-filters__label" htmlFor="job-description-search">
                {t("filters.searchJobDescription")}
              </label>
              <div className="job-filters__input-container">
                <input
                  id="job-description-search"
                  type="text"
                  className="job-filters__input"
                  placeholder={t("filters.jobDescriptionPlaceholder")}
                  value={jobDescriptionTerm}
                  onChange={e => onJobDescriptionChange(e.target.value)}
                />
                {jobDescriptionTerm && (
                  <button
                    type="button"
                    className="job-filters__clear"
                    onClick={() => clearField("jobDescription")}
                    title={t("filters.clear")}
                  >
                    ×
                  </button>
                )}
              </div>
            </div>

            <div className="job-filters__field">
              <label className="job-filters__label" htmlFor="job-id-search">
                {t("filters.jobId")}
              </label>
              <div className="job-filters__input-container">
                <input
                  id="job-id-search"
                  type="text"
                  className="job-filters__input"
                  placeholder={t("filters.jobIdPlaceholder")}
                  value={jobIdTerm}
                  onChange={e => onJobIdChange(e.target.value)}
                />
                {jobIdTerm && (
                  <button
                    type="button"
                    className="job-filters__clear"
                    onClick={() => clearField("jobId")}
                    title={t("filters.clear")}
                  >
                    ×
                  </button>
                )}
              </div>
            </div>

            <div className="job-filters__field">
              <CompanyAutocompleteInput
                value={localCompany}
                onChange={handleCompanyChange}
                options={companyOptions}
                label={t("filters.companyFilter")}
                placeholder={t("filters.companyPlaceholder")}
                inputId="company"
                className=""
                filterType="job"
              />
            </div>

            <div className="job-filters__field">
              <RegionsMultiSelect
                value={selectedRegions}
                onChange={onRegionsChange}
                options={regionOptions}
                label={t("filters.regions")}
                placeholder={t("filters.regionsPlaceholder", {
                  examples: regionOptions
                    .slice(0, 3)
                    .map(r => currentLanguage === "he" && REGIONS_DICTIONARY[r] ? REGIONS_DICTIONARY[r] : r)
                    .join(", ")
                })}
                inputId="regions"
                className="job-filters__input"
              />
            </div>

            <div className="job-filters__field">
              <label className="job-filters__label" htmlFor="posted-after">
                {t("filters.postedAfter")}
              </label>
              <div className="job-filters__input-container">
                <input
                  id="posted-after"
                  type="date"
                  className="job-filters__input job-filters__input--date"
                  value={postedAfter || ""}
                  max={getLocalDateString()}
                  onChange={e => onPostedAfterChange(e.target.value)}
                />
                {postedAfter && (
                  <button
                    type="button"
                    className="job-filters__clear"
                    onClick={() => clearField("postedAfter")}
                    title={t("filters.clear")}
                  >
                    ×
                  </button>
                )}
              </div>
            </div>

          </div>

          <div className="job-filters__actions">
            <button
              type="button"
              className={`job-filters__clear-all ${!hasActiveFilters() ? "disabled" : ""}`}
              onClick={clearAllFilters}
              title={t("filters.clearAll")}
              disabled={!hasActiveFilters()}
            >
              {t("filters.clearAll")}
            </button>
          </div>
        </form>

        {/* Mobile-only apply button — hidden on desktop via CSS */}
        <div className="job-filters__mobile-footer">
          <button
            type="button"
            className="job-filters__apply"
            onClick={() => setIsFiltersOpen(false)}
          >
            {t("filters.applyFilters") || "Apply"}
          </button>
        </div>
      </div>
    </section>
  );
};

export default JobListingsFilters;
