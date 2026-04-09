import { SquareCheck, CloudDownload, ThumbsUp, ThumbsDown, ArrowRightFromLine } from "lucide-react";
import React from "react";

import { useTranslations } from "../../utils/translations";

const CandidatesTable = ({
  candidates,
  jobId,
  onToggleMatchStatus,
  onToggleRelevance,
  onCandidateClick,
  onDownloadCV,
  changingMatches,
  changingRelevance,
  getScoreColor,
  translateStatus
}) => {
  const { t } = useTranslations("matches");
  const [sortField, setSortField] = React.useState(null);
  const [sortDirection, setSortDirection] = React.useState("asc");

  const handleSort = field => {
    if (sortField === field) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortField(field);
      setSortDirection("asc");
    }
  };

  const getSortIcon = field => {
    if (sortField !== field) {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      );
    }
    if (sortDirection === "asc") {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      );
    }
    return (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    );
  };

  const renderSortableHeader = ({ field, label, sortable = true }) => {
    return (
      <th
        className={`redesigned-table__candidate-header ${
          sortable ? "redesigned-table__candidate-header--sortable" : ""
        } ${sortField === field ? "redesigned-table__candidate-header--sorted" : ""}`}
        onClick={() => sortable && handleSort(field)}
      >
        <div className="redesigned-table__header-content">
          <span>{label}</span>
          {sortable && (
            <span className="redesigned-table__sort-icon">{getSortIcon(field)}</span>
          )}
        </div>
      </th>
    );
  };

  const sortedCandidates = React.useMemo(() => {
    if (!sortField) {
      return candidates;
    }
    return [...candidates].sort((a, b) => {
      let aVal, bVal;
      if (sortField === "name") {
        aVal = a.name;
        bVal = b.name;
      } else if (sortField === "score") {
        aVal = parseFloat(a.score);
        bVal = parseFloat(b.score);
      } else if (sortField === "status") {
        aVal = a.status;
        bVal = b.status;
      } else {
        return 0;
      }

      if (typeof aVal === "string") {
        return sortDirection === "asc"
          ? aVal.localeCompare(bVal)
          : bVal.localeCompare(aVal);
      }
      return sortDirection === "asc" ? aVal - bVal : bVal - aVal;
    });
  }, [candidates, sortField, sortDirection]);

  return (
    <div className="redesigned-table__candidates-wrapper">
      <table className="redesigned-table__candidates">
        <thead>
          <tr>
            {renderSortableHeader({ field: "name", label: t("table.headers.candidateName") })}
            {renderSortableHeader({ field: "score", label: t("table.headers.matchScore") })}
            {renderSortableHeader({ field: "showMore", label: t("table.headers.showDetailedReport"), sortable: false })}
            {renderSortableHeader({ field: "cv", label: t("table.headers.downloadCV"), sortable: false })}
            {renderSortableHeader({ field: "mmr", label: t("table.headers.candidateMeetingMMR"), sortable: false })}
            {renderSortableHeader({ field: "relevant", label: t("table.headers.wasMatchRelevant"), sortable: false })}
            {renderSortableHeader({ field: "status", label: t("table.headers.appliedStatus") })}
            {renderSortableHeader({ field: "actions", label: t("table.headers.actions"), sortable: false })}
          </tr>
        </thead>
        <tbody>
          {sortedCandidates.map((candidate, index) => {
            const isChangingMatch = changingMatches.has(candidate._metadata.matchId);
            const isChangingRel = changingRelevance.has(candidate._metadata.matchId);
            const relevance = candidate.relevance || "neutral";

            return (
              <tr key={index} className="redesigned-table__candidate-row">
                <td className="redesigned-table__candidate-cell">
                  <span className="redesigned-table__candidate-name">
                    {candidate.name}
                  </span>
                </td>
                <td className="redesigned-table__candidate-cell">
                  <span
                    className="redesigned-table__score"
                    style={{ color: getScoreColor(candidate.score) }}
                  >
                    {candidate.score}
                  </span>
                </td>
                <td className="redesigned-table__candidate-cell">
                  <button
                    className="redesigned-table__view-btn"
                    onClick={() => onCandidateClick(candidate)}
                  >
                    <ArrowRightFromLine aria-label="Show Report" />
                    Show Report
                  </button>
                </td>
                <td className="redesigned-table__candidate-cell">
                  {candidate.cv && candidate.cvLink ? (
                    <button
                      className="redesigned-table__cv-btn"
                      onClick={() => onDownloadCV(candidate.cvLink, candidate.name)}
                    >
                      <CloudDownload aria-label="Download CV" />
                    </button>
                  ) : (
                    <span>—</span>
                  )}
                </td>
                <td className="redesigned-table__candidate-cell">
                  <span className={`redesigned-table__mmr-badge redesigned-table__mmr-badge--${candidate.mmr.toLowerCase()}`}>
                    {translateStatus(candidate.mmr)}
                  </span>
                </td>
                <td className="redesigned-table__candidate-cell">
                  <div className="redesigned-table__relevance-btns">
                    <button
                      className={`redesigned-table__relevance-btn thumbs-up ${relevance === "relevant" ? "active" : ""}`}
                      onClick={() => onToggleRelevance(jobId, candidate._metadata.matchId, relevance, true)}
                      disabled={isChangingRel}
                    >
                      <ThumbsUp aria-label="Relevant" />
                    </button>
                    <button
                      className={`redesigned-table__relevance-btn thumbs-down ${relevance === "irrelevant" ? "active" : ""}`}
                      onClick={() => onToggleRelevance(jobId, candidate._metadata.matchId, relevance, false)}
                      disabled={isChangingRel}
                    >
                      <ThumbsDown aria-label="Irrelevant" />
                    </button>
                  </div>
                </td>
                <td className="redesigned-table__candidate-cell">
                  <span className={`redesigned-table__status-badge redesigned-table__status-badge--${candidate.status}`}>
                    {isChangingMatch ? t("table.updating") : translateStatus(candidate.status)}
                  </span>
                </td>
                <td className="redesigned-table__candidate-cell">
                  <button
                    className={`redesigned-table__action-btn ${candidate.status === "sent" ? "redesigned-table__action-btn--revert" : ""}`}
                    onClick={() => onToggleMatchStatus(jobId, candidate._metadata.matchId, candidate.status)}
                    disabled={isChangingMatch}
                  >
                    <SquareCheck width={18} height={18} aria-label="Mark" />
                    {isChangingMatch
                      ? t("table.updating")
                      : candidate.status === "pending"
                        ? t("table.markAsSent")
                        : t("table.revertStatus")}
                  </button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default CandidatesTable;
