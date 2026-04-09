import { Eye, EyeOff } from "lucide-react";
import React, { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { setNewPassword } from "../../api";
import { useLanguage } from "../../contexts/LanguageContext";
import "./Login.css";
import { useTranslations } from "../../utils/translations";

const NewPasswordPage = () => {
  const { t } = useTranslations("newPassword");
  const { currentLanguage } = useLanguage();
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const navigate = useNavigate();
  // Get token from URL params (now /reset_password/:token)
  const { token } = useParams();

  const handleSubmit = async e => {
    e.preventDefault();
    setError("");
    if (!password || !confirmPassword) {
      setError(t("errors.fillAllFields"));
      return;
    }
    if (password !== confirmPassword) {
      setError(t("errors.passwordsMismatch"));
      return;
    }
    setLoading(true);
    try {
      await setNewPassword(token, password, confirmPassword);
      // Optionally, redirect to login page after success
      navigate("/login");
    } catch (err) {
      setError(err.message || t("errors.failedToSet"));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div key={`newPassword-${currentLanguage}`} className="login-page">
      <div className="login-container">
        <h1 className="login-title">{t("title")}</h1>
        <form onSubmit={handleSubmit} className="login-form">
          <label htmlFor="new-password">{t("newPassword")}</label>
          <div style={{ position: "relative" }}>
            <input
              id="new-password"
              type={showPassword ? "text" : "password"}
              value={password}
              onChange={e => setPassword(e.target.value)}
              className="form-input"
              required
              placeholder={t("newPasswordPlaceholder")}
              style={{ background: "#fff", color: "#222", paddingRight: "40px" }}
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
          <label htmlFor="confirm-password">{t("confirmPassword")}</label>
          <div style={{ position: "relative" }}>
            <input
              id="confirm-password"
              type={showConfirmPassword ? "text" : "password"}
              value={confirmPassword}
              onChange={e => setConfirmPassword(e.target.value)}
              className="form-input"
              required
              placeholder={t("confirmPasswordPlaceholder")}
              style={{ background: "#fff", color: "#222", marginBottom: "1.2rem", paddingRight: "40px" }}
            />
            <button
              type="button"
              onClick={() => setShowConfirmPassword(!showConfirmPassword)}
              className="password-toggle-btn"
              title={showConfirmPassword ? t("hidePassword") : t("showPassword")}
              aria-label={showConfirmPassword ? t("hidePassword") : t("showPassword")}
            >
              {showConfirmPassword ? <Eye width={18} height={18} /> : <EyeOff width={18} height={18} />}
            </button>
          </div>
          {error && <div className="error-message">{error}</div>}
          <button type="submit" className="login-button" disabled={loading}>
            {loading ? t("setting") : t("setPassword")}
          </button>
        </form>
      </div>
    </div>
  );
};

export default NewPasswordPage;
