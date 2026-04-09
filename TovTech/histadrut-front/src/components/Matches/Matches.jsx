import React from "react";

import { useAuth } from "../../hooks/useAuth";
import { useMatchesData } from "../../hooks/useMatchesData";
import useMediaQuery from "../../hooks/useMediaQuery";
import { useTranslations } from "../../utils/translations";
import ScrollToTop from "../shared/ScrollToTop";
import MatchesFilters from "./MatchesFilters";
import MatchesMobile from "./MatchesMobile";
import MatchesTableAdmin from "./MatchesTableAdmin";
import MatchesTableUser from "./MatchesTableUser";
import "./Matches.css";

const Matches = () => {
  const {
    jobsData,
    filteredJobs,
    loading,
    error,
    filters,
    updateFilters,
    handleLimitChange,
    currentPage,
    totalPages,
    totalJobs,
    goToNextPage,
    goToPreviousPage,
    sortField,
    sortDirection,
    handleSort
  } = useMatchesData();

  const { t, currentLanguage } = useTranslations("matches");
  const { user } = useAuth();
  const isAdminOrDemo = user?.role === "admin" || user?.role === "demo";
  const isMobile = useMediaQuery("(max-width: 768px)");

  return (
    <section className="main-page matches-page">
      <div className="matches-header">
        <h1 className="page__title">{t("title")}</h1>
        <p className="matches-subtitle">
          {isAdminOrDemo ? t("subtitle") : t("subtitleUser")}
        </p>
        {user?.role === "demo" && (
          <p className="matches-demo-warning">
            {t("demoWarning")}
          </p>
        )}
      </div>

      <MatchesFilters />

      {isMobile ? (
        <MatchesMobile
          jobs={filteredJobs}
          loading={loading}
          error={error}
        />
      ) : (
        isAdminOrDemo ? (
          <MatchesTableAdmin
            jobs={filteredJobs}
            allJobs={jobsData}
            loading={loading}
            error={error}
            sortField={sortField}
            sortDirection={sortDirection}
            onSort={handleSort}
          />
        ) : (
          <MatchesTableUser
            jobs={filteredJobs}
            loading={loading}
            error={error}
            sortField={sortField}
            sortDirection={sortDirection}
            onSort={handleSort}
          />
        )
      )}

      <div className="pagination-controls">
        <div className="pagination-left">
          <div className="page-size-control">
            <span className="page-size-label">{t("pagination.showLabel")}</span>
            <div className="page-size-buttons">
              {[20, 50, 100].map(size => (
                <button
                  key={size}
                  className={`page-size-btn ${filters?.limit === size ? "active" : ""}`}
                  onClick={() => handleLimitChange(size)}
                >
                  {t(`pagination.pageSize${size}`)}
                </button>
              ))}
            </div>
            <span className="page-size-label">{t("pagination.jobsPerPage")}</span>
          </div>
        </div>
        <div className="pagination-right">
          <button
            onClick={goToPreviousPage}
            disabled={currentPage === 1}
            className="pagination-button"
          >
            {t("pagination.previous")}
          </button>
          <span className="pagination-info">
            {t("pagination.pageInfo", { current: currentPage, total: totalPages })}
          </span>
          <span className="pagination-total">
            {t("pagination.totalJobs", { total: totalJobs })}
          </span>
          <button
            onClick={goToNextPage}
            disabled={currentPage === totalPages}
            className="pagination-button"
          >
            {t("pagination.next")}
          </button>
        </div>
      </div>
      <ScrollToTop />
    </section>
  );
};

export default Matches;
