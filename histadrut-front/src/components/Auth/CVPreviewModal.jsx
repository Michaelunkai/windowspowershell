import { X, Download, FileText, Loader } from "lucide-react";
import React, { useState, useEffect } from "react";

import { API_BASE_URL } from "../../utils/config";
import { useTranslations } from "../../utils/translations";
import Modal from "../shared/Modal";
import "./CVPreviewModal.css";

const CVPreviewModal = ({ user, isOpen, onClose }) => {
  const { t } = useTranslations("users");
  const [loading, setLoading] = useState(true);
  const [pdfUrl, setPdfUrl] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!isOpen || !user) {
      return;
    }

    // Debug: Log the entire user object and cv_id
    console.log("=== CV MODAL DEBUG ===");
    console.log("Full User Object:", user);
    console.log("cv_id value:", user.cv_id);
    console.log("cv_id type:", typeof user.cv_id);
    console.log("cv_status:", user.cv_status);
    console.log("email:", user.email);
    console.log("name:", user.name);

    // More lenient check - just needs to be a non-empty string
    const hasValidCvId = user.cv_id &&
      typeof user.cv_id === "string" &&
      user.cv_id.trim().length > 0 &&
      user.cv_id !== "null" &&
      user.cv_id !== "None" &&
      user.cv_id !== "undefined" &&
      user.cv_id !== "NA";

    console.log("hasValidCvId:", hasValidCvId);

    if (hasValidCvId) {
      console.log("✓ CV ID is valid, loading CV...");
      setLoading(true);
      setError(null);
      // Build the CV URL using the backend endpoint with full API base URL
      // Use mode=inline for iframe viewing
      // Backend will auto-convert DOCX/DOC/RTF/TXT/HTML/ODT/JPG/PNG to PDF
      const cvUrl = `${API_BASE_URL}/s3_get_cv?id=${user.cv_id}&mode=inline`;
      console.log("CV URL:", cvUrl);
      setPdfUrl(cvUrl);
      setLoading(false);
    } else {
      console.log("✗ CV ID is INVALID");
      console.log("Validation details:");
      console.log("  cv_id exists?", !!user.cv_id);
      console.log("  is string?", typeof user.cv_id === "string");
      if (user.cv_id) {
        console.log("  length:", String(user.cv_id).length);
        console.log("  trimmed length:", String(user.cv_id).trim().length);
        console.log("  equals \"null\"?", user.cv_id === "null");
        console.log("  equals \"None\"?", user.cv_id === "None");
      }
      console.log("======================");
      setError("CV not available for this user");
      setLoading(false);
      setPdfUrl(null);
    }
  }, [isOpen, user]);

  const handleDownload = () => {
    if (!user || !user.cv_id) {
      return;
    }

    // Create a temporary link to trigger download with mode=download
    const link = document.createElement("a");
    link.href = `${API_BASE_URL}/s3_get_cv?id=${user.cv_id}&mode=download`;
    link.download = `${user.name.replace(/\s+/g, "_")}_CV.pdf`;
    link.target = "_blank";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (!isOpen || !user) {
    return null;
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title=""
      maxWidth="90vw"
      className="cv-preview-modal"
      xOnlyHeader={true}
    >
      <div className="cv-preview-modal__container">
        {/* Custom Header */}
        <div className="cv-preview-modal__header">
          <div className="cv-preview-modal__header-info">
            <div className="cv-preview-modal__icon">
              <FileText size={20} />
            </div>
            <div>
              <h3 className="cv-preview-modal__title">{user.name}'s CV</h3>
              <p className="cv-preview-modal__subtitle">{user.email}</p>
            </div>
          </div>
          <div className="cv-preview-modal__actions">
            <button
              onClick={handleDownload}
              className="cv-preview-modal__download-btn"
              title={t("cvModal.download")}
            >
              <Download size={16} />
              {t("cvModal.download")}
            </button>
          </div>
        </div>

        {/* PDF Viewer */}
        <div className="cv-preview-modal__content">
          {error ? (
            <div className="cv-preview-modal__error">
              <FileText size={48} style={{ opacity: 0.3 }} />
              <p>{error}</p>
              <p style={{ fontSize: "0.875rem", color: "#9ca3af", marginTop: "0.5rem" }}>
                Check browser console for details
              </p>
            </div>
          ) : loading ? (
            <div className="cv-preview-modal__loading">
              <Loader className="cv-preview-modal__spinner" size={40} />
              <p>{t("cvModal.loading")}</p>
            </div>
          ) : (
            <iframe
              src={pdfUrl}
              className="cv-preview-modal__iframe"
              title={`${user.name} CV`}
              onLoad={e => {
                // Check if iframe loaded successfully
                try {
                  const iframe = e.target;
                  const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;

                  // Check if it's an error page (JSON response)
                  if (iframeDoc.contentType === "application/json") {
                    try {
                      const errorData = JSON.parse(iframeDoc.body.textContent);
                      setError(errorData.message || errorData.error || "Failed to load CV");
                      setLoading(false);
                    } catch (parseErr) {
                      // Not JSON, probably loaded successfully
                      console.log("CV loaded successfully");
                    }
                  }
                } catch (err) {
                  // Cross-origin iframe - can't access content, assume success
                  console.log("Iframe loaded (cross-origin)");
                }
              }}
              onError={e => {
                console.error("Iframe loading error:", e);
                setError("Failed to load CV. The file may be corrupted or inaccessible. Try downloading instead.");
                setLoading(false);
              }}
            />
          )}
        </div>
      </div>
    </Modal>
  );
};

export default CVPreviewModal;
