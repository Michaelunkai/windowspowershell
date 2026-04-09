import React from "react";

import Modal from "./Modal";

const ConfirmationModal = ({
  isOpen,
  onClose,
  title = "Success",
  message = "",
  buttonText = "OK",
  actions,
  maxWidth,
  className = ""
}) => {
  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title} maxWidth={maxWidth} className={className}>
      <div className="confirmation-modal__body">
        <div className="confirmation-modal__message">{message}</div>
        <div className="confirmation-modal__actions">
          {actions ? actions : (
            <button className="confirmation-modal__ok" onClick={onClose}>{buttonText}</button>
          )}
        </div>
      </div>
    </Modal>
  );
};

export default ConfirmationModal;
