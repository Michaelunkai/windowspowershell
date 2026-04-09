import { SquareCheck, CloudDownload, Link as LucideLink, ThumbsUp, ThumbsDown, Copy, ArrowRightFromLine } from "lucide-react";
import React, { useState, useEffect } from "react";

import { setMatchSent, setMatchRelevant } from "../../api";
import { useAuth } from "../../hooks/useAuth";
import { useTranslations } from "../../utils/translations";
import JobDescriptionModal from "../shared/JobDescriptionModal";
import CandidateModal from "./CandidateModal";
import "./MatchesMobile.css";

const MatchesMobile = ({ jobs: initialJobs, loading, error }) => {
  const [jobs, setJobs] = useState(initialJobs);
  const [selectedJob, setSelectedJob] = useState(null);
  const [selectedCandidate, setSelectedCandidate] = useState(null);
  const [changingMatches, setChangingMatches] = useState(new Set());
  const [changingRelevance, setChangingRelevance] = useState(new Set());
  const [expandedJobIds, setExpandedJobIds] = useState(new Set());
  const [copiedId, setCopiedId] = useState(null);
  const { t, currentLanguage } = useTranslations("matches");
  const { isAdmin } = useAuth();
  const isUserAdmin = isAdmin();

  useEffect(() => {
    setJobs(initialJobs);
  }, [initialJobs]);

  const truncateJobId = jobId => {
    if (!jobId) return "";
    return jobId.length > 20 ? jobId.substring(0, 20) + "..." : jobId;
  };

  const handleCopyJobId = async (jobId, index) => {
    try {
      await navigator.clipboard.writeText(jobId);
      setCopiedId(index);
      setTimeout(() => setCopiedId(null), 2000);
    } catch (err) {
      console.error("Failed to copy job ID:", err);
    }
  };

  const toggleJobExpanded = jobId => {
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
    if (isNaN(numScore)) return "#666";
    if (numScore <= 6) return "#dc3545";
    if (numScore >= 8.5) return "#4caf50";
    return "#ff8c00";
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
          if (job.id !== jobId) return job;
          return {
            ...job,
            matchedCandidates: job.matchedCandidates.map(candidate =>
              candidate._metadata.matchId === matchId
                ? { ...candidate, status: newStatus }
                : candidate
            )
          };
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
      await setMatchRelevant(matchId, newRelevance);
      setJobs(prevJobs =>
        prevJobs.map(job => {
          if (job.id !== jobId) return job;
          return {
            ...job,
            matchedCandidates: job.matchedCandidates.map(candidate =>
              candidate._metadata.matchId === matchId
                ? { ...candidate, relevance: newRelevance }
                : candidate
            )
          };
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

  if (loading) {
    return (
      <div className="matches-mobile">
        <div className="matches-mobile__loading">{t("table.loading")}</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="matches-mobile">
        <div className="matches-mobile__error">{t("table.error")}: {error}</div>
      </div>
    );
  }

  if (jobs.length === 0) {
    return (
      <div className="matches-mobile">
        <div className="matches-mobile__empty">{t("table.noMatches")}</div>
      </div>
    );
  }

  return (
    <div className="matches-mobile" key={currentLanguage}>
      {jobs.map((job, jobIndex) => {
        const isExpanded = expandedJobIds.has(job.id);
        const candidateCount = job.matchedCandidates?.length || 0;

        return (
          <div key={`${jobIndex}_${job.id}`} className="match-card">
            <div className="match-card__header">
              <h3 className="match-card__title" onClick={() => setSelectedJob(job)}>
                {job.jobTitle}
              </h3>
            </div>

            <div className="match-card__info">
              <div className="match-card__detail">
                <span className="match-card__label">{t("table.headers.company")}:</span>
                <span className="match-card__value">{job.company}</span>
              </div>
              <div className="match-card__detail">
                <span className="match-card__label">{t("table.headers.region")}:</span>
                <span className="match-card__value">{job.region || "—"}</span>
              </div>
              <div className="match-card__detail">
                <span className="match-card__label">{t("table.headers.location")}:</span>
                <span className="match-card__value">{job.location || "—"}</span>
              </div>
              <div className="match-card__detail">
                <span className="match-card__label">{t("table.headers.dateAdded")}:</span>
                <span className="match-card__value">{job.dateAdded}</span>
              </div>
              <div className="match-card__detail match-card__detail--id">
                <span className="match-card__label">{t("table.headers.jobId")}:</span>
                <div className="match-card__id-wrapper">
                  <span className="match-card__id">{truncateJobId(job.job_id)}</span>
                  <button
                    className="match-card__copy-btn"
                    onClick={() => handleCopyJobId(job.job_id, jobIndex)}
                    aria-label={t("table.actions.copy") || "Copy Job ID"}
                  >
                    <Copy width={16} height={16} aria-hidden="true" />
                  </button>
                  {copiedId === jobIndex && (
                    <span className="match-card__copied-tooltip">Copied!</span>
                  )}
                </div>
              </div>
              {job.link && (
                <div className="match-card__detail">
                  <a
                    href={job.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="match-card__link-btn"
                  >
                    <LucideLink className="match-card__link-icon" aria-hidden="true" />
                    <span>{t("table.linkToJob")}</span>
                  </a>
                </div>
              )}
            </div>

            {/* Regular user: compact match info */}
            {!isUserAdmin && job.matchedCandidates.length > 0 && (() => {
              const candidate = job.matchedCandidates[0];
              const isChangingMatch = changingMatches.has(candidate._metadata.matchId);
              const isChangingRel = changingRelevance.has(candidate._metadata.matchId);
              const relevance = candidate.relevance || "neutral";

              return (
                <div className="match-card__user-section">
                  <div className="match-card__user-header">
                    <span
                      className="match-card__user-score"
                      style={{
                        backgroundColor: getScoreColor(candidate.score) + "20",
                        color: getScoreColor(candidate.score)
                      }}
                    >
                      {candidate.score}
                    </span>
                    <div className="match-card__user-badges">
                      <span className={`match-card__user-badge match-card__user-badge--mmr-${candidate.mmr.toLowerCase()}`}>
                        MMR: {translateStatus(candidate.mmr)}
                      </span>
                      <span className={`match-card__user-badge match-card__user-badge--status-${candidate.status}`}>
                        {isChangingMatch ? t("table.updating") : translateStatus(candidate.status)}
                      </span>
                    </div>
                  </div>

                  <div className="match-card__user-actions">
                    {candidate.cv && candidate.cvLink ? (
                      <button
                        className="match-card__user-action-btn"
                        onClick={e => { e.stopPropagation(); downloadCV(candidate.cvLink, candidate.name); }}
                        aria-label={t("table.downloadCV")}
                      >
                        <CloudDownload aria-hidden="true" />
                      </button>
                    ) : (
                      <button className="match-card__user-action-btn match-card__user-action-btn--disabled" disabled aria-label={t("table.cvNotAvailable") || "CV not available"}>
                        <CloudDownload style={{ opacity: 0.3 }} aria-hidden="true" />
                      </button>
                    )}
                    <button
                      className={`match-card__user-action-btn ${relevance === "relevant" ? "match-card__user-action-btn--active" : ""}`}
                      onClick={() => handleToggleRelevance(job.id, candidate._metadata.matchId, relevance, true)}
                      disabled={isChangingRel}
                      aria-label={t("table.relevant") || "Relevant"}
                    >
                      <ThumbsUp aria-hidden="true" />
                    </button>
                    <button
                      className={`match-card__user-action-btn ${relevance === "irrelevant" ? "match-card__user-action-btn--active" : ""}`}
                      onClick={() => handleToggleRelevance(job.id, candidate._metadata.matchId, relevance, false)}
                      disabled={isChangingRel}
                      aria-label={t("table.irrelevant") || "Irrelevant"}
                    >
                      <ThumbsDown aria-hidden="true" />
                    </button>
                    <button
                      className={`match-card__user-action-btn match-card__user-action-btn--sent ${candidate.status === "sent" ? "match-card__user-action-btn--revert" : ""}`}
                      onClick={() => handleToggleMatchStatus(job.id, candidate._metadata.matchId, candidate.status)}
                      disabled={isChangingMatch}
                      aria-label={candidate.status === "sent" ? t("table.revertStatus") : t("table.markAsSent")}
                    >
                      <SquareCheck width={18} height={18} aria-hidden="true" />
                    </button>
                  </div>

                  <button className="match-card__user-view-btn" onClick={() => setSelectedCandidate(candidate)}>
                    {t("table.viewDetails")}
                  </button>
                </div>
              );
            })()}

            {/* Admin: expandable candidates list */}
            {isUserAdmin && (
              <>
                <button
                  className={`match-card__toggle ${isExpanded ? "match-card__toggle--expanded" : ""}`}
                  onClick={() => toggleJobExpanded(job.id)}
                >
                  <span>
                    {isExpanded ? t("hideCandidates") : `${t("viewCandidates")} (${candidateCount})`}
                  </span>
                  <svg
                    width="16" height="16" viewBox="0 0 16 16" fill="none"
                    className={`match-card__toggle-icon ${isExpanded ? "match-card__toggle-icon--rotated" : ""}`}
                    aria-hidden="true"
                  >
                    <path d="M4 6L8 10L12 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </button>

                {isExpanded && (
                  <div className="match-card__candidates">
                    {job.matchedCandidates.map((candidate, candidateIndex) => {
                      const isChangingMatch = changingMatches.has(candidate._metadata.matchId);
                      const isChangingRel = changingRelevance.has(candidate._metadata.matchId);
                      const relevance = candidate.relevance || "neutral";

                      return (
                        <div key={candidateIndex} className="candidate-card">
                          <div className="candidate-card__header">
                            <div className="candidate-card__name-container">
                              <h4 className="candidate-card__name" onClick={() => setSelectedCandidate(candidate)}>
                                {candidate.name}
                              </h4>
                              <button
                                className="candidate-card__action-btn candidate-details-btn--mobile"
                                onClick={() => setSelectedCandidate(candidate)}
                                aria-label={t("table.viewDetails")}
                              >
                                <ArrowRightFromLine aria-hidden="true" />
                              </button>
                            </div>
                            <span className="candidate-card__score" style={{ color: getScoreColor(candidate.score) }}>
                              {candidate.score}
                            </span>
                          </div>

                          <div className="candidate-card__info">
                            <div className="candidate-card__badges">
                              <span className={`candidate-card__badge candidate-card__badge--mmr candidate-card__badge--mmr-${candidate.mmr.toLowerCase()}`}>
                                MMR: {translateStatus(candidate.mmr)}
                              </span>
                              <span className={`candidate-card__badge candidate-card__badge--status candidate-card__badge--status-${candidate.status}`}>
                                {isChangingMatch ? t("table.updating") : translateStatus(candidate.status)}
                              </span>
                            </div>

                            <div className="candidate-card__actions">
                              {candidate.cv && candidate.cvLink ? (
                                <button
                                  className="candidate-card__action-btn candidate-card__action-btn--cv"
                                  onClick={e => { e.stopPropagation(); downloadCV(candidate.cvLink, candidate.name); }}
                                  aria-label={t("table.downloadCVFor", { name: candidate.name })}
                                >
                                  <CloudDownload aria-hidden="true" />
                                </button>
                              ) : (
                                <button className="candidate-card__action-btn candidate-card__action-btn--disabled" disabled aria-label={t("table.cvNotAvailable") || "CV not available"}>
                                  <CloudDownload style={{ opacity: 0.3 }} aria-hidden="true" />
                                </button>
                              )}
                              <button
                                className={`candidate-card__action-btn candidate-card__action-btn--relevance ${relevance === "relevant" ? "candidate-card__action-btn--active" : ""}`}
                                onClick={() => handleToggleRelevance(job.id, candidate._metadata.matchId, relevance, true)}
                                disabled={isChangingRel}
                                aria-label={t("table.relevant") || "Relevant"}
                              >
                                <ThumbsUp aria-hidden="true" />
                              </button>
                              <button
                                className={`candidate-card__action-btn candidate-card__action-btn--relevance ${relevance === "irrelevant" ? "candidate-card__action-btn--active" : ""}`}
                                onClick={() => handleToggleRelevance(job.id, candidate._metadata.matchId, relevance, false)}
                                disabled={isChangingRel}
                                aria-label={t("table.irrelevant") || "Irrelevant"}
                              >
                                <ThumbsDown aria-hidden="true" />
                              </button>
                              <button
                                className={`candidate-card__action-btn candidate-card__action-btn--sent ${candidate.status === "sent" ? "candidate-card__action-btn--revert" : ""}`}
                                onClick={() => handleToggleMatchStatus(job.id, candidate._metadata.matchId, candidate.status)}
                                disabled={isChangingMatch}
                                aria-label={candidate.status === "sent" ? t("table.revertStatus") : t("table.markAsSent")}
                              >
                                <SquareCheck width={18} height={18} aria-hidden="true" />
                                <span className="candidate-card__action-text">
                                  {isChangingMatch
                                    ? t("table.updating")
                                    : candidate.status === "pending"
                                      ? t("table.markAsSent")
                                      : t("table.revertStatus")}
                                </span>
                              </button>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </>
            )}
          </div>
        );
      })}

      {selectedJob && (
        <JobDescriptionModal job={selectedJob} isOpen={!!selectedJob} onClose={() => setSelectedJob(null)} />
      )}
      {selectedCandidate && (
        <CandidateModal candidate={selectedCandidate} onClose={() => setSelectedCandidate(null)} />
      )}
    </div>
  );
};

export default MatchesMobile;
