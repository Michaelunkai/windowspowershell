import { useState, useEffect, useRef } from "react";

/**
 * Keeps a local input value in sync with an externally controlled value.
 * Uses a ref to track the previous external value and syncs state in an effect.
 */
export function useControlledInput(externalValue) {
  const [localValue, setLocalValue] = useState(externalValue || "");
  const prevExternalRef = useRef(externalValue);

  useEffect(() => {
    if (externalValue !== prevExternalRef.current) {
      prevExternalRef.current = externalValue;
      // Intentional: ref guard prevents cascading renders; syncing local state to an external reset (e.g. "Clear All")
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setLocalValue(externalValue || "");
    }
  }, [externalValue]);

  return [localValue, setLocalValue];
}
