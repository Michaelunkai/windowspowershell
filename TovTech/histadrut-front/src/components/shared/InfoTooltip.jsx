import { Info } from "lucide-react";
import React, { useState } from "react";
import ReactDOM from "react-dom";

import "./InfoTooltip.css";

const InfoTooltip = ({ text, isAdmin = false }) => {
  const [isVisible, setIsVisible] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });

  const handleMouseEnter = e => {
    const iconRect = e.target.getBoundingClientRect();
    const tooltipWidth = 200; // Approximate tooltip width
    const tooltipHeight = 60; // Approximate tooltip height

    let left = iconRect.left + iconRect.width / 2 - tooltipWidth / 2;
    let top = iconRect.top - tooltipHeight - 8; // 8px spacing above icon

    // Adjust if tooltip would go off screen
    if (left < 10) {
      left = 10;
    }
    if (left + tooltipWidth > window.innerWidth - 10) {
      left = window.innerWidth - tooltipWidth - 10;
    }
    if (top < 10) {
      top = iconRect.bottom + 8; // Show below icon if not enough space above
    }

    setPosition({ top, left });
    setIsVisible(true);
  };

  const handleMouseLeave = () => {
    setIsVisible(false);
  };

  const formatTooltipText = text => {
    if (!text.includes("(")) {
      return text;
    }

    // Handle multiple parentheses groups - process each one separately
    let result = text;

    // Replace each (admin text/user text) pattern
    result = result.replace(/\(([^)]+)\)/g, (match, content) => {
      if (content.includes("/")) {
        const parts = content.split("/");
        const adminText = parts[0];
        const candidateText = parts[1];
        const selectedText = isAdmin ? adminText : candidateText;
        return selectedText;
      }
      return content; // Return content without parentheses if no slash
    });

    return result;
  };

  const tooltip = isVisible ? (
    <div className="info-tooltip" style={{ top: position.top, left: position.left }}>
      <div className="info-tooltip__content">
        {formatTooltipText(text)}
      </div>
    </div>
  ) : null;

  return (
    <>
      <img
        as={Info}
        alt="Info"
        className="info-tooltip__icon"
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
      />
      {isVisible && ReactDOM.createPortal(tooltip, document.body)}
    </>
  );
};

export default InfoTooltip;
