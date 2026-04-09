import { Clock, Briefcase, GraduationCap, CheckCircle2, XCircle } from "lucide-react";
import React, { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";

import {
  downloadCVWithAuth,
  fetchUserFromSession,
  resubscribeToEmails,
  unsubscribeFromEmails,
  updateIsStudentStatus,
  updateMaxAlerts,
  user_profile
} from "../api";
import { useLanguage } from "../contexts/LanguageContext";
import { capitalizeName } from "../utils/textHelpers";
import { useTranslations } from "../utils/translations";
import "./Profile.css";
import Modal from "./shared/Modal";

const getBinaryStatusValue = value => value === 1 || value === "1" || value === true || value === "true";
const TOGGLE_FEEDBACK_DURATION = 3500;
const TOGGLE_FEEDBACK_EXIT_DURATION = 250;

const Profile = () => {
  const { t } = useTranslations("profile");
  const { currentLanguage, setLanguage } = useLanguage();
  const isRtl = currentLanguage === "he";
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [profInfo, setProfInfo] = useState(null);
  const [profInfoLoading, setProfInfoLoading] = useState(false);
  const [loading, setLoading] = useState(true);

  const [subscribed, setSubscribed] = useState(true);
  const [subLoading, setSubLoading] = useState(false);

  const [maxAlerts, setMaxAlerts] = useState(5);
  const [originalMaxAlerts, setOriginalMaxAlerts] = useState(5);
  const [maxAlertsLoading, setMaxAlertsLoading] = useState(false);
  const [studentJobsLoading, setStudentJobsLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [modalMessage, setModalMessage] = useState("");
  const [toggleFeedback, setToggleFeedback] = useState(null);

  const [downloadLoading, setDownloadLoading] = useState(false);
  const emailToggleRef = useRef(null);
  const studentToggleRef = useRef(null);

  const restoreToggleFocus = toggleRef => {
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        toggleRef.current?.focus();
      });
    });
  };

  const refreshProfessionalInfo = async userId => {
    setProfInfoLoading(true);
    try {
      const prof = await user_profile(userId);
      setProfInfo(prof);
      return prof;
    } catch (error) {
      setProfInfo(null);
      throw error;
    } finally {
      setProfInfoLoading(false);
    }
  };

  const showToggleFeedback = (message, type) => {
    setToggleFeedback({ message, type, isVisible: false });

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        setToggleFeedback(current => current && current.message === message && current.type === type ? {
          ...current,
          isVisible: true
        } : current);
      });
    });
  };

  const hideToggleFeedback = () => {
    setToggleFeedback(current => {
      if (!current || !current.isVisible) {
        return current;
      }

      return {
        ...current,
        isVisible: false
      };
    });
  };

  const handleDownloadCV = async () => {
    setDownloadLoading(true);
    try {
      await downloadCVWithAuth(user.cv_link, user.name);
    } catch (err) {
      console.error("Download error:", err);
      setModalMessage(t("downloadError")); // שימוש בתרגום
      setShowModal(true);
    } finally {
      setDownloadLoading(false);
    }
  };

  const handleMaxAlertsChange = e => {
    const value = e.target.value;
    // Allow empty string while typing
    if (value === "") {
      setMaxAlerts("");
      return;
    }
    // Parse as number and validate range
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      setMaxAlerts(Math.max(0, Math.min(100, numValue)));
    }
  };

  const handleSaveMaxAlerts = async () => {
    // Don't save if empty string
    if (maxAlerts === "") {
      return;
    }

    setMaxAlertsLoading(true);
    try {
      await updateMaxAlerts(maxAlerts, user.id);
      setOriginalMaxAlerts(maxAlerts);
      setModalMessage(t("maxAlertsUpdated"));
      setShowModal(true);
    } catch (_err) {
      // Error is already shown to user via modal
      setModalMessage(t("maxAlertsUpdateFailed"));
      setShowModal(true);
    } finally {
      setMaxAlertsLoading(false);
    }
  };

  const handleSubscriptionChange = async checked => {
    setSubscribed(checked);
    setSubLoading(true);

    try {
      if (checked) {
        await resubscribeToEmails(user.email);
        showToggleFeedback(t("subscribeSuccess"), "success");
      } else {
        await unsubscribeFromEmails(user.email);
        showToggleFeedback(t("unsubscribeSuccess"), "success");
      }
    } catch (_err) {
      setSubscribed(!checked);
      showToggleFeedback(checked ? t("subscribeFailed") : t("unsubscribeFailed"), "error");
    } finally {
      setSubLoading(false);
      restoreToggleFocus(emailToggleRef);
    }
  };

  const handleStudentJobAlertsChange = async checked => {
    if (!user || !profInfo) {
      return;
    }

    setStudentJobsLoading(true);

    try {
      await updateIsStudentStatus({ userId: user.id, value: checked ? 1 : 0 });
      await refreshProfessionalInfo(user.id);
      showToggleFeedback(t("studentJobAlertsUpdated"), "success");
    } catch (_err) {
      showToggleFeedback(t("studentJobAlertsUpdateFailed"), "error");
    } finally {
      setStudentJobsLoading(false);
      restoreToggleFocus(studentToggleRef);
    }
  };

  useEffect(() => {
    if (!toggleFeedback) {
      return undefined;
    }

    const timeoutId = window.setTimeout(
      () => {
        if (!toggleFeedback.isVisible) {
          setToggleFeedback(null);
          return;
        }

        hideToggleFeedback();
      },
      toggleFeedback.isVisible ? TOGGLE_FEEDBACK_DURATION : TOGGLE_FEEDBACK_EXIT_DURATION
    );

    return () => window.clearTimeout(timeoutId);
  }, [toggleFeedback]);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const userData = await fetchUserFromSession();
        setUser(userData);
        setSubscribed(
          userData && typeof userData.subscribed === "boolean" ? userData.subscribed : true
        );
        const userMaxAlerts = userData && typeof userData.max_alerts === "number" ? userData.max_alerts : 5;
        setMaxAlerts(userMaxAlerts);
        setOriginalMaxAlerts(userMaxAlerts);
        // Fetch professional info only for non-admin, non-demo
        if (userData && userData.role !== "admin" && userData.role !== "demo") {
          try {
            await refreshProfessionalInfo(userData.id);
          } catch {
            setProfInfo(null);
          }
        }
        setLoading(false);
      } catch {
        setModalMessage("Failed to load user profile.");
        setShowModal(true);
        setLoading(false);
      }
    };
    fetchUser();
  }, []);

  const hasDegree = getBinaryStatusValue(profInfo?.HasDegree);
  const isStudent = getBinaryStatusValue(profInfo?.IsStudent);
  const studentToggleHelpText = !subscribed ? t("studentAlertsRequiresEmail") : null;

  if (loading) {
    return <div className="profile-loading text-basic" dir="auto">Loading profile...</div>;
  }
  if (!user) {
    return <div className="profile-error" dir="auto">Unable to load profile.</div>;
  }

  return (
    <div className="profile-page-wrapper">
      <div className="profile-flex-container" style={{ display: "flex", gap: "32px", flexWrap: "wrap" }} dir="auto">
        {/* Main Profile Card + Professional Info Card as siblings, wrapped in fragment */}
        <>
          <div className="profile-container" style={{ flex: "1 1 340px", minWidth: 320, maxWidth: "max(500px, 35vw)" }}>
            <h2 className="profile-title">
              {t("welcome")}, {capitalizeName(user.name) || "User"}
            </h2>
            <div className="profile-section">
              <div className="profile-label">{t("email")}:</div>
              <div className="profile-value">{user.email || "-"}</div>
              <div className="profile-label">{t("role")}:</div>
              <div className="profile-value">{user.role || "-"}</div>
              {user.role !== "admin" && user.role !== "demo" && (
                <>
                  <div className="profile-label">{t("cvStatus")}:</div>
                  <div className="profile-value">{user.cv_status || "-"}</div>
                </>
              )}
            </div>

            {/* Language toggle buttons - visible for all users */}
            <hr style={{ margin: "24px 0 18px 0", border: 0, borderTop: "1px solid #eee" }} />
            <div style={{ marginBottom: "16px", textAlign: currentLanguage === "he" ? "right" : "left" }}>
              <span style={{ marginRight: currentLanguage === "he" ? "0" : "8px", marginLeft: currentLanguage === "he" ? "8px" : "0", fontSize: "14px", color: "#666" }}>
                {t("language")}:
              </span>
              <button
                onClick={() => setLanguage("en")}
                style={{
                  background: currentLanguage === "en" ? "#2196f3" : "#f5f5f5",
                  border: "1px solid #ddd",
                  borderRadius: "4px 0 0 4px",
                  padding: "8px 12px",
                  cursor: "pointer",
                  fontSize: "14px",
                  color: currentLanguage === "en" ? "#fff" : "#333",
                  marginRight: "0"
                }}
              >
                English
              </button>
              <button
                onClick={() => setLanguage("he")}
                style={{
                  background: currentLanguage === "he" ? "#2196f3" : "#f5f5f5",
                  border: "1px solid #ddd",
                  borderRadius: "0 4px 4px 0",
                  borderLeft: "0",
                  padding: "8px 12px",
                  cursor: "pointer",
                  fontSize: "14px",
                  color: currentLanguage === "he" ? "#fff" : "#333"
                }}
              >
                עברית
              </button>
            </div>

            {/* Subscription/Unsubscribe UI (not for admin) */}
            {user.role !== "admin" && (
              <>

                <div className="profile-sub-block" role="group" aria-labelledby="profile-alert-preferences-heading">
                  <h3 id="profile-alert-preferences-heading" className="profile-toggle-group-title">
                    {t("alertPreferences")}
                  </h3>
                  <div className="profile-toggle-list">
                    <label className={`profile-toggle-row${subLoading ? " profile-toggle-row--disabled" : ""}`} htmlFor="profile-email-alerts-toggle">
                      <span className="profile-toggle-text">
                        <span className="profile-toggle-label">{t("wishToReceiveEmails")}</span>
                        <span className="profile-toggle-help profile-toggle-help--keyboard" aria-hidden="true">
                          {t("alertToggleKeyboardHint")}
                        </span>
                      </span>
                      <span className="profile-toggle-control">
                        <input
                          id="profile-email-alerts-toggle"
                          type="checkbox"
                          role="switch"
                          checked={subscribed}
                          onChange={e => handleSubscriptionChange(e.target.checked)}
                          disabled={subLoading}
                          className="profile-toggle-input"
                          ref={emailToggleRef}
                        />
                        <span className="profile-toggle-slider" aria-hidden="true"></span>
                      </span>
                    </label>
                    <label className={`profile-toggle-row${(!subscribed || studentJobsLoading) ? " profile-toggle-row--disabled" : ""}`} htmlFor="profile-student-alerts-toggle">
                      <span className="profile-toggle-text">
                        <span className="profile-toggle-label">{t("receiveStudentJobAlerts")}</span>
                        <span className="profile-toggle-help profile-toggle-help--keyboard" aria-hidden="true">
                          {t("alertToggleKeyboardHint")}
                        </span>
                        {studentToggleHelpText && (
                          <span id="profile-student-alerts-help" className="profile-toggle-help">
                            {studentToggleHelpText}
                          </span>
                        )}
                      </span>
                      <span className="profile-toggle-control">
                        <input
                          id="profile-student-alerts-toggle"
                          type="checkbox"
                          role="switch"
                          checked={isStudent}
                          onChange={e => handleStudentJobAlertsChange(e.target.checked)}
                          disabled={!subscribed || studentJobsLoading || profInfoLoading || !profInfo}
                          className="profile-toggle-input"
                          aria-describedby={studentToggleHelpText ? "profile-student-alerts-help" : undefined}
                          ref={studentToggleRef}
                        />
                        <span className="profile-toggle-slider" aria-hidden="true"></span>
                      </span>
                    </label>
                  </div>
                </div>

                {/* Max Alerts Setting */}
                <div className="profile-max-alerts-section">
                  <div className="profile-max-alerts-line">
                    <span className="profile-max-alerts-text" dangerouslySetInnerHTML={{ __html: t("maxAlerts") }}></span>
                    <input
                      type="number"
                      min="0"
                      max="100"
                      value={maxAlerts}
                      onChange={handleMaxAlertsChange}
                      className="profile-max-alerts-input"
                    />
                    <span className="profile-max-alerts-text">{t("maxAlertsEachDay")}</span>
                  </div>
                  {maxAlerts !== originalMaxAlerts && maxAlerts !== "" && (
                    <button
                      className="profile-btn profile-btn-save-alerts"
                      onClick={handleSaveMaxAlerts}
                      disabled={maxAlertsLoading}
                    >
                      {maxAlertsLoading ? <span className="profile-btn-spinner"></span> : t("saveChanges")}
                    </button>
                  )}
                </div>
              </>
            )}
            {user.role !== "admin" && (
              <div className="profile-cv-actions">
                {user.cv_link && (
                  <button
                    className={`profile-btn profile-btn-view-cv ${downloadLoading ? "profile-btn-disabled" : ""}`}
                    onClick={handleDownloadCV}
                    disabled={downloadLoading}
                  >
                    {downloadLoading ? (
                      <>
                        <span className="profile-btn-spinner"></span>
                        {t("downloading")}
                      </>
                    ) : (
                      t("downloadCV")
                    )}
                  </button>
                )}
                <button
                  className="profile-btn profile-btn-cv"
                  onClick={() => navigate("/cv-upload", { state: { fromProfile: true } })}
                >
                  {user.cv_status === "Missing" ? t("uploadCV") : t("reUploadCV")}
                </button>
              </div>
            )}
            <Modal isOpen={showModal} onClose={() => setShowModal(false)} title="" xOnlyHeader>
              <div className="profile-modal-content">
                <div className="profile-modal-message">{modalMessage}</div>
                <button className="profile-modal-confirm-btn" onClick={() => setShowModal(false)}>OK</button>
              </div>
            </Modal>
            {toggleFeedback && (
              <div
                className={`profile-toast profile-toast--${toggleFeedback.type}${toggleFeedback.isVisible ? " profile-toast--visible" : ""}`}
                role="status"
                aria-live={toggleFeedback.type === "error" ? "assertive" : "polite"}
              >
                <span className="profile-toast-message">{toggleFeedback.message}</span>
                <button
                  type="button"
                  className="profile-toast-close"
                  onClick={hideToggleFeedback}
                  aria-label={t("dismissFeedback")}
                >
                  ×
                </button>
              </div>
            )}
          </div>
          {/* Professional Info Card (side-by-side) */}
          {user.role !== "admin" && user.role !== "demo" && (
            <div className="profile-container profile-prof-card" style={{ flex: "1 1 340px", minWidth: 320, maxWidth: "max(500px, 35vw)" }}>
              <div className={`profile-prof-header${isRtl ? " rtl" : ""}`}>
                <h2 className="profile-title">{t("professional_info.title")}</h2>
                <div className={`profile-subtitle${isRtl ? " rtl" : ""}`}>{t("professional_info.subtitle")}</div>
              </div>
              {profInfoLoading ? (
                <div className="profile-prof-loading">Loading...</div>
              ) : profInfo ? (
                <>
                  <div className="profile-prof-skills-container">
                    {Array.isArray(profInfo.fields_of_expertise) && profInfo.fields_of_expertise.length > 0 ? profInfo.fields_of_expertise.map(field => (
                      <span className="profile-prof-pill" key={field}>{field}</span>
                    )) : <span className="profile-prof-pill profile-fields-none">-</span>}
                  </div>
                  <footer className="profile-prof-footer profile-prof-footer-sticky">
                    <div className="profile-prof-footer-item">
                      <div className="profile-prof-footer-label">
                        <GraduationCap className="profile-prof-footer-icon" aria-label="degree" />
                        {t("professional_info.has_degree")}
                      </div>
                      <div className={`profile-prof-footer-value ${hasDegree ? "status-success" : "status-disabled"}`}>
                        <span className={`profile-prof-footer-status-icon-bg ${hasDegree ? "positive" : "negative"}`}>
                          {hasDegree ? (
                            <CheckCircle2 className="profile-prof-footer-status-icon" aria-label="yes" />
                          ) : (
                            <XCircle className="profile-prof-footer-status-icon" aria-label="no" />
                          )}
                        </span>
                        <span>{hasDegree ? t("professional_info.yes") : t("professional_info.no")}</span>
                      </div>
                    </div>
                    <div className="profile-prof-footer-divider"></div>
                    <div className="profile-prof-footer-item">
                      <div className="profile-prof-footer-label">
                        <Clock className="profile-prof-footer-icon" aria-label="exp" />
                        {t("professional_info.years_of_experience")}
                      </div>
                      <div className="profile-prof-footer-value">
                        {profInfo.years_of_experience ?? "-"}
                        <span className="profile-prof-footer-years">{t("professional_info.experience_time_unit")}</span>
                      </div>
                    </div>
                    <div className="profile-prof-footer-divider"></div>
                    <div className="profile-prof-footer-item">
                      <div className="profile-prof-footer-label">
                        <Briefcase className="profile-prof-footer-icon" aria-label="student" />
                        {t("professional_info.is_student")}
                      </div>
                      <div className={`profile-prof-footer-value ${isStudent ? "status-success" : "status-disabled"}`}>
                        <span className={`profile-prof-footer-status-icon-bg ${isStudent ? "positive" : "negative"}`}>
                          {isStudent ? (
                            <CheckCircle2 className="profile-prof-footer-status-icon" aria-label="yes" />
                          ) : (
                            <XCircle className="profile-prof-footer-status-icon" aria-label="no" />
                          )}
                        </span>
                        <span>{isStudent ? t("professional_info.yes") : t("professional_info.no")}</span>
                      </div>
                    </div>
                  </footer>
                </>
              ) : (
                <div className="profile-prof-nodata">-</div>
              )}
            </div>
          )}
        </>
      </div>
    </div>
  );
};

export default Profile;
