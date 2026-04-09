import { SquareCheck, ThumbsUp, ThumbsDown, Download, Link, BookOpenText } from "lucide-react";
import React, { useState, useEffect } from "react";

import { setMatchSent, setMatchRelevant } from "../../api";
import { useAuth } from "../../hooks/useAuth";
import { useTranslations } from "../../utils/translations";
import InfoTooltip from "../shared/InfoTooltip";
import JobDescriptionModal from "../shared/JobDescriptionModal";
import TruncatedText from "../shared/TruncatedText";
import CandidateModal from "./CandidateModal";

const MatchesTable = ({ jobs: initialJobs, allJobs = [], loading, error, sortField, sortDirection, onSort }) => {
  const [jobs, setJobs] = useState(initialJobs);
  const [selectedJob, setSelectedJob] = useState(null);
  const [selectedCandidate, setSelectedCandidate] = useState(null);
  const [changingMatches, setChangingMatches] = useState(new Set());
  const [changingRelevance, setChangingRelevance] = useState(new Set());
  const { t, currentLanguage } = useTranslations("matches");
  const { t: tCommon } = useTranslations("common");
  const { isAdmin } = useAuth();
  const isUserAdmin = isAdmin();

  // Sort icons component
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

  // Sortable header component
  const SortableHeader = ({ field, children, sortable = true }) => {
    const handleClick = () => {
      if (sortable && onSort) {
        onSort(field);
      }
    };

    return (
      <th
        className={`match-table__cell match-table__cell--header ${
          sortable ? "match-table__cell--sortable" : ""
        } ${sortField === field ? "match-table__cell--sorted" : ""}`}
        onClick={handleClick}
      >
        <div className="match-table__header-content">
          <span>{children}</span>
          {sortable && (
            <span className="match-table__sort-icon">{getSortIcon(field)}</span>
          )}
        </div>
      </th>
    );
  };

  // Function to get score color based on value
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

    const isHighScore = numScore >= 8.5;
    if (isHighScore) {
      // noinspection UnnecessaryLocalVariableJS
      const green = "#4caf50";
      return green;
    }

    // Medium score 6-8.5
    // noinspection UnnecessaryLocalVariableJS
    const orange = "#ff8c00";
    return orange;
  };

  // Function to translate status values
  const translateStatus = status => {
    const statusMap = {
      YES: t("table.statusValues.yes"),
      NO: t("table.statusValues.no"),
      pending: t("table.statusValues.pending"),
      sent: t("table.statusValues.sent")
    };
    return statusMap[status] || status;
  };

  useEffect(() => {
    setJobs(initialJobs);
  }, [initialJobs]);

  const handleToggleMatchStatus = async (jobId, matchId, currentStatus) => {
    // Add this match to the changing set
    setChangingMatches(prev => new Set([...prev, matchId]));

    try {
      const newStatus = currentStatus === "pending" ? "sent" : "pending";
      await setMatchSent(matchId, newStatus);

      // Only update the local state after successful API response
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
      // Error is already shown to user via alert
      alert("Failed to update match status. Please try again.");
    } finally {
      // Remove this match from the changing set
      setChangingMatches(prev => {
        const newSet = new Set(prev);
        newSet.delete(matchId);
        return newSet;
      });
    }
  };

  const handleToggleRelevance = async (jobId, matchId, currentRelevance, isThumbsUp) => {
    // Add this match to the changing relevance set
    setChangingRelevance(prev => new Set([...prev, matchId]));

    try {
      let newRelevance;

      if (isThumbsUp) {
        // Thumbs up logic: neutral -> relevant -> neutral
        newRelevance = currentRelevance === "relevant" ? "neutral" : "relevant";
      } else {
        // Thumbs down logic: neutral -> irrelevant -> neutral
        newRelevance = currentRelevance === "irrelevant" ? "neutral" : "irrelevant";
      }

      await setMatchRelevant(matchId, newRelevance);

      // Only update the local state after successful API response
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
      // Error is already shown to user via alert
      alert("Failed to update match relevance. Please try again.");
    } finally {
      // Remove this match from the changing relevance set
      setChangingRelevance(prev => {
        const newSet = new Set(prev);
        newSet.delete(matchId);
        return newSet;
      });
    }
  };

  if (loading) {
    return (
      <div className="match-table">
        <div className="match-table__loading">Loading matches...</div>
      </div>
    );
  }

  // If there is an error, but allJobs is empty and loading is false, show no matches message instead of error
  if (error && !(Array.isArray(allJobs) && allJobs.length === 0 && !loading)) {
    return (
      <div className="match-table">
        <div className="match-table__error">Error loading matches: {error}</div>
      </div>
    );
  }

  const downloadCV = (cvLink, candidateName) => {
    if (cvLink) {
      // Create a temporary anchor element to trigger download
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

  const handleJobClick = job => {
    setSelectedJob(job);
  };

  const handleCandidateClick = candidate => {
    setSelectedCandidate(candidate);
  };

  const handleCloseJobModal = () => {
    setSelectedJob(null);
  };

  const handleCloseCandidateModal = () => {
    setSelectedCandidate(null);
  };

  return (
    <div className="match-table" key={currentLanguage}>
      <table className="match-table__table">
        <thead className="match-table__header">
          <tr>
            <SortableHeader field="job_id">
              {t("table.headers.jobId")}
            </SortableHeader>
            <SortableHeader field="job_title">
              {t("table.headers.jobTitle")}
            </SortableHeader>
            <SortableHeader field="company">
              {t("table.headers.company")}
            </SortableHeader>
            <SortableHeader field="region" sortable={false}>
              {t("table.headers.region")}
            </SortableHeader>
            <SortableHeader field="location" sortable={false}>
              {t("table.headers.location")}
            </SortableHeader>
            <SortableHeader field="dateAdded" sortable={false}>
              {t("table.headers.dateAdded")}
            </SortableHeader>
            <SortableHeader field="linkToJob" sortable={false}>
              {t("table.headers.linkToJob")}
            </SortableHeader>
            <SortableHeader field="matchedCandidates" sortable={false}>
              {t("table.headers.matchedCandidates")}
            </SortableHeader>
            <SortableHeader field="score" sortable={false}>
              <span className="match-table__cell--scores">{t("table.headers.score")}</span>
            </SortableHeader>
            <SortableHeader field="cv" sortable={false}>
              {t("table.headers.cv")}
            </SortableHeader>
            <SortableHeader field="mmr" sortable={false}>
              {t("table.headers.mmr")}
              <InfoTooltip text={t("table.tooltips.mmr")} isAdmin={isUserAdmin} />
            </SortableHeader>
            <SortableHeader field="relevant" sortable={false}>
              {t("table.headers.relevant")}
              <InfoTooltip text={t("table.tooltips.relevant")} isAdmin={isUserAdmin} />
            </SortableHeader>
            <SortableHeader field="appliedStatus" sortable={false}>
              {t("table.headers.appliedStatus")}
              <InfoTooltip text={t("table.tooltips.appliedStatus")} isAdmin={isUserAdmin} />
            </SortableHeader>
            <SortableHeader field="actions" sortable={false}>
              {t("table.headers.actions")}
            </SortableHeader>
          </tr>
        </thead>
        <tbody>
          {jobs.length === 0 && !loading ? (
            <tr>
              <td colSpan="12" className="match-table__empty">
                {Array.isArray(allJobs) && allJobs.length === 0 && error
                  ? error
                  : Array.isArray(allJobs) && allJobs.length === 0
                    ? t("table.noMatches")
                    : t("table.noMatchesFiltered")}
              </td>
            </tr>
          ) : (
            jobs.map((job, index) => (
              <tr key={`${index}_${job.id || "NA"}_${job.company || "unknown"}`} className="match-table__row">
                <td className="match-table__cell match-table__cell--job-id">
                  <TruncatedText
                    text={job.job_id || ""}
                    maxWidth="100px"
                    className="job-id-truncated"
                    copyable={true}
                  />
                </td>
                <td className="match-table__cell match-table__cell--match-title">
                  <span
                    className="match-table__title match-table__title--clickable"
                    onClick={() => handleJobClick(job)}
                    title={t("table.viewJob")}
                  >
                    {job.jobTitle}
                  </span>
                </td>
                <td className="match-table__cell">{job.company}</td>
                <td className="match-table__cell">{job.region || "—"}</td>
                <td className="match-table__cell">{job.location || "—"}</td>
                <td className="match-table__cell">{job.dateAdded}</td>
                <td className="match-table__cell match-table__cell--link">
                  {job.link ? (
                    <a
                      href={job.link}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="job-link-btn"
                      title={t("table.viewJob")}
                      aria-label={t("table.viewJob")}
                    >
                      <Link className="job-link-icon" aria-label="Link, external link" />
                      <span className="job-link-text">{t("table.linkToJob")}</span>
                    </a>
                  ) : (
                    <span
                      className="job-link-unavailable"
                      title={t("table.jobLinkNotAvailable")}
                    >
                      —
                    </span>
                  )}
                </td>
                <td className="match-table__cell match-table__cell--candidates">
                  {job.matchedCandidates.map((candidate, index) => (
                    <div className="candidate-info-item" key={index}>
                      <span
                        className="candidate-match__name candidate-match__name--clickable"
                        onClick={() => handleCandidateClick(candidate)}
                        title={t("table.viewCandidate")}
                      >
                        {candidate.name}
                      </span>
                      <button
                        className="candidate-details-btn"
                        onClick={() => handleCandidateClick(candidate)}
                        title={t("table.viewDetails")}
                        aria-label={t("table.viewDetails")}
                      >
                        <BookOpenText className="candidate-details-icon" aria-label="View details" />
                      </button>
                    </div>
                  ))}
                </td>
                <td className="match-table__cell match-table__cell--scores">
                  {job.matchedCandidates.map((candidate, index) => (
                    <div className="candidate-info-item" key={index}>
                      <span
                        className="candidate-match__score"
                        style={{
                          color: getScoreColor(candidate.score),
                          fontWeight: "800"
                        }}
                      >
                        {candidate.score}
                      </span>
                    </div>
                  ))}
                </td>
                <td className="match-table__cell match-table__cell--cv">
                  {job.matchedCandidates.map((candidate, index) => (
                    <div className="candidate-info-item" key={index}>
                      {candidate.cv && candidate.cvLink ? (
                        <button
                          className="cv-download-btn"
                          onClick={e => {
                            e.stopPropagation();
                            downloadCV(candidate.cvLink, candidate.name);
                          }}
                          title={t("table.downloadCVFor", { name: candidate.name })}
                          aria-label={t("table.downloadCVFor", { name: candidate.name })}
                        >
                          <Download className="cv-download-icon" aria-hidden="true" />
                        </button>
                      ) : (
                        <span
                          className="cv-not-available"
                          title={t("table.cvNotAvailable")}
                        >
                          —
                        </span>
                      )}
                    </div>
                  ))}
                </td>
                <td className="match-table__cell match-table__cell--mmr">
                  {job.matchedCandidates.map((candidate, index) => (
                    <div className="candidate-info-item" key={index}>
                      <span
                        className={`mmr-badge ${
                          candidate.mmr === "YES"
                            ? "mmr-badge--yes"
                            : "mmr-badge--no"
                        }`}
                      >
                        {translateStatus(candidate.mmr)}
                      </span>
                    </div>
                  ))}
                </td>
                <td className="match-table__cell match-table__cell--relevance">
                  {job.matchedCandidates.map((candidate, index) => {
                    const isChangingRelevance = changingRelevance.has(candidate._metadata.matchId);
                    const relevance = candidate.relevance || "neutral";

                    return (
                      <div className="candidate-info-item relevance-controls" key={index}>
                        <button
                          className={`relevance-btn thumbs-up-btn ${
                            relevance === "relevant" ? "relevance-btn--active" : ""
                          }`}
                          onClick={() =>
                            handleToggleRelevance(
                              job.id,
                              candidate._metadata.matchId,
                              relevance,
                              true
                            )
                          }
                          disabled={isChangingRelevance}
                          title={
                            isChangingRelevance
                              ? tCommon("updating")
                              : relevance === "relevant"
                                ? t("table.relevanceActions.markNeutral")
                                : t("table.relevanceActions.markRelevant")
                          }
                        >
                          <ThumbsUp className="relevance-icon" aria-label="Thumbs up" />
                        </button>
                        <button
                          className={`relevance-btn thumbs-down-btn ${
                            relevance === "irrelevant" ? "relevance-btn--active" : ""
                          }`}
                          onClick={() =>
                            handleToggleRelevance(
                              job.id,
                              candidate._metadata.matchId,
                              relevance,
                              false
                            )
                          }
                          disabled={isChangingRelevance}
                          title={
                            isChangingRelevance
                              ? tCommon("updating")
                              : relevance === "irrelevant"
                                ? t("table.relevanceActions.markNeutral")
                                : t("table.relevanceActions.markIrrelevant")
                          }
                        >
                          <ThumbsDown className="relevance-icon" aria-label="Thumbs down" />
                        </button>
                      </div>
                    );
                  })}
                </td>
                <td className="match-table__cell match-table__cell--status">
                  {job.matchedCandidates.map((candidate, index) => (
                    <div className="candidate-info-item" key={index}>
                      <span
                        className={`status-badge ${
                          changingMatches.has(candidate._metadata.matchId)
                            ? "status-badge--changing"
                            : `status-badge--${candidate.status}`
                        }`}
                      >
                        {changingMatches.has(candidate._metadata.matchId)
                          ? t("table.updating")
                          : translateStatus(candidate.status)}
                      </span>
                    </div>
                  ))}
                </td>
                <td className="match-table__cell match-table__cell--actions">
                  {job.matchedCandidates.map((candidate, index) => {
                    const isChanging = changingMatches.has(candidate._metadata.matchId);
                    return (
                      <div className="candidate-info-item" key={index}>
                        <button
                          className={`action-btn mark-as-sent-btn ${
                            candidate.status === "sent" ? "action-btn--revert" : ""
                          }`}
                          onClick={() =>
                            handleToggleMatchStatus(
                              job.id,
                              candidate._metadata.matchId,
                              candidate.status
                            )
                          }
                          disabled={isChanging}
                          title={
                            isChanging
                              ? tCommon("updating")
                              : candidate.status === "pending"
                                ? t("table.markAsSent")
                                : t("table.markAsPending")
                          }
                        >
                          <SquareCheck
                            aria-label={
                              isChanging
                                ? tCommon("updating")
                                : candidate.status === "pending"
                                  ? t("table.markAsSent")
                                  : t("table.markAsPending")
                            }
                            className={`action-icon ${
                              candidate.status === "sent"
                                ? "action-icon--sent"
                                : ""
                            }`}
                            width={18}
                            height={18}
                          />
                          <span className="action-btn-text">
                            {isChanging
                              ? t("table.updating")
                              : candidate.status === "pending"
                                ? t("table.markAsSent")
                                : t("table.revertStatus")}
                          </span>
                        </button>
                      </div>
                    );
                  })}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      {selectedJob && (
        <JobDescriptionModal job={selectedJob} isOpen={!!selectedJob} onClose={handleCloseJobModal} />
      )}

      {selectedCandidate && (
        <CandidateModal
          candidate={selectedCandidate}
          onClose={handleCloseCandidateModal}
        />
      )}
    </div>
  );
};

export default MatchesTable;
