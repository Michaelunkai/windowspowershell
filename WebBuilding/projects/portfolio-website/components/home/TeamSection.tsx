"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import { Github, Linkedin, Download, ChevronDown, ChevronUp, FileText } from "lucide-react";
import { fadeUp, fadeUpProps } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";

export default function TeamSection() {
  const [showResumes, setShowResumes] = useState(false);

  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8 bg-[#0a0b14]">
      <div className="max-w-4xl mx-auto">
        <motion.div variants={fadeUp} {...fadeUpProps} className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            About Me
          </h2>
          <p className="text-gray-400">
            The person behind the infrastructure and automation.
          </p>
        </motion.div>

        <motion.div
          variants={fadeUp}
          {...fadeUpProps}
          className="bg-[#0f1020] rounded-3xl border border-white/[0.07] p-8 text-center"
        >
          {/* Avatar */}
          <div className="relative w-32 h-32 mx-auto mb-6 rounded-full overflow-hidden border-4 border-accent-purple/30">
            <Image
              src={portfolio.personal.avatar}
              alt={portfolio.personal.name}
              fill
              className="object-cover"
              sizes="128px"
              priority
            />
          </div>

          {/* Name & Role */}
          <h3 className="text-2xl font-bold text-white mb-1">
            {portfolio.personal.name}
          </h3>
          <p className="text-accent-purpleLight mb-4">
            {portfolio.personal.title}
          </p>

          {/* Bio */}
          <p className="text-gray-400 max-w-lg mx-auto mb-6">
            {portfolio.personal.bio}
          </p>

          {/* Social Links */}
          <div className="flex items-center justify-center gap-4 mb-6">
            <Link
              href={portfolio.socials.github}
              target="_blank"
              rel="noopener noreferrer"
              className="p-3 rounded-xl bg-white/5 text-gray-400 hover:text-white hover:bg-white/10 transition-colors"
              aria-label="GitHub"
            >
              <Github className="w-6 h-6" />
            </Link>
            <Link
              href={portfolio.socials.linkedin}
              target="_blank"
              rel="noopener noreferrer"
              className="p-3 rounded-xl bg-white/5 text-gray-400 hover:text-white hover:bg-white/10 transition-colors"
              aria-label="LinkedIn"
            >
              <Linkedin className="w-6 h-6" />
            </Link>
          </div>

          {/* Resume Download Section */}
          <div className="border-t border-white/[0.07] pt-6">
            <button
              onClick={() => setShowResumes(!showResumes)}
              className="inline-flex items-center gap-2 px-6 py-3 bg-accent-purple text-white rounded-xl font-medium hover:bg-accent-purpleLight transition-colors"
            >
              <Download className="w-5 h-5" />
              Download Résumé
              {showResumes ? (
                <ChevronUp className="w-4 h-4" />
              ) : (
                <ChevronDown className="w-4 h-4" />
              )}
            </button>

            <AnimatePresence>
              {showResumes && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.3, ease: [0.25, 0.1, 0.25, 1] }}
                  className="overflow-hidden"
                >
                  <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                    {portfolio.resumes.map((resume) => (
                      <Link
                        key={resume.name}
                        href={resume.file}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-3 p-4 bg-[#141528] rounded-xl border border-white/[0.07] hover:border-accent-purple/30 transition-colors group"
                      >
                        <FileText className="w-5 h-5 text-accent-purple" />
                        <div className="text-left">
                          <div className="text-sm font-medium text-white group-hover:text-accent-purpleLight transition-colors">
                            {resume.name}
                          </div>
                          <div className="text-xs text-gray-500">PDF Download</div>
                        </div>
                      </Link>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
