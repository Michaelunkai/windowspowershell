import { Eye, EyeOff } from "lucide-react";
import React, { useState, useEffect } from "react";
import { useNavigate, Link } from "react-router-dom";

import { useLanguage } from "../../contexts/LanguageContext";
import { useAuth } from "../../hooks/useAuth";
import { useTranslations } from "../../utils/translations";
import { getTranslation } from "../../utils/translations";
import ResetPasswordModal from "./ResetPasswordModal";
import "./Login.css";

const Login = () => {
  const { t } = useTranslations("login");
  const { currentLanguage } = useLanguage();

  const [formData, setFormData] = useState({
    email: "",
    password: "",
    rememberMe: false
  });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [sessionExpiredMessage, setSessionExpiredMessage] = useState("");
  const [showCookiePopup, setShowCookiePopup] = useState(false);
  const [popupState, setPopupState] = useState("initial"); // 'initial' or 'manual'
  const [cookieRetryCount, setCookieRetryCount] = useState(0);
  const { login } = useAuth();
  const [showResetModal, setShowResetModal] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const navigate = useNavigate();

  // Check for session expiration on component mount
  useEffect(() => {
    const sessionExpired = localStorage.getItem("sessionExpired");
    if (sessionExpired === "true") {
      setSessionExpiredMessage(t("errors.sessionExpired"));
      // Clear the flag so it doesn't show again
      localStorage.removeItem("sessionExpired");
    }
  }, [t]);

  const handleInputChange = e => {
    const value = e.target.type === "checkbox" ? e.target.checked : e.target.value;
    setFormData({
      ...formData,
      [e.target.name]: value
    });
    setError("");
  };

  const handleAllowCookies = async () => {
    try {
      // Check if API exists
      if (!document.requestStorageAccess) {
        setPopupState("manual");
        return;
      }

      // Request the access
      await document.requestStorageAccess();

      // Close popup and retry login
      setShowCookiePopup(false);
      handleSubmit(new Event("submit"));
    } catch (_err) {
      setPopupState("manual");
    }
  };

  const handleManualRetry = () => {
    // User claims they fixed it manually, let them retry
    setShowCookiePopup(false);
    setPopupState("initial");
    handleSubmit(new Event("submit"));
  };

  const handleSubmit = async e => {
    e.preventDefault();
    setLoading(true);
    setError("");
    setShowCookiePopup(false);
    setPopupState("initial");
    try {
      const result = await login(formData.email, formData.password, formData.rememberMe);

      if (result.status === 200 && result.data?.user_authenticated) {
        // Check if cookies are blocked
        if (result.data?.cookies_blocked) {
          const newRetryCount = cookieRetryCount + 1;
          setCookieRetryCount(newRetryCount);

          // If this is the 2nd failure, switch to manual mode
          if (newRetryCount >= 2) {
            setPopupState("manual");
          }

          setShowCookiePopup(true);
          setLoading(false);
          return;
        }

        // Success! Reset retry count
        setCookieRetryCount(0);

        // Redirect based on role
        if ((result.data.role || "user") === "admin") {
          navigate("/overview");
        } else {
          navigate("/user/matches");
        }
      } else {
        let msg = result.data?.error || result.data?.message || t("errors.loginFailed");
        if (msg === "User authentication failed" || msg.toLowerCase().includes("authentication failed")) {
          msg = t("errors.userNotFound");
        }
        setError(msg);
      }
    } catch {
      setError(t("errors.genericError"));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page" dir="auto">
      <div className="login-container">

        <div className="login-header">
          <h1 className="login-title">{t("title")}</h1>
          <p className="login-subtitle">{t("subtitle")}</p>
        </div>
        <form onSubmit={handleSubmit} className="login-form">
          {sessionExpiredMessage && <div className="session-expired-message">{sessionExpiredMessage}</div>}
          {error && <div className="error-message">{error}</div>}
          <div className="form-group">
            <label htmlFor="email" className="form-label">
              {t("emailLabel")}
            </label>
            <input
              type="email"
              id="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              className="form-input light-input"
              required
              placeholder={t("emailLabel")}
              autoComplete="username"
              style={{
                background: "#fff",
                color: "#222",
                textAlign: currentLanguage === "he" ? "right" : "left"
              }}
            />
          </div>
          <div className="form-group">
            <label htmlFor="password" className="form-label">
              {t("passwordLabel")}
            </label>
            <div style={{ position: "relative" }}>
              <input
                type={showPassword ? "text" : "password"}
                id="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                className="form-input light-input"
                required
                placeholder={t("passwordLabel")}
                autoComplete="new-password"
                style={{
                  background: "#fff",
                  color: "#222",
                  paddingRight: currentLanguage === "he" ? "10px" : "40px",
                  paddingLeft: currentLanguage === "he" ? "40px" : "10px",
                  textAlign: currentLanguage === "he" ? "right" : "left"
                }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="password-toggle-btn"
                title={showPassword ? t("hidePassword") : t("showPassword")}
                aria-label={showPassword ? t("hidePassword") : t("showPassword")}
              >
                {showPassword ? <Eye width={18} height={18} /> : <EyeOff width={18} height={18} />}
              </button>
            </div>
          </div>

          {/* Remember Me checkbox */}
          <div className="form-group" style={{ marginBottom: "12px", textAlign: currentLanguage === "he" ? "right" : "left" }}>
            <label className="remember-me-label" style={{
              display: "inline-flex",
              gap: "8px"
            }}>
              <input
                type="checkbox"
                name="rememberMe"
                checked={formData.rememberMe}
                onChange={handleInputChange}
                className="remember-me-checkbox"
              />
              <span>{t("rememberMe")}</span>
            </label>
          </div>

          {/* Forgot password link moved here */}
          <div style={{ textAlign: "right", marginBottom: "12px" }}>
            <button
              type="button"
              className="text-button"
              style={{ background: "none", border: "none", color: "#2196f3", cursor: "pointer", fontWeight: 500, padding: 0, fontSize: "0.9rem" }}
              onClick={() => setShowResetModal(true)}
            >
              {t("forgotPassword")}
            </button>
          </div>

          <button type="submit" className="login-button" disabled={loading}>
            {loading ? getTranslation("common", "loading", currentLanguage) : t("loginButton")}
          </button>
        </form>

        <div className="login-footer">
          <p className="login-link">
            {t("signUpPrompt")}{" "}
            <Link to="/signup" className="text-button">
              {t("signUpLink")}
            </Link>
          </p>
        </div>

        {/* Cookie warning message - moved to bottom */}
        <div dir="auto" style={{
          textAlign: "center",
          marginTop: "16px",
          padding: "8px",
          fontSize: "0.85rem",
          color: "#666",
          lineHeight: "1.4"
        }}>
          {/* {t('cookieWarning')} */}
        </div>
      </div>
      {/* Move modal outside login-container */}
      <ResetPasswordModal isOpen={showResetModal} onClose={() => setShowResetModal(false)} />

      {/* Cookie Blocked Popup - slides up from bottom */}
      {showCookiePopup && (
        <div className="cookie-popup-overlay" onClick={() => setShowCookiePopup(false)}>
          <div className="cookie-popup" onClick={e => e.stopPropagation()}>
            <div className="cookie-popup-content">
              {popupState === "initial" ? (
                // Initial view - try automatic fix
                <>
                  <h3 className="cookie-popup-title">{t("cookieBlockedTitle")}</h3>
                  <p className="cookie-popup-message">{t("cookieBlockedMessage")}</p>
                  <div className="cookie-popup-buttons">
                    <button
                      className="cookie-popup-button cookie-popup-button--primary"
                      onClick={handleAllowCookies}
                    >
                      {t("cookieAllowButton")}
                    </button>
                    <button
                      className="cookie-popup-button cookie-popup-button--secondary"
                      onClick={() => setShowCookiePopup(false)}
                    >
                      {t("cookieCancelButton")}
                    </button>
                  </div>
                </>
              ) : (
                // Manual fix view - hard block detected
                <>
                  <h3 className="cookie-popup-title">{t("cookieManualTitle")}</h3>
                  <div className="cookie-popup-manual">
                    <p className="cookie-popup-message">{t("cookieManualDescription")}</p>
                    <ol className="cookie-popup-steps">
                      <li>{t("cookieManualStep1")}</li>
                      <li>{t("cookieManualStep2")}</li>
                      <li>{t("cookieManualStep3")}</li>
                    </ol>
                  </div>
                  <div className="cookie-popup-buttons">
                    <button
                      className="cookie-popup-button cookie-popup-button--primary"
                      onClick={handleManualRetry}
                    >
                      {t("cookieManualRetryButton")}
                    </button>
                    <button
                      className="cookie-popup-button cookie-popup-button--secondary"
                      onClick={() => setShowCookiePopup(false)}
                    >
                      {t("cookieCancelButton")}
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Login;
