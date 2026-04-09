import React from "react";

import { getTextAlignment } from "../../utils/languageDetection";
import { useTranslations } from "../../utils/translations";
import Modal from "../shared/Modal";
import "./JobDescriptionModal.css";

/**
 * Unified Job Description Modal for both Matches and Job Listings
 * @param {object} props
 * @param {object} props.job - The job object (supports both Matches and JobListings shape)
 * @param {boolean} props.isOpen - Whether the modal is open
 * @param {function} props.onClose - Close handler
 */
const JobDescriptionModal = ({ job, isOpen, onClose }) => {
  const { t, currentLanguage } = useTranslations("modals");

  if (!isOpen || !job) {
    return null;
  }

  // Support both jobDescription/job.job_description and jobTitle/job.title
  const description = job.jobDescription || job.job_description || t("jobDescriptionModal.noDescriptionAvailable");
  const title = job.jobTitle || job.title || t("jobDescriptionModal.jobDetails");
  const company = job.company || "";
  const dateAdded = job.dateAdded || job.posted || job.discovered || "";

  // Handle array or string description
  const getDescription = desc => {
    if (Array.isArray(desc)) {
      return desc[0] || t("jobDescriptionModal.noDescriptionAvailable");
    }
    return desc || t("jobDescriptionModal.noDescriptionAvailable");
  };
  const jobDescription = getDescription(description);
  const textAlignment = getTextAlignment(jobDescription);

  return (
    <Modal
      key={currentLanguage}
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      className="job-modal"
    >
      <div className="job-modal__info">
        {company && (
          <div className="job-modal__company">
            <strong>{t("jobDescriptionModal.company")}:</strong> {company}
          </div>
        )}
        {dateAdded && (
          <div className="job-modal__date">
            <strong>{t("jobDescriptionModal.dateAdded")}:</strong> {dateAdded}
          </div>
        )}
      </div>
      <div className="job-modal__description">
        <h3>{t("jobDescriptionModal.jobDescription")}</h3>
        <div
          className="job-modal__description-content"
          dir="auto"
          style={{ textAlign: textAlignment }}
        >
          {jobDescription}
        </div>
      </div>
    </Modal>
  );
};

export default JobDescriptionModal;
