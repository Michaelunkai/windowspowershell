import React, { useEffect, useCallback } from "react";

import "./Modal.css";

const Modal = ({
  isOpen,
  onClose,
  title,
  children,
  maxWidth = "600px",
  className = "",
  xOnlyHeader = false
}) => {
  const handleOverlayClick = e => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const handleKeyDown = useCallback(
    e => {
      if (e.key === "Escape") {
        onClose();
      }
    },
    [onClose]
  );

  if (!isOpen) {
    return null;
  }

  return (
    <div className="modal__overlay" onClick={handleOverlayClick}>
      <div className={`modal__content ${className}`} style={{ maxWidth }}>
        <div className="modal__sticky-header-wrap">
          <>
            {xOnlyHeader ? (
              <div className="modal__header modal__header--x-only">
                <button
                  className="modal__close-btn"
                  onClick={onClose}
                  aria-label="Close modal"
                  style={{ marginLeft: "auto", fontSize: 28, background: "none", border: "none", color: "#222", cursor: "pointer", lineHeight: 1 }}
                >
                  ×
                </button>
              </div>
            ) : (
              <div className="modal__header">
                {title && <h2 className="modal__title">{title}</h2>}
                <button
                  className="modal__close-btn"
                  onClick={onClose}
                  aria-label="Close modal"
                >
                  ×
                </button>
              </div>
            )}
            <div className="modal__body">{children}</div>
          </>
        </div>
      </div>
    </div>
  );
};

export default Modal;
