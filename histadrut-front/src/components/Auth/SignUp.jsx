import { Eye, EyeOff } from "lucide-react";
import React, { useState } from "react";
import { useNavigate, Link } from "react-router-dom";

import { useLanguage } from "../../contexts/LanguageContext";
import { useAuth } from "../../hooks/useAuth";
import "./Login.css";
import { useTranslations } from "../../utils/translations";

const SignUp = () => {
  const { t } = useTranslations("signUp");
  const { currentLanguage } = useLanguage();
  const [formData, setFormData] = useState({
    email: "",
    name: "",
    password: "",
    confirmPassword: "",
    subscribed: true // Default to true
  });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { signUp } = useAuth();
  const navigate = useNavigate();
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const handleInputChange = e => {
    const value = e.target.type === "checkbox" ? e.target.checked : e.target.value;
    setFormData({
      ...formData,
      [e.target.name]: value
    });
    setError("");
  };

  const handleSubmit = async e => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      if (!formData.name.trim()) {
        setError(t("errors.nameRequired"));
        setLoading(false);
        return;
      }
      if (formData.password !== formData.confirmPassword) {
        setError(t("errors.passwordsMismatch"));
        setLoading(false);
        return;
      }
      const result = await signUp(
        formData.email,
        formData.password,
        formData.name,
        formData.subscribed
      );

      if (result.status === 201) {
        setError("");
        navigate("/cv-upload");
      } else {
        setError(result.data?.message || t("errors.registrationFailed"));
      }
    } catch {
      setError(t("errors.genericError"));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div key={`signUp-${currentLanguage}`} className="login-page" dir="auto">
      <div className="login-container">
        <div className="login-header">
          <h1 className="login-title">{t("title")}</h1>
          <p className="login-subtitle">{t("subtitle")}</p>
        </div>
        <form onSubmit={handleSubmit} className="login-form">
          {error && <div className="error-message">{error}</div>}
          <div className="form-group">
            <label htmlFor="email" className="form-label">
              {t("form.email")}
            </label>
            <input
              type="email"
              id="email"
              name="email"
              value={formData.email}
              onChange={handleInputChange}
              className="form-input"
              required
              placeholder={t("form.emailPlaceholder")}
              autoComplete="off"
              style={{ textAlign: currentLanguage === "he" ? "right" : "left" }}
            />
          </div>
          <div className="form-group">
            <label htmlFor="name" className="form-label">
              {t("form.name")}
            </label>
            <input
              type="text"
              id="name"
              name="name"
              value={formData.name}
              onChange={handleInputChange}
              className="form-input"
              required
              placeholder={t("form.namePlaceholder")}
              autoComplete="off"
              style={{ textAlign: currentLanguage === "he" ? "right" : "left" }}
            />
          </div>
          <div className="form-group">
            <label htmlFor="password" className="form-label">
              {t("form.password")}
            </label>
            <div className="password-input-container">
              <input
                type={showPassword ? "text" : "password"}
                id="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                className="form-input"
                required
                placeholder={t("form.passwordPlaceholder")}
                autoComplete="new-password"
                style={{
                  paddingRight: currentLanguage === "he" ? "10px" : "40px",
                  paddingLeft: currentLanguage === "he" ? "40px" : "10px",
                  textAlign: currentLanguage === "he" ? "right" : "left"
                }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                title={showPassword ? t("form.hidePassword") : t("form.showPassword")}
                className="password-toggle-btn"
                aria-label={showPassword ? t("form.hidePassword") : t("form.showPassword")}
              >
                {showPassword ? <Eye width={18} height={18} /> : <EyeOff width={18} height={18} />}
              </button>
            </div>
          </div>
          <div className="form-group">
            <label htmlFor="confirmPassword" className="form-label">
              {t("form.confirmPassword")}
            </label>
            <div className="password-input-container">
              <input
                type={showConfirmPassword ? "text" : "password"}
                id="confirmPassword"
                name="confirmPassword"
                value={formData.confirmPassword}
                onChange={handleInputChange}
                className="form-input"
                required
                placeholder={t("form.confirmPasswordPlaceholder")}
                autoComplete="new-password"
                style={{
                  paddingRight: currentLanguage === "he" ? "10px" : "40px",
                  paddingLeft: currentLanguage === "he" ? "40px" : "10px",
                  textAlign: currentLanguage === "he" ? "right" : "left"
                }}
              />
              <button
                type="button"
                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                title={showConfirmPassword ? t("form.hidePassword") : t("form.showPassword")}
                className="password-toggle-btn"
                aria-label={showConfirmPassword ? t("form.hidePassword") : t("form.showPassword")}
              >
                {showConfirmPassword ? <Eye width={18} height={18} /> : <EyeOff width={18} height={18} />}
              </button>
            </div>
          </div>
          <div className="form-group">
            <div className="checkbox-container">
              <input
                type="checkbox"
                id="subscribed"
                name="subscribed"
                checked={formData.subscribed}
                onChange={handleInputChange}
                className="checkbox-input"
              />
              <label htmlFor="subscribed" className="checkbox-label">
                {t("form.subscribeToEmails")}
              </label>
            </div>
          </div>
          <button type="submit" className="login-button" disabled={loading}>
            {loading ? t("actions.loading") : t("actions.signUp")}
          </button>
        </form>

        <div className="login-footer">
          <p className="login-link">
            {t("footer.alreadyHaveAccount")}{" "}
            <Link to="/login" className="text-button">
              {t("actions.signIn")}
            </Link>
          </p>
        </div>

        {/* Cookie warning message - moved to bottom */}
        <div style={{
          textAlign: "center",
          marginTop: "16px",
          padding: "8px",
          fontSize: "0.85rem",
          color: "#666",
          lineHeight: "1.4"
        }}>
          {/* {t('footer.cookieWarning')} */}
        </div>
      </div>
    </div>
  );
};

export default SignUp;
