import { Eye, Trash2, Link, ArrowRightFromLine, Copy } from "lucide-react";
import React, { useState, useRef, useEffect } from "react";

import { REGIONS_DICTIONARY } from "../../utils/constants";
import { getRelativeDays } from "../../utils/dateHelpers";
import { useTranslations } from "../../utils/translations";
import JobDescriptionModal from "../shared/JobDescriptionModal";
import TruncatedText from "../shared/TruncatedText";
import "./JobListingsTable.css";

const getAgeClass = age => {
  switch (age) {
    case "New":
      return "age-new";
    case "Fresh":
      return "age-fresh";
    case "Stale":
      return "age-stale";
    case "Old":
      return "age-old";
    default:
      return "";
  }
};

const getSortIcon = (field, sortField, sortDirection) => {
  if (sortField !== field) {
    return (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  if (sortDirection === "asc") {
    return (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
};

const SortableHeader = ({ field, children, sortable = true, sortField, sortDirection, onSort }) => {
  const handleClick = () => {
    if (sortable && onSort) {
      onSort(field);
    }
  };

  return (
    <th
      className={`job-table__cell job-table__cell--header ${
        sortable ? "job-table__cell--sortable" : ""
      } ${sortField === field ? "job-table__cell--sorted" : ""}`}
      onClick={handleClick}
    >
      <div className="job-table__header-content">
        <span>{children}</span>
        {sortable && (
          <span className="job-table__sort-icon">{getSortIcon(field, sortField, sortDirection)}</span>
        )}
      </div>
    </th>
  );
};

const JobListingsTable = ({
  jobs,
  loading,
  error,
  onAction,
  sortField,
  sortDirection,
  onSort,
  showActions = true,
  onJobTitleClick
}) => {
  const { t, currentLanguage } = useTranslations("jobListings");
  const [selectedJob, setSelectedJob] = useState(null);
  const [copiedJobId, setCopiedJobId] = useState(null);
  const copyTimeoutRef = useRef(null);

  useEffect(() => {
    return () => { if (copyTimeoutRef.current) clearTimeout(copyTimeoutRef.current); };
  }, []);

  const sortProps = { sortField, sortDirection, onSort };

  const handleCopyJobId = async jobId => {
    try {
      await navigator.clipboard.writeText(jobId);
      setCopiedJobId(jobId);
      if (copyTimeoutRef.current) clearTimeout(copyTimeoutRef.current);
      copyTimeoutRef.current = setTimeout(() => setCopiedJobId(null), 2000);
    } catch (err) {
      console.error("Failed to copy job ID:", err);
    }
  };

  const truncateJobId = jobId => {
    if (!jobId) return "";
    return jobId.length > 20 ? `${jobId.substring(0, 20)}...` : jobId;
  };

  const getLocalizedRegion = value => {
    if (!value) return "—";
    return currentLanguage === "he" && REGIONS_DICTIONARY[value] ? REGIONS_DICTIONARY[value] : value;
  };

  return (
    <div className="job-table" key={currentLanguage}>

      {/* Mobile card list */}
      <div className="joblisting-layout--mobile">
        <div className="job-mobile">
          {loading ? (
            <div className="job-mobile__loading">{t("table.loading")}</div>
          ) : error ? (
            <div className="job-mobile__error">{t("table.error", { error })}</div>
          ) : !jobs || jobs.length === 0 ? (
            <div className="job-mobile__empty">{t("table.noJobs")}</div>
          ) : (
            jobs.map((job, index) => (
              <div key={`${index}_${job.job_id || job.id || "NA"}_${job.company || "unknown"}`} className="job-card">
                <h3 className="job-card__title" onClick={() => setSelectedJob(job)}>
                  {job.title}
                </h3>

                <div className="job-card__details">
                  <div className="job-card__detail">
                    <span className="job-card__label">{t("table.headers.company")}:</span>
                    <span className="job-card__value">{job.company}</span>
                  </div>
                  <div className="job-card__detail">
                    <span className="job-card__label">{t("table.headers.region")}:</span>
                    <span className="job-card__value">{getLocalizedRegion(job.region)}</span>
                  </div>
                  <div className="job-card__detail">
                    <span className="job-card__label">{t("table.headers.location")}:</span>
                    <span className="job-card__value">{getLocalizedRegion(job.location)}</span>
                  </div>
                  <div className="job-card__detail">
                    <span className="job-card__label">{t("table.headers.datePosted")}:</span>
                    <span className="job-card__value">{job.posted}</span>
                  </div>
                  <div className="job-card__detail">
                    <span className="job-card__label">{t("table.headers.age")}:</span>
                    <span className="job-card__value">
                      <span className={`age-badge ${getAgeClass(job.ageCategory)}`}>
                        {getRelativeDays(job.rawDate || job.posted, currentLanguage, t("table.ageLabels.today"))}
                      </span>
                    </span>
                  </div>
                  <div className="job-card__detail job-card__detail--id">
                    <span className="job-card__label">{t("table.headers.jobId")}:</span>
                    <div className="job-card__id-wrapper">
                      <span className="job-card__value job-card__value--id" title={job.job_id}>
                        {truncateJobId(job.job_id)}
                      </span>
                      {job.job_id && (
                        <button
                          className="job-card__copy-btn"
                          onClick={() => handleCopyJobId(job.job_id)}
                          title="Copy Job ID"
                          aria-label="Copy Job ID"
                        >
                          <Copy aria-hidden="true" />
                          {copiedJobId === job.job_id && (
                            <span className="job-card__copied-tooltip">Copied!</span>
                          )}
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                <div className="job-card__actions">
                  {job.position_link ? (
                    <a
                      href={job.position_link}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="job-card__action-btn job-card__action-btn--link"
                      title={t("table.actions.openLink")}
                    >
                      <Link aria-hidden="true" />
                      <span>{t("table.headers.linkToJob")}</span>
                    </a>
                  ) : (
                    <span className="job-card__action-btn job-card__action-btn--disabled">
                      <span>—</span>
                    </span>
                  )}
                  {showActions && (
                    <div className="job-card__action-buttons">
                      <button
                        className="job-card__icon-btn job-card__icon-btn--view"
                        onClick={() => onAction("view", job)}
                        title={t("table.actions.view")}
                        aria-label={t("table.actions.view")}
                      >
                        <Eye aria-hidden="true" />
                      </button>
                      <button
                        className="job-card__icon-btn job-card__icon-btn--delete"
                        onClick={() => onAction("delete", job)}
                        title={t("table.actions.delete")}
                        aria-label={t("table.actions.delete")}
                      >
                        <Trash2 aria-hidden="true" />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Desktop table */}
      <div className="joblisting-layout--desktop">
        <div className="job-table__container">
          {loading ? (
            <div className="job-table__loading">{t("table.loading")}</div>
          ) : error ? (
            <div className="job-table__error">{t("table.error", { error })}</div>
          ) : (
            <table className="job-table__table">
              <thead className="job-table__header">
                <tr>
                  <SortableHeader field="job_id" {...sortProps}>
                    {t("table.headers.jobId")}
                  </SortableHeader>
                  <SortableHeader field="title" {...sortProps}>{t("table.headers.title")}</SortableHeader>
                  <SortableHeader field="company" {...sortProps}>{t("table.headers.company")}</SortableHeader>
                  <SortableHeader field="region" {...sortProps}>{t("table.headers.region")}</SortableHeader>
                  <SortableHeader field="location" {...sortProps}>{t("table.headers.location")}</SortableHeader>
                  <SortableHeader field="posted" {...sortProps}>{t("table.headers.datePosted")}</SortableHeader>
                  <SortableHeader field="age" {...sortProps}>{t("table.headers.age")}</SortableHeader>
                  <SortableHeader field="link" sortable={false} {...sortProps}>
                    {t("table.headers.linkToJob")}
                  </SortableHeader>
                  {showActions && (
                    <SortableHeader field="actions" sortable={false} {...sortProps}>
                      {t("table.headers.actions")}
                    </SortableHeader>
                  )}
                </tr>
              </thead>
              <tbody>
                {!jobs || jobs.length === 0 ? (
                  <tr>
                    <td colSpan={showActions ? "9" : "8"} className="job-table__empty">
                      {t("table.noJobs")}
                    </td>
                  </tr>
                ) : (
                  jobs.map((job, index) => (
                    <tr key={`${index}_${job.job_id || job.id || "NA"}_${job.company || "unknown"}`} className="job-table__row">
                      <td className="job-table__cell" data-label={t("table.headers.jobId")}>
                        <div className="joblistings-copy-wrapper" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", position: "relative", width: "100%" }}>
                          <TruncatedText
                            text={job.job_id || ""}
                            maxWidth="100px"
                            className="job-id-truncated"
                            style={{ marginInlineEnd: "8px" }}
                          />
                          {job.job_id && (
                            <button
                              className="redesigned-table__copy-btn"
                              title="Copy Job ID"
                              aria-label="Copy Job ID"
                              onClick={() => handleCopyJobId(job.job_id)}
                            >
                              <Copy />
                            </button>
                          )}
                          {copiedJobId === job.job_id && (
                            <span className="joblistings-copy-tooltip">Copied!</span>
                          )}
                        </div>
                      </td>
                      <td className="job-table__cell job-table__cell--title" data-label={t("table.headers.title")}>
                        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "0.5rem", width: "100%" }}>
                          <button
                            type="button"
                            className="job-table__link-title"
                            onClick={() => onJobTitleClick && onJobTitleClick(job)}
                            title={job.title}
                          >
                            {job.title}
                          </button>
                          <button
                            className="job-table__job-view-btn"
                            onClick={() => setSelectedJob(job)}
                            title={t("table.actions.view")}
                            aria-label={t("table.actions.view")}
                          >
                            <ArrowRightFromLine width={18} height={18} aria-hidden="true" />
                          </button>
                        </div>
                      </td>
                      <td className="job-table__cell" data-label={t("table.headers.company")}>{job.company}</td>
                      <td className="job-table__cell" data-label={t("table.headers.region")}>{job.region || "—"}</td>
                      <td className="job-table__cell" data-label={t("table.headers.location")}>{job.location || "—"}</td>
                      <td className="job-table__cell" data-label={t("table.headers.datePosted")}>{job.posted}</td>
                      <td className="job-table__cell" data-label={t("table.headers.age")}>
                        <span className={`age-badge ${getAgeClass(job.ageCategory)}`}>
                          {getRelativeDays(job.rawDate || job.posted, currentLanguage, t("table.ageLabels.today"))}
                        </span>
                      </td>
                      <td className="job-table__cell job-table__cell--link" data-label={t("table.headers.linkToJob")}>
                        {job.position_link ? (
                          <a
                            href={job.position_link}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="job-link-btn"
                            title={t("table.actions.openLink")}
                            aria-label={t("table.actions.openLink")}
                            style={{ margin: 0 }}
                          >
                            <Link width={18} height={18} className="job-link-icon" aria-hidden="true" />
                            <span className="job-link-text">{t("table.headers.linkToJob")}</span>
                          </a>
                        ) : (
                          <span className="job-link-unavailable" title={t("table.linkNotAvailable")}>
                            —
                          </span>
                        )}
                      </td>
                      {showActions && (
                        <td className="job-table__cell job-table__cell--actions" data-label={t("table.headers.actions")}>
                          <div className="action-buttons">
                            <button
                              className="action-btn view-btn"
                              onClick={() => onAction("view", job)}
                              title={t("table.actions.view")}
                              aria-label={t("table.actions.view")}
                            >
                              <Eye aria-hidden="true" />
                            </button>
                            <button
                              className="action-btn delete-btn"
                              onClick={() => onAction("delete", job)}
                              title={t("table.actions.delete")}
                              aria-label={t("table.actions.delete")}
                            >
                              <Trash2 aria-hidden="true" />
                            </button>
                          </div>
                        </td>
                      )}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>

      <JobDescriptionModal
        job={selectedJob}
        isOpen={!!selectedJob}
        onClose={() => setSelectedJob(null)}
      />
    </div>
  );
};

export default JobListingsTable;
