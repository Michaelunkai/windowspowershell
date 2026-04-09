import { Link as LucideLink, Copy, ArrowRightFromLine } from "lucide-react";
import React, { useState, useEffect, Fragment } from "react";

import { setMatchSent, setMatchRelevant } from "../../api";
import { useAuth } from "../../hooks/useAuth";
import { DEFAULT_MIN_RELEVANCE_SCORE } from "../../utils/constants";
import { useTranslations } from "../../utils/translations";
import JobDescriptionModal from "../shared/JobDescriptionModal";
import CandidateModal from "./CandidateModal";
import CandidatesTable from "./CandidatesTable";
import "./MatchesTableAdmin.css";

const MatchesTableAdmin = ({ jobs: initialJobs, loading, error, sortField, sortDirection, onSort }) => {
  const [jobs, setJobs] = useState(initialJobs);
  const [selectedJob, setSelectedJob] = useState(null);
  const [selectedCandidate, setSelectedCandidate] = useState(null);
  const [expandedJobIds, setExpandedJobIds] = useState(new Set());
  const [changingMatches, setChangingMatches] = useState(new Set());
  const [changingRelevance, setChangingRelevance] = useState(new Set());
  const [copiedJobId, setCopiedJobId] = useState(null);
  const [showDemoCVModal, setShowDemoCVModal] = useState(false);
  const { t, currentLanguage } = useTranslations("matches");
  const { t: tCommon } = useTranslations("common");
  const { isAdmin } = useAuth();
  const isUserAdmin = isAdmin();

  const expandAll = () => {
    const allJobIds = new Set(jobs.map(job => job.id));
    setExpandedJobIds(allJobIds);
  };

  const collapseAll = () => {
    setExpandedJobIds(new Set());
  };

  const allExpanded = jobs.length > 0 && expandedJobIds.size === jobs.length;

  // Sort icons component
  const getSortIcon = field => {
    if (sortField !== field) {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
            strokeLinejoin="round" />
          <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
            strokeLinejoin="round" />
        </svg>
      );
    }

    if (sortDirection === "asc") {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
            strokeLinejoin="round" />
        </svg>
      );
    }

    return (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
          strokeLinejoin="round" />
      </svg>
    );
  };

  // Sortable header component
  const SortableHeader = ({ field, children, sortable = true, className = "" }) => {
    const handleClick = () => {
      if (sortable && onSort) {
        onSort(field);
      }
    };

    return (
      <th
        className={`redesigned-table__header ${
          sortable ? "redesigned-table__header--sortable" : ""
        } ${sortField === field ? "redesigned-table__header--sorted" : ""} ${className}`}
        onClick={handleClick}
      >
        <div className="redesigned-table__header-content">
          <span>{children}</span>
          {sortable && (
            <span className="redesigned-table__sort-icon">{getSortIcon(field)}</span>
          )}
        </div>
      </th>
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
      // noinspection UnnecessaryLocalVariableJS
      const gray = "#666";
      return gray;
    }

    const isLowScore = numScore <= 6;
    if (isLowScore) {
      // noinspection UnnecessaryLocalVariableJS
      const red = "#dc3545";
      return red;
    }

    const isHighScore = numScore >= DEFAULT_MIN_RELEVANCE_SCORE;
    if (isHighScore) {
      // noinspection UnnecessaryLocalVariableJS
      const green = "#4caf50";
      return green;
    }

    // Medium score between low threshold and min relevance score
    // noinspection UnnecessaryLocalVariableJS
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

      // For demo users, skip API call and just update local state
      if (!isUserAdmin) {
        // Simulate a brief delay for realism
        await new Promise(resolve => setTimeout(resolve, 300));
      } else {
        await setMatchSent(matchId, newStatus);
      }

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
    try {
      let newRelevance;
      if (isThumbsUp) {
        newRelevance = currentRelevance === "relevant" ? "neutral" : "relevant";
      } else {
        newRelevance = currentRelevance === "irrelevant" ? "neutral" : "irrelevant";
      }

      // For demo users, skip API call and just update local state
      if (!isUserAdmin) {
        // Simulate a brief delay for realism
        await new Promise(resolve => setTimeout(resolve, 300));
      } else {
        await setMatchRelevant(matchId, newRelevance);
      }

      setJobs(prevJobs =>
        prevJobs.map(job => {
          if (job.id === jobId) {
            const updatedCandidates = job.matchedCandidates.map(candidate => {
              if (candidate._metadata.matchId === matchId) {
                return { ...candidate, relevance: newRelevance };
              }
              return candidate;
            });
            return { ...job, matchedCandidates: updatedCandidates };
          }
          return job;
        })
      );
    } catch (_error) {
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
    // For demo users, show modal explaining this is demo mode
    if (!isUserAdmin) {
      setShowDemoCVModal(true);
      return;
    }

    if (cvLink) {
      const link = document.createElement("a");
      link.href = cvLink;
      link.download = `${candidateName}_CV.pdf`;
      link.target = "_blank";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } else {
      alert(`CV not available for ${candidateName}`);
    }
  };

  const copyToClipboard = jobId => {
    navigator.clipboard.writeText(jobId).then(() => {
      setCopiedJobId(jobId);
      setTimeout(() => {
        setCopiedJobId(null);
      }, 2000);
    }).catch(err => {
      console.error("Failed to copy:", err);
    });
  };

  return (
    <>
      <div className="redesigned-table" key={currentLanguage}>
        {loading ? (
          <div className="redesigned-table__loading">Loading matches...</div>
        ) : error ? (
          <div className="redesigned-table__error">Error loading matches: {error}</div>
        ) : (
          <table className="redesigned-table__main">
            <thead>
              <tr>
                <th className="redesigned-table__header redesigned-table__header--expand"></th>
                <SortableHeader field="job_id">
                  {t("table.headers.jobId")}
                </SortableHeader>
                <SortableHeader field="job_title" className="redesigned-table__header--title">
                  {t("table.headers.jobTitle")}
                </SortableHeader>
                <SortableHeader field="company">
                  {t("table.headers.company")}
                </SortableHeader>
                <SortableHeader field="region">
                  {t("table.headers.region")}
                </SortableHeader>
                <SortableHeader field="location">
                  {t("table.headers.location")}
                </SortableHeader>
                <SortableHeader field="dateAdded">
                  {t("table.headers.dateAdded")}
                </SortableHeader>
                <SortableHeader field="linkToJob" sortable={false}>
                  {t("table.headers.linkToJob")}
                </SortableHeader>
                <th className="redesigned-table__header">
                  <button
                    className="redesigned-table__expand-all-btn"
                    onClick={allExpanded ? collapseAll : expandAll}
                    title={allExpanded ? t("table.collapseAll") : t("table.expandAll")}
                  >
                    {allExpanded ? t("table.collapseAll") : t("table.expandAll")}
                  </button>
                </th>
              </tr>
            </thead>
            <tbody>
              {jobs.length === 0 ? (
                <tr>
                  <td colSpan="9" className="redesigned-table__empty">
                    {t("table.noMatches")}
                  </td>
                </tr>
              ) : (
                jobs.map(job => {
                  const isExpanded = expandedJobIds.has(job.id);
                  return (
                    <Fragment key={job.id}>
                      <tr className="redesigned-table__job-row">
                        <td className="redesigned-table__cell redesigned-table__cell--expand">
                          <button
                            className={`redesigned-table__expand-btn ${!isExpanded ? "redesigned-table__expand-btn--collapsed" : ""}`}
                            onClick={() => toggleJobExpansion(job.id)}
                            aria-label={isExpanded ? "Collapse" : "Expand"}
                          >
                            {isExpanded ? (
                              <svg width="16" height="16" viewBox="0 0 16 16" fill="none"
                                xmlns="http://www.w3.org/2000/svg"
                              >
                                <path d="M4 10L8 6L12 10" stroke="currentColor" strokeWidth="2"
                                  strokeLinecap="round" strokeLinejoin="round" />
                              </svg>
                            ) : (
                              <svg width="16" height="16" viewBox="0 0 16 16" fill="none"
                                xmlns="http://www.w3.org/2000/svg"
                              >
                                <path d="M6 4L10 8L6 12" stroke="currentColor" strokeWidth="2"
                                  strokeLinecap="round" strokeLinejoin="round" />
                              </svg>
                            )}
                          </button>
                        </td>
                        <td className="redesigned-table__cell redesigned-table__cell--job-id" data-label={t("table.headers.jobId")}>
                          <span className="redesigned-table__job-id-text">{job.job_id || "N/A"}</span>
                          {job.job_id && (
                            <div className="redesigned-table__copy-btn-wrapper">
                              <button
                                className="redesigned-table__copy-btn"
                                onClick={() => copyToClipboard(job.job_id)}
                                title="Copy Job ID"
                                aria-label="Copy Job ID to clipboard"
                              >
                                <Copy aria-label="Copy" color="#222" />
                              </button>
                              {copiedJobId === job.job_id && (
                                <span
                                  className="redesigned-table__copy-tooltip"
                                >Job ID copied!</span>
                              )}
                            </div>
                          )}
                        </td>
                        <td className="redesigned-table__cell redesigned-table__cell--title" data-label={t("table.headers.jobTitle")}>
                          <div className="redesigned-table__job-title-wrapper">
                            <span
                              className="redesigned-table__job-title"
                              onClick={() => setSelectedJob(job)}
                            >
                              {job.jobTitle}
                            </span>
                            <button
                              className="redesigned-table__job-view-btn"
                              onClick={() => setSelectedJob(job)}
                              title="View job details"
                              aria-label="View job details"
                            >
                              <ArrowRightFromLine aria-label="View" color="#222" />
                            </button>
                          </div>
                        </td>
                        <td className="redesigned-table__cell" data-label={t("table.headers.company")}>{job.company || "N/A"}</td>
                        <td className="redesigned-table__cell" data-label={t("table.headers.region")}>{job.region || "—"}</td>
                        <td className="redesigned-table__cell" data-label={t("table.headers.location")}>{job.location || "—"}</td>
                        <td className="redesigned-table__cell" data-label={t("table.headers.dateAdded")}>{job.dateAdded || "N/A"}</td>
                        <td className="redesigned-table__cell redesigned-table__cell--link" data-label={t("table.headers.linkToJob")}>
                          {job.link ? (
                            <a
                              href={job.link}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="redesigned-table__link-btn"
                            >
                              <LucideLink width={18} height={18} aria-label="Link" />
                              {t("table.linkToJob")}
                            </a>
                          ) : (
                            <span>—</span>
                          )}
                        </td>
                        <td className="redesigned-table__cell">
                          <button
                            className="redesigned-table__show-candidates-btn"
                            onClick={() => toggleJobExpansion(job.id)}
                          >
                            {isExpanded ? t("hideCandidates") : t("viewCandidates")} ({job.matchedCandidates.length})
                          </button>
                        </td>
                      </tr>
                      {isExpanded && (
                        <tr className="redesigned-table__expanded-row">
                          <td colSpan="9">
                            <CandidatesTable
                              candidates={job.matchedCandidates}
                              jobId={job.id}
                              onToggleMatchStatus={handleToggleMatchStatus}
                              onToggleRelevance={handleToggleRelevance}
                              onCandidateClick={setSelectedCandidate}
                              onDownloadCV={downloadCV}
                              changingMatches={changingMatches}
                              changingRelevance={changingRelevance}
                              getScoreColor={getScoreColor}
                              translateStatus={translateStatus}
                            />
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  );
                })
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Shared modals */}
      {selectedJob && (
        <JobDescriptionModal job={selectedJob} isOpen={!!selectedJob} onClose={() => setSelectedJob(null)} />
      )}

      {selectedCandidate && (
        <CandidateModal candidate={selectedCandidate} onClose={() => setSelectedCandidate(null)} />
      )}

      {/* Demo CV Download Modal */}
      {showDemoCVModal && (
        <div className="demo-cv-modal-overlay" onClick={() => setShowDemoCVModal(false)}>
          <div className="demo-cv-modal" onClick={e => e.stopPropagation()}>
            <h3 className="demo-cv-modal__title">{t("demoCVDownloadTitle")}</h3>
            <p className="demo-cv-modal__message">{t("demoCVDownloadMessage")}</p>
            <button className="demo-cv-modal__button" onClick={() => setShowDemoCVModal(false)}>
              {tCommon("ok")}
            </button>
          </div>
        </div>
      )}
    </>
  );
};

export default MatchesTableAdmin;
