import React, { useState, useEffect, useRef, useMemo } from "react";

import { REGIONS_DICTIONARY } from "../../utils/constants";
import { useTranslations } from "../../utils/translations";
import "./RegionsMultiSelect.css";

const RegionsMultiSelect = ({
  value = "",
  onChange,
  options = [],
  label,
  placeholder,
  inputId,
  className = ""
}) => {
  const { currentLanguage } = useTranslations("common");
  const [isOpen, setIsOpen] = useState(false);
  const selectedRegions = useMemo(() => {
    if (!value || !value.trim()) {
      return [];
    }
    return value.split(",").map(reg => reg.trim()).filter(reg => reg);
  }, [value]);
  const [focusedOptionIndex, setFocusedOptionIndex] = useState(null);
  const containerRef = useRef(null);
  const inputContainerRef = useRef(null);
  const optionRefs = useRef([]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = event => {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleToggleDropdown = e => {
    e.stopPropagation();
    if (!isOpen) {
      setFocusedOptionIndex(0);
    } else {
      setFocusedOptionIndex(null);
    }
    setIsOpen(!isOpen);
  };

  const handleRegionToggle = (region, e) => {
    e.stopPropagation();
    const newSelected = selectedRegions.includes(region)
      ? selectedRegions.filter(reg => reg !== region)
      : [...selectedRegions, region];
    onChange(newSelected.join(","));
  };

  const handleRemoveRegion = (regionToRemove, e) => {
    e.stopPropagation();
    const newSelected = selectedRegions.filter(reg => reg !== regionToRemove);
    onChange(newSelected.join(","));
  };

  const handleOptionKeyDown = (e, index) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      const next = Math.min(index + 1, options.length - 1);
      setFocusedOptionIndex(next);
      optionRefs.current[next]?.focus();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      const prev = Math.max(index - 1, 0);
      setFocusedOptionIndex(prev);
      optionRefs.current[prev]?.focus();
    } else if (e.key === "Escape") {
      setIsOpen(false);
      setFocusedOptionIndex(null);
      inputContainerRef.current?.focus();
    }
  };

  const labelId = label ? `${inputId}-label` : undefined;

  return (
    <div className="regions-multiselect" ref={containerRef}>
      {label && (
        <label className="regions-multiselect__label" id={labelId} htmlFor={inputId}>
          {label}
        </label>
      )}

      <div className="regions-multiselect__input-wrapper">
        <button
          id={inputId}
          ref={inputContainerRef}
          className={`regions-multiselect__input-container ${className} ${isOpen ? "regions-multiselect__input-container--open" : ""}`}
          onClick={handleToggleDropdown}
          type="button"
        >
          {selectedRegions.length > 0 && (
            <div className="regions-multiselect__selected">
              {selectedRegions.map(region => {
                const regionLabel = currentLanguage === "he" && REGIONS_DICTIONARY[region] ? REGIONS_DICTIONARY[region] : region;
                return (
                  <div key={region} className="regions-multiselect__tag-wrapper">
                    <span className="regions-multiselect__tag">
                      {regionLabel}
                    </span>
                    <div
                      className="regions-multiselect__tag-remove"
                      role="button"
                      tabIndex={0}
                      onClick={e => {
                        e.stopPropagation();
                        handleRemoveRegion(region, e);
                      }}
                      onKeyDown={e => {
                        if (e.key === "Enter" || e.key === " ") {
                          e.preventDefault();
                          e.stopPropagation();
                          handleRemoveRegion(region, e);
                        }
                      }}
                    >
                      ×
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {selectedRegions.length === 0 && (
            <span className="regions-multiselect__placeholder">{placeholder}</span>
          )}

          <div className="regions-multiselect__arrow">
            <svg width="12" height="8" viewBox="0 0 12 8" fill="none">
              <path d="M1 1L6 6L11 1" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
        </button>

        {isOpen && (
          <div className="regions-multiselect__dropdown">
            <ul className="regions-multiselect__options-list">
              {options.length > 0 ? (
                options.map((region, i) => (
                  <li key={region}>
                    <button
                      type="button"
                      ref={el => {
                        optionRefs.current[i] = el;
                      }}
                      tabIndex={focusedOptionIndex === i ? 0 : -1}
                      className={`regions-multiselect__option ${
                        selectedRegions.includes(region) ? "regions-multiselect__option--selected" : ""
                      }`}
                      onClick={e => handleRegionToggle(region, e)}
                      onKeyDown={e => handleOptionKeyDown(e, i)}
                    >
                      <input
                        type="checkbox"
                        checked={selectedRegions.includes(region)}
                        readOnly
                        tabIndex={-1}
                        className="regions-multiselect__checkbox"
                      />
                      <span className="regions-multiselect__option-text">
                        {currentLanguage === "he" && REGIONS_DICTIONARY[region] ? REGIONS_DICTIONARY[region] : region}
                      </span>
                    </button>
                  </li>
                ))
              ) : (
                <li className="regions-multiselect__no-options">
                  No regions available
                </li>
              )}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
};

export default RegionsMultiSelect;
