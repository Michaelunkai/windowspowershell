import { SquareCheck, CloudDownload, Link as LucideLink, Copy, ArrowRightFromLine, ThumbsUp, ThumbsDown } from "lucide-react";
import React, { useState, useEffect } from "react";

import { setMatchSent, setMatchRelevant } from "../../api";
import { useTranslations } from "../../utils/translations";
import JobDescriptionModal from "../shared/JobDescriptionModal";
import CandidateModal from "./CandidateModal";
import "./MatchesTableUser.css";

const MatchesTableUser = ({ jobs: initialJobs, loading, error, sortField, sortDirection, onSort }) => {
  const [jobs, setJobs] = useState(initialJobs);
  const [selectedJob, setSelectedJob] = useState(null);
  const [selectedCandidate, setSelectedCandidate] = useState(null);
  const [expandedJobIds, setExpandedJobIds] = useState(new Set());
  const [changingMatches, setChangingMatches] = useState(new Set());
  const [changingRelevance, setChangingRelevance] = useState(new Set());
  const [copiedJobId, setCopiedJobId] = useState(null);
  const { t, currentLanguage } = useTranslations("matches");

  const expandAll = () => {
    const allJobIds = new Set(jobs.map(job => job.id));
    setExpandedJobIds(allJobIds);
  };

  const collapseAll = () => {
    setExpandedJobIds(new Set());
  };

  const allExpanded = jobs.length > 0 && expandedJobIds.size === jobs.length;

  const copyToClipboard = jobId => {
    navigator.clipboard.writeText(jobId).then(() => {
      setCopiedJobId(jobId);
      setTimeout(() => setCopiedJobId(null), 2000);
    }).catch(err => {
      console.error("Failed to copy:", err);
    });
  };

  const getSortIcon = field => {
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

  useEffect(() => {
    setJobs(initialJobs);
  }, [initialJobs]);

  const toggleJobExpansion = jobId => {
    setExpandedJobIds(prev => {
      const newSet = new Set(prev);
      if (newSet.has(jobId)) {
        newSet.delete(jobId);
      } else {
        newSet.add(jobId);
      }
      return newSet;
    });
  };

  const getScoreColor = score => {
    const numScore = parseFloat(score);
    const isInvalidScore = isNaN(numScore);
    if (isInvalidScore) {
      const gray = "#666";
      return gray;
    }
    const isLowScore = numScore <= 6;
    if (isLowScore) {
      const red = "#dc3545";
      return red;
    }
    const isHighScore = numScore >= 8.5;
    if (isHighScore) {
      const green = "#4caf50";
      return green;
    }
    const orange = "#ff8c00";
    return orange;
  };

  const translateStatus = status => {
    const statusMap = {
      YES: t("table.statusValues.yes"),
      NO: t("table.statusValues.no"),
      pending: t("table.statusValues.pending"),
      sent: t("table.statusValues.sent")
    };
    return statusMap[status] || status;
  };

  const handleToggleMatchStatus = async (jobId, matchId, currentStatus) => {
    setChangingMatches(prev => new Set([...prev, matchId]));
    try {
      const newStatus = currentStatus === "pending" ? "sent" : "pending";
      await setMatchSent(matchId, newStatus);
      setJobs(prevJobs =>
        prevJobs.map(job => {
          if (job.id === jobId) {
            const updatedCandidates = job.matchedCandidates.map(candidate => {
              if (candidate._metadata.matchId === matchId) {
                return { ...candidate, status: newStatus };
              }
              return candidate;
            });
            return { ...job, matchedCandidates: updatedCandidates };
          }
          return job;
        })
      );
    } catch (_error) {
      alert("Failed to update match status. Please try again.");
    } finally {
      setChangingMatches(prev => {
        const newSet = new Set(prev);
        newSet.delete(matchId);
        return newSet;
      });
    }
  };

  const handleToggleRelevance = async (jobId, matchId, currentRelevance, isThumbsUp) => {
    setChangingRelevance(prev => new Set([...prev, matchId]));
    const prevJobsSnapshot = jobs;
    try {
      let newRelevance;
      if (isThumbsUp) {
        newRelevance = currentRelevance === "relevant" ? "neutral" : "relevant";
      } else {
        newRelevance = currentRelevance === "irrelevant" ? "neutral" : "irrelevant";
      }
      // Optimistic update: apply locally first so UI responds immediately
      const prevJobsSnapshot = jobs;
      setJobs(prevJobs =>
        prevJobs.map(job => {
          if (job.id === jobId) {
            const updatedCandidates = job.matchedCandidates.map(candidate => {
              if (candidate._metadata.matchId === matchId) {
                console.debug("Optimistic relevance update", { jobId, matchId, oldRelevance: candidate.relevance, newRelevance });
                return { ...candidate, relevance: newRelevance };
              }
              return candidate;
            });
            return { ...job, matchedCandidates: updatedCandidates };
          }
          return job;
        })
      );

      const resp = await setMatchRelevant(matchId, newRelevance);
      // If API returns an error-like response (but still 200), rollback
      if (resp && resp.success === false) {
        // Rollback
        setJobs(prevJobsSnapshot);
        throw new Error(resp.error || "Failed to set relevance");
      }
    } catch (_error) {
      console.error("Failed to update match relevance", _error);
      // Rollback on error
      setJobs(prevJobsSnapshot);
      alert("Failed to update match relevance. Please try again.");
    } finally {
      setChangingRelevance(prev => {
        const newSet = new Set(prev);
        newSet.delete(matchId);
        return newSet;
      });
    }
  };

  const downloadCV = (cvLink, candidateName) => {
    const link = document.createElement("a");
    link.href = cvLink;
    link.download = `${candidateName}_CV.pdf`;
    link.target = "_blank";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <>
      <div className="user-accordion" key={currentLanguage}>
        {loading ? (
          <div className="user-accordion__loading">Loading matches...</div>
        ) : error ? (
          <div className="user-accordion__error">Error loading matches: {error}</div>
        ) : !jobs || jobs.length === 0 ? (
          <div className="user-accordion__empty">{t("table.noMatches")}</div>
        ) : (
          <>
            {/* Global Header */}
            <div className="user-accordion__header">
              {/* Empty expand column */}
              <div className="user-accordion__strip-cell user-accordion__strip-cell--expand">
              </div>

              {/* Job ID */}
              <div
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "job_id" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("job_id")}
              >
                <span>{t("table.headers.jobId")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("job_id")}</span>
              </div>

              {/* Job Title */}
              <div
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "job_title" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("job_title")}
              >
                <span>{t("table.headers.jobTitle")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("job_title")}</span>
              </div>

              {/* Company */}
              <div
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "company" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("company")}
              >
                <span>{t("table.headers.company")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("company")}</span>
              </div>

              {/* Region */}
              <button
                type="button"
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "region" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("region")}
              >
                <span>{t("table.headers.region")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("region")}</span>
              </button>

              {/* Location */}
              <div
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "location" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("location")}
              >
                <span>{t("table.headers.location")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("location")}</span>
              </div>

              {/* Date Added */}
              <div
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "dateAdded" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("dateAdded")}
              >
                <span>{t("table.headers.dateAdded")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("dateAdded")}</span>
              </div>

              {/* Match Score */}
              <div
                className={`user-accordion__strip-cell user-accordion__header-cell--sortable ${sortField === "score" ? "user-accordion__header-cell--sorted" : ""}`}
                onClick={() => onSort && onSort("score")}
              >
                <span>{t("table.headers.matchScore")}</span>
                <span className="user-accordion__sort-icon">{getSortIcon("score")}</span>
              </div>

              {/* Meets Mandatory Req */}
              <div className="user-accordion__strip-cell">
                {t("table.headers.meetsMandatoryReq")}
              </div>

              {/* Expand All Button */}
              <div className="user-accordion__strip-cell user-accordion__strip-cell--center">
                <button
                  className="user-accordion__expand-all-btn"
                  onClick={allExpanded ? collapseAll : expandAll}
                  title={allExpanded ? t("table.collapseAll") : t("table.expandAll")}
                >
                  {allExpanded ? t("table.collapseAll") : t("table.expandAll")}
                </button>
              </div>
            </div>

            {/* Row List */}
            <div className="user-accordion__list">
              {jobs.map(job => {
                const isExpanded = expandedJobIds.has(job.id);
                const candidate = job.matchedCandidates?.[0]; // Get first candidate for the scan strip

                if (!candidate) {
                  return null;
                }

                const isChangingMatch = changingMatches.has(candidate._metadata.matchId);
                const isChangingRel = changingRelevance.has(candidate._metadata.matchId);
                const relevance = candidate.relevance || "neutral";
                console.debug("Rendering candidate relevance", { jobId: job.id, matchId: candidate._metadata.matchId, relevance });

                return (
                  <div key={job.id} className="user-accordion__row">
                    {/* Scan Strip - Collapsed State */}
                    <div
                      className={`user-accordion__strip ${isExpanded ? "user-accordion__strip--expanded" : ""}`}
                    >
                      {/* Expand Button */}
                      <div className="user-accordion__strip-cell user-accordion__strip-cell--expand">
                        <button
                          className={`user-accordion__expand-btn ${!isExpanded ? "user-accordion__expand-btn--collapsed" : ""}`}
                          onClick={() => toggleJobExpansion(job.id)}
                          aria-label={isExpanded ? "Collapse" : "Expand"}
                        >
                          {isExpanded ? (
                            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                              <path d="M4 10L8 6L12 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                          ) : (
                            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                              <path d="M6 4L10 8L6 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                          )}
                        </button>
                      </div>

                      {/* Job ID */}
                      <div className="user-accordion__strip-cell user-accordion__strip-cell--job-id">
                        <span className="user-accordion__job-id">{job.job_id || "N/A"}</span>
                        {job.job_id && (
                          <div className="user-accordion__copy-wrapper">
                            <button
                              className="user-accordion__copy-btn"
                              onClick={e => {
                                e.stopPropagation();
                                copyToClipboard(job.job_id);
                              }}
                              title="Copy Job ID"
                            >
                              <Copy aria-label="Copy" />
                            </button>
                            {copiedJobId === job.job_id && (
                              <span className="user-accordion__copy-tooltip">Job ID copied!</span>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Job Title */}
                      <div
                        className="user-accordion__strip-cell user-accordion__strip-cell--title"
                      >
                        <span className="user-accordion__job-title" onClick={() => toggleJobExpansion(job.id)}>{job.jobTitle}</span>
                        <button
                          className="user-accordion__job-view-btn"
                          onClick={e => {
                            e.stopPropagation();
                            setSelectedJob(job);
                          }}
                          title="View job details"
                          aria-label="View job details"
                        >
                          <ArrowRightFromLine aria-label="View" />
                        </button>
                      </div>

                      {/* Company */}
                      <div
                        className="user-accordion__strip-cell"
                        onClick={() => toggleJobExpansion(job.id)}
                      >
                        <span className="user-accordion__company">{job.company || "N/A"}</span>
                      </div>

                      {/* Region */}
                      <button
                        type="button"
                        className="user-accordion__strip-cell"
                        onClick={() => toggleJobExpansion(job.id)}
                      >
                        <span className="user-accordion__region">{job.region || "—"}</span>
                      </button>

                      {/* Location */}
                      <div
                        className="user-accordion__strip-cell"
                        onClick={() => toggleJobExpansion(job.id)}
                      >
                        <span className="user-accordion__location">{job.location || "—"}</span>
                      </div>

                      {/* Date */}
                      <div
                        className="user-accordion__strip-cell"
                        onClick={() => toggleJobExpansion(job.id)}
                      >
                        <span className="user-accordion__date">{job.dateAdded || "N/A"}</span>
                      </div>

                      {/* Match Score */}
                      <div
                        className="user-accordion__strip-cell"
                        onClick={() => toggleJobExpansion(job.id)}
                      >
                        <span
                          className="user-accordion__score"
                          style={{ color: getScoreColor(candidate.score) }}
                        >
                          {candidate.score}
                        </span>
                      </div>

                      {/* MMR */}
                      <div
                        className="user-accordion__strip-cell"
                        onClick={() => toggleJobExpansion(job.id)}
                      >
                        <span className={`user-accordion__mmr-badge user-accordion__mmr-badge--${candidate.mmr.toLowerCase()}`}>
                          {translateStatus(candidate.mmr)}
                        </span>
                      </div>

                      {/* Actions */}
                      <div
                        className="user-accordion__strip-cell user-accordion__strip-cell--center"
                      >
                        <button
                          className="user-accordion__details-btn"
                          onClick={() => toggleJobExpansion(job.id)}
                        >
                          {isExpanded ? t("hideDetails") : t("showDetails")}
                        </button>
                      </div>
                    </div>

                    {/* Action Drawer - Expanded State (Single Line) */}
                    {isExpanded && (
                      <div className="user-accordion__drawer">
                        <button
                          className="user-accordion__report-btn"
                          onClick={e => {
                            e.stopPropagation();
                            setSelectedCandidate(candidate);
                          }}
                        >
                          <ArrowRightFromLine width={18} height={18} aria-label={t("table.showDetailedReport")} />
                          {t("table.showDetailedReport")}
                        </button>

                        {candidate.cv && candidate.cvLink ? (
                          <button
                            className="user-accordion__cv-btn"
                            onClick={e => {
                              e.stopPropagation();
                              downloadCV(candidate.cvLink, candidate.name);
                            }}
                          >
                            <CloudDownload aria-label="Download CV" />
                          </button>
                        ) : null}

                        <div className="user-accordion__drawer-divider" />

                        <span className="user-accordion__drawer-label">{t("table.headers.wasMatchRelevant")}</span>
                        <div className="user-accordion__relevance-btns">
                          <button
                            className={`user-accordion__relevance-btn user-accordion__relevance-btn--up ${relevance === "relevant" ? "active thumbs-up" : ""}`}
                            onClick={e => {
                              e.stopPropagation();
                              handleToggleRelevance(job.id, candidate._metadata.matchId, relevance, true);
                            }}
                            disabled={isChangingRel}
                          >
                            <ThumbsUp aria-label="Relevant" />
                          </button>
                          <button
                            className={`user-accordion__relevance-btn user-accordion__relevance-btn--down ${relevance === "irrelevant" ? "active thumbs-down" : ""}`}
                            onClick={e => {
                              e.stopPropagation();
                              handleToggleRelevance(job.id, candidate._metadata.matchId, relevance, false);
                            }}
                            disabled={isChangingRel}
                          >
                            <ThumbsDown aria-label="Irrelevant" />
                          </button>
                        </div>

                        <div className="user-accordion__drawer-divider" />

                        {job.link && (
                          <>
                            <a
                              href={job.link}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="user-accordion__external-link"
                              onClick={e => e.stopPropagation()}
                            >
                              <LucideLink width={18} height={18} aria-label={t("table.linkToJob")} />
                              {t("table.linkToJob")}
                            </a>
                            <div className="user-accordion__drawer-divider" />
                          </>
                        )}

                        <div className="user-accordion__drawer-spacer" />

                        <span className="user-accordion__drawer-label">{t("table.headers.appliedStatus")}</span>
                        <span className={`user-accordion__badge user-accordion__badge--${candidate.status}`}>
                          {translateStatus(candidate.status)}
                        </span>

                        <button
                          className={`user-accordion__primary-action ${candidate.status === "sent" ? "user-accordion__primary-action--revert" : ""}`}
                          onClick={e => {
                            e.stopPropagation();
                            handleToggleMatchStatus(job.id, candidate._metadata.matchId, candidate.status);
                          }}
                          disabled={isChangingMatch}
                        >
                          <SquareCheck width={18} height={18} aria-label={t("table.markAsSent")} />
                          {isChangingMatch
                            ? t("table.updating")
                            : candidate.status === "pending"
                              ? t("table.markAsSent")
                              : t("table.revertStatus")}
                        </button>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>

      {/* Shared modals */}
      {selectedJob && (
        <JobDescriptionModal
          job={selectedJob}
          isOpen={!!selectedJob}
          onClose={() => setSelectedJob(null)}
        />
      )}

      {selectedCandidate && (
        <CandidateModal
          candidate={selectedCandidate}
          onClose={() => setSelectedCandidate(null)}
        />
      )}
    </>
  );
};

export default MatchesTableUser;
