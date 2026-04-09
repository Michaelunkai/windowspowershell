import type { Variants } from "framer-motion";

// Immediate fade in - no delay
export const fadeIn: Variants = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
};

export const fadeInFast = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
  transition: { duration: 0.3, ease: [0.25, 0.1, 0.25, 1] },
};

// Quick fade up with minimal delay
export const fadeUp: Variants = {
  initial: { opacity: 0, y: 20 },
  whileInView: { opacity: 1, y: 0 },
};

export const fadeUpProps = {
  initial: "initial",
  whileInView: "whileInView",
  viewport: { once: true, amount: 0.1, margin: "0px 0px -100px 0px" },
  transition: { duration: 0.4, ease: [0.25, 0.1, 0.25, 1] },
};

export const fadeUpFast = {
  initial: { opacity: 0, y: 15 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, amount: 0.1, margin: "0px 0px -100px 0px" },
  transition: { duration: 0.3, ease: [0.25, 0.1, 0.25, 1] },
};

export const staggerContainer: Variants = {
  initial: {},
  whileInView: { transition: { staggerChildren: 0.08 } },
};

export const staggerChild: Variants = {
  initial: { opacity: 0, y: 15 },
  whileInView: { opacity: 1, y: 0 },
};

export const staggerChildTransition = { 
  duration: 0.3, 
  ease: [0.25, 0.1, 0.25, 1] as const 
};

export const expandHeight = {
  initial: { height: 0, opacity: 0 },
  animate: { height: "auto", opacity: 1 },
  exit: { height: 0, opacity: 0 },
  transition: { duration: 0.3, ease: [0.25, 0.1, 0.25, 1] as const },
};

// Count up animation for stats
export const countUp = {
  initial: { opacity: 0, scale: 0.8 },
  whileInView: { opacity: 1, scale: 1 },
  viewport: { once: true, amount: 0.5 },
  transition: { duration: 0.4, ease: [0.25, 0.1, 0.25, 1] },
};
