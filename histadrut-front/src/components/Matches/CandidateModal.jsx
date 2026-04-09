import React from "react";

import {
  getTextAlignment
} from "../../utils/languageDetection";
import { useTranslations } from "../../utils/translations";
import Modal from "../shared/Modal";
import "./CandidateModal.css";

const CandidateModal = ({ candidate, onClose }) => {
  const { t, currentLanguage } = useTranslations("modals");

  if (!candidate) {
    return null;
  }

  // Get the overview text and detect language
  const overviewText = candidate._metadata?.overview || t("candidateModal.noOverviewAvailable");
  const textAlignment = getTextAlignment(overviewText);

  return (
    <Modal
      key={currentLanguage}
      isOpen={!!candidate}
      onClose={onClose}
      title={candidate.name}
      className="candidate-modal"
    >
      {/* Place info bar inside sticky header wrap using a React fragment */}
      <React.Fragment>
        <div className="candidate-modal__info">
          <div className="candidate-modal__score">
            <strong>{t("candidateModal.matchScore")}:</strong> {candidate.score}
          </div>
          <div className="candidate-modal__mmr">
            <strong>{t("candidateModal.mmr")}:</strong> <span className={candidate.mmr === "YES" ? "candidate-modal__mmr-yes" : "candidate-modal__mmr-no"}>{candidate.mmr}</span>
          </div>
          {candidate._metadata?.createdAt && (
            <div className="candidate-modal__matched-at">
              <strong>{t("candidateModal.matchedAt")}:</strong> {new Date(candidate._metadata.createdAt).toLocaleString(currentLanguage === "he" ? "he-IL" : "en-CA")}
            </div>
          )}
        </div>
      </React.Fragment>

      <div className="candidate-modal__overview">
        <h3>{t("candidateModal.candidateOverview")}</h3>
        <div
          className="candidate-modal__overview-content"
          dir="auto"
          style={{
            textAlign: textAlignment
          }}
        >
          {overviewText}
        </div>
      </div>

      <div className="candidate-modal__strweak-flex">
        <div className="candidate-modal__strweak-section">
          <h3 className="candidate-modal__strweak-title">{t("candidateModal.strengths")}</h3>
          <div className="candidate-modal__strweak-content">
            {candidate._metadata?.strengths && candidate._metadata.strengths.length > 0 ? (
              <ul>
                {candidate._metadata.strengths.map((s, i) => (
                  <li key={i}>{s}</li>
                ))}
              </ul>
            ) : (
              <span>{t("candidateModal.noStrengthsListed")}</span>
            )}
          </div>
        </div>
        <div className="candidate-modal__strweak-section">
          <h3 className="candidate-modal__strweak-title">{t("candidateModal.weaknesses")}</h3>
          <div className="candidate-modal__strweak-content">
            {candidate._metadata?.weaknesses && candidate._metadata.weaknesses.length > 0 ? (
              <ul>
                {candidate._metadata.weaknesses.map((w, i) => (
                  <li key={i}>{w}</li>
                ))}
              </ul>
            ) : (
              <span>{t("candidateModal.noWeaknessesListed")}</span>
            )}
          </div>
        </div>
      </div>
    </Modal>
  );
};

export default CandidateModal;
