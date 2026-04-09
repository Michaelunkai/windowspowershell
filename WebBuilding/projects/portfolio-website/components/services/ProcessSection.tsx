"use client";

import { motion } from "framer-motion";
import { fadeUpFast } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";
import ProcessCard from "@/components/ui/ProcessCard";

export default function ProcessSection() {
  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <motion.div
          {...fadeUpFast}
          className="text-center mb-12"
        >
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            How I Work
          </h2>
          <p className="text-gray-400 max-w-2xl mx-auto">
            A proven, streamlined process from discovery to delivery - designed to
            build reliable infrastructure with zero surprises.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {portfolio.process.map((step, index) => (
            <ProcessCard key={step.step} step={step} index={index} />
          ))}
        </div>
      </div>
    </section>
  );
}
