import React, { useState, useRef } from "react";
import ReactDOM from "react-dom";

import "./TruncatedText.css";

const TruncatedText = ({
  text,
  maxWidth = "100px",
  className = "",
  copyable = false,
  style
}) => {
  const [showTooltip, setShowTooltip] = useState(false);
  const [tooltipPos, setTooltipPos] = useState({ x: 0, y: 0 });
  const textRef = useRef(null);

  // Simple text handling - just ensure we have a string
  const displayText = text ? text.toString().trim() : "";

  const handleMouseEnter = e => {
    const element = textRef.current;
    if (element && element.scrollWidth > element.offsetWidth) {
      const rect = e.target.getBoundingClientRect();
      setTooltipPos({
        x: rect.left + rect.width / 2,
        y: rect.top - 40  // Increased gap from -8 to -40
      });
      setShowTooltip(true);
    }
  };

  const handleMouseLeave = () => {
    setShowTooltip(false);
  };

  const handleClick = () => {
    if (copyable && displayText) {
      navigator.clipboard.writeText(displayText).then(() => {
        // Successfully copied to clipboard
      }).catch(_err => {
        // Failed to copy - could add user feedback here if needed
      });
    }
  };

  return (
    <>
      <div
        className={`truncated-text ${className}`}
        style={{
          maxWidth,
          cursor: copyable ? "pointer" : "default",
          ...style
        }}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        onClick={handleClick}
      >
        <span
          ref={textRef}
          className="truncated-text__content"
        >
          {displayText}
        </span>
      </div>

      {showTooltip && ReactDOM.createPortal(
        <div
          className="truncated-text__tooltip-portal"
          style={{
            position: "fixed",
            top: tooltipPos.y,
            left: tooltipPos.x,
            transform: "translateX(-50%)"
          }}
        >
          {displayText}
        </div>,
        document.body
      )}
    </>
  );
};

export default TruncatedText;
