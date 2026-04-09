"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { ExternalLink, Github, Star } from "lucide-react";
import { fadeUp, fadeUpProps } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";

export default function FeaturedProject() {
  const featuredProject = portfolio.projects.find((p) => p.featured);

  if (!featuredProject) return null;

  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <motion.div variants={fadeUp} {...fadeUpProps} className="text-center mb-12">
          <div className="inline-flex items-center gap-2 mb-4">
            <Star className="w-5 h-5 text-accent-purple fill-accent-purple" />
            <span className="text-accent-purpleLight font-medium">
              Featured Project
            </span>
          </div>
        </motion.div>

        <motion.div
          variants={fadeUp}
          {...fadeUpProps}
          className="relative bg-[#0f1020] rounded-3xl border border-accent-purple/20 overflow-hidden shadow-[0_0_60px_-15px_rgba(124,58,237,0.3)]"
        >
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 p-8 lg:p-12">
            {/* Content */}
            <div className="flex flex-col justify-center order-2 lg:order-1">
              <h3 className="text-3xl sm:text-4xl font-bold text-white mb-2">
                {featuredProject.name}
              </h3>
              <p className="text-accent-purpleLight text-lg mb-4">
                {featuredProject.tagline}
              </p>
              <p className="text-gray-400 mb-6">{featuredProject.description}</p>

              {/* Tech Tags */}
              <div className="flex flex-wrap gap-2 mb-8">
                {featuredProject.tech.map((tech) => (
                  <span
                    key={tech}
                    className="px-3 py-1.5 bg-accent-purple/10 text-accent-purpleLight text-sm rounded-lg border border-accent-purple/20"
                  >
                    {tech}
                  </span>
                ))}
              </div>

              {/* Buttons */}
              <div className="flex flex-wrap gap-4">
                {featuredProject.links.website && (
                  <Link
                    href={featuredProject.links.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-6 py-3 bg-accent-purple text-white rounded-xl font-medium hover:bg-accent-purpleLight transition-colors"
                  >
                    <ExternalLink className="w-4 h-4" />
                    View Live
                  </Link>
                )}
                {featuredProject.links.source && (
                  <Link
                    href={featuredProject.links.source}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-6 py-3 border border-white/10 text-white rounded-xl font-medium hover:bg-white/5 transition-colors"
                  >
                    <Github className="w-4 h-4" />
                    Source Code
                  </Link>
                )}
              </div>
            </div>

            {/* Image */}
            <div className="relative order-1 lg:order-2">
              <div className="relative aspect-video rounded-2xl overflow-hidden bg-[#141528]">
                <Image
                  src={featuredProject.image}
                  alt={featuredProject.name}
                  fill
                  className="object-cover"
                  sizes="(max-width: 1024px) 100vw, 50vw"
                  priority
                />
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
