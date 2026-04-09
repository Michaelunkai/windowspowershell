import { CloudUpload } from "lucide-react";
import React, { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import { uploadCV } from "../../api";
import "./CVUpload.css";
import { useTranslations } from "../../utils/translations";

const CVUpload = () => {
  const [file, setFile] = useState(null);
  const [isDragOver, setIsDragOver] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showSuccess, setShowSuccess] = useState(false);

  const { t, currentLanguage } = useTranslations("cvUpload");
  const location = useLocation();
  const navigate = useNavigate();

  const handleFileSelect = selectedFile => {
    if (selectedFile) {
      if (
        selectedFile.type === "application/pdf" ||
        selectedFile.type === "application/msword" ||
        selectedFile.type ===
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ) {
        setFile(selectedFile);
        setError("");
      } else {
        setError(t("errors.invalidFileType"));
      }
    }
  };

  const handleFileChange = e => {
    const selectedFile = e.target.files[0];
    handleFileSelect(selectedFile);
  };

  const handleDragOver = e => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleDragLeave = e => {
    e.preventDefault();
    setIsDragOver(false);
  };

  const handleDrop = e => {
    e.preventDefault();
    setIsDragOver(false);
    const droppedFile = e.dataTransfer.files[0];
    handleFileSelect(droppedFile);
  };

  const handleSubmit = async e => {
    e.preventDefault();
    if (!file) {
      setError(t("errors.noFileSelected"));
      return;
    }

    setLoading(true);
    setError("");

    try {
      await uploadCV(file);
      setShowSuccess(true);
      setFile(null);
    } catch (err) {
      setError(err.message || t("errors.uploadError"));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={`cv-upload-page ${currentLanguage === "he" ? "rtl" : "ltr"}`}>
      <div className="cv-upload-container">
        {showSuccess && (
          <div className="cv-upload-modal-overlay">
            <div className="cv-upload-modal">
              <div className="cv-upload-modal-icon">✔️</div>
              <div className="cv-upload-modal-title">{t("successTitle")}</div>
              <div className="cv-upload-modal-desc">{t("successMessage")}</div>
              <button
                className="cv-upload-modal-btn"
                onClick={() => {
                  if (location.state?.fromProfile) {
                    navigate("/profile");
                  } else {
                    // User came from signup, go to matches
                    navigate("/user/matches");
                  }
                }}
              >
                {t("okButton")}
              </button>
            </div>
          </div>
        )}
        <h1 className="cv-upload-title">{t("title")}</h1>
        <p className="cv-upload-subtitle">{t("subtitle")}</p>
        <p className="cv-upload-desc" dangerouslySetInnerHTML={{
          __html: t("description").replace(t("startingTomorrow"), `<strong>${t("startingTomorrow")}</strong>`)
        }} />
        <form
          onSubmit={handleSubmit}
          className="cv-upload-form"
        >
          {error && <div className="error-message">{error}</div>}
          <div
            className={`cv-drop-zone ${isDragOver ? "drag-over" : ""} ${
              file ? "has-file" : ""
            }`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            {file ? (
              <div className="file-selected">
                <div className="file-icon">📄</div>
                <div className="file-info">
                  <p className="file-name">{file.name}</p>
                  <p className="file-size">{(file.size / 1024 / 1024).toFixed(2)} MB</p>
                </div>
                <button
                  type="button"
                  onClick={() => setFile(null)}
                  className="remove-file-btn"
                >
                  {t("remove")}
                </button>
              </div>
            ) : (
              <div className="drop-zone-content">
                <div className="upload-icon">
                  <CloudUpload size={48} aria-label={t("uploadYourResume")} />
                </div>
                <div className="drop-zone-title">{t("uploadYourResume")}</div>
                <div className="drop-zone-instructions">
                  {t("dragAndDropInstructions")}{" "}
                  <label htmlFor="cv-file" className="file-select-btn">
                    {t("clickToBrowse")}
                  </label>
                </div>
                <div className="drop-zone-help">{t("supportedFormats")}</div>
              </div>
            )}
            <input
              type="file"
              id="cv-file"
              accept=".pdf,.doc,.docx"
              onChange={handleFileChange}
              className="file-input"
            />
          </div>
          <div className="cv-upload-actions">
            {location.state?.fromProfile ? (
              <button
                type="button"
                onClick={() => navigate(-1)}
                className="cv-upload-back-btn"
              >
                {t("back")}
              </button>
            ) : (
              <button
                type="button"
                onClick={() => navigate("/matches")}
                className="cv-upload-back-btn"
              >
                {t("uploadLater")}
              </button>
            )}
            <button
              type="submit"
              className="upload-button"
              disabled={!file || loading}
            >
              {loading ? t("uploading") : t("uploadButton")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CVUpload;
