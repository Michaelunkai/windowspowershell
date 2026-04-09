import React from "react";
import { useNavigate } from "react-router-dom";

import { uploadJobDetails } from "../../api";
import { useLanguage } from "../../contexts/LanguageContext";
import "../shared/ConfirmationModal.css";
import { useTranslations } from "../../utils/translations";
import ConfirmationModal from "../shared/ConfirmationModal";
import JobForm from "./JobForm";

export default function AddJob() {
  const { t } = useTranslations("addJob");
  const { currentLanguage } = useLanguage();
  const navigate = useNavigate();
  const [modalOpen, setModalOpen] = React.useState(false);
  const [modalMessage, setModalMessage] = React.useState("");

  const handleCancel = () => {
    navigate("/jobs");
  };

  const handleSubmit = async formData => {
    try {
      const response = await uploadJobDetails(formData);
      setModalMessage(response.message || t("successModal.message"));
      setModalOpen(true);
    } catch (error) {
      alert(error.message || t("errors.failedToAdd"));
    }
  };

  const handleModalClose = () => {
    setModalOpen(false);
    navigate("/jobs");
  };

  return (
    <div key={`addJob-${currentLanguage}`} className="add-job-page">
      <JobForm
        onSubmit={handleSubmit}
        onCancel={handleCancel}
        submitLabel={t("actions.submit")}
        pageTitle={t("title")}
      />
      <ConfirmationModal
        isOpen={modalOpen}
        onClose={handleModalClose}
        title={t("successModal.title")}
        message={modalMessage}
        buttonText="OK"
      />
    </div>
  );
}
