import React, { useState, useEffect } from "react";
import ReactDOM from "react-dom";

import { SESSION_EXPIRED_COUNTDOWN } from "../../utils/constants";
import "./SessionExpiredModal.css";

const SessionExpiredModal = ({ onConfirm }) => {
  const [secondsLeft, setSecondsLeft] = useState(SESSION_EXPIRED_COUNTDOWN);

  useEffect(() => {
    // Countdown timer
    const timer = setInterval(() => {
      setSecondsLeft(prev => {
        if (prev <= 1) {
          clearInterval(timer);
          onConfirm();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [onConfirm]);

  // Get current language from localStorage or default to 'en'
  const currentLanguage = localStorage.getItem("language") || "en";
  const isRTL = currentLanguage === "he";

  const messages = {
    en: {
      title: "Session Expired",
      message: "Your session has expired due to inactivity.",
      redirect: "You will be redirected to the login page in",
      seconds: "seconds",
      button: "Go to Login Now"
    },
    he: {
      title: "תוקף הסשן פג",
      message: "תוקף הסשן שלך פג עקב חוסר פעילות.",
      redirect: "תועבר לדף ההתחברות בעוד",
      seconds: "שניות",
      button: "עבור להתחברות כעת"
    }
  };

  const t = messages[currentLanguage] || messages.en;

  return ReactDOM.createPortal(
    <div className="session-expired-modal__overlay" dir="auto">
      <div className="session-expired-modal__content">
        <div className="session-expired-modal__icon">⚠️</div>
        <h2 className="session-expired-modal__title">{t.title}</h2>
        <p className="session-expired-modal__message">{t.message}</p>
        <p className="session-expired-modal__countdown">
          {t.redirect} <strong>{secondsLeft}</strong> {t.seconds}
        </p>
        <button className="session-expired-modal__button" onClick={onConfirm}>
          {t.button}
        </button>
      </div>
    </div>,
    document.body
  );
};

export default SessionExpiredModal;
