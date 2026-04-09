"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown, ChevronUp } from "lucide-react";
import { fadeUp, fadeUpProps } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";
import ProjectCard from "@/components/ui/ProjectCard";

export default function ProjectsSection() {
  const [showAll, setShowAll] = useState(false);

  const nonFeaturedProjects = portfolio.projects.filter((p) => !p.featured);
  const visibleProjects = showAll
    ? nonFeaturedProjects
    : nonFeaturedProjects.slice(0, 2);
  const hasMoreProjects = nonFeaturedProjects.length > 2;

  return (
    <section id="projects" className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <motion.div variants={fadeUp} {...fadeUpProps} className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            More Projects
          </h2>
          <p className="text-gray-400 max-w-2xl mx-auto">
            Explore more of my work across different technologies and domains.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {visibleProjects.map((project) => (
            <ProjectCard key={project.id} project={project} />
          ))}
        </div>

        <AnimatePresence>
          {showAll && nonFeaturedProjects.length > 2 && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.35, ease: [0.25, 0.1, 0.25, 1] }}
              className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6"
            >
              {nonFeaturedProjects.slice(2).map((project) => (
                <ProjectCard key={project.id} project={project} />
              ))}
            </motion.div>
          )}
        </AnimatePresence>

        {hasMoreProjects && (
          <motion.div variants={fadeUp} {...fadeUpProps} className="text-center mt-10">
            <button
              onClick={() => setShowAll(!showAll)}
              className="inline-flex items-center gap-2 px-6 py-3 border border-white/10 text-white rounded-xl font-medium hover:bg-white/5 transition-colors"
            >
              {showAll ? (
                <>
                  Show Less
                  <ChevronUp className="w-4 h-4" />
                </>
              ) : (
                <>
                  Show All Projects
                  <ChevronDown className="w-4 h-4" />
                </>
              )}
            </button>
          </motion.div>
        )}
      </div>
    </section>
  );
}
