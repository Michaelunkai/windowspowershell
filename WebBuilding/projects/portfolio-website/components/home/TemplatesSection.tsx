"use client";

import { motion } from "framer-motion";
import { fadeUp, fadeUpProps } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";
import TemplateCard from "@/components/ui/TemplateCard";

export default function TemplatesSection() {
  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8 bg-[#0a0b14]">
      <div className="max-w-7xl mx-auto">
        <motion.div variants={fadeUp} {...fadeUpProps} className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            Free Templates
          </h2>
          <p className="text-gray-400 max-w-2xl mx-auto">
            Open-source templates to kickstart your next project. Free to use and
            customize.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {portfolio.templates.map((template) => (
            <TemplateCard key={template.name} template={template} />
          ))}
        </div>
      </div>
    </section>
  );
}
