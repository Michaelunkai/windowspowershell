"use client";

import Image from "next/image";
import Link from "next/link";
import { ExternalLink, Github, Smartphone } from "lucide-react";
import { motion } from "framer-motion";
import type { Project } from "@/data/portfolio";

interface ProjectCardProps {
  project: Project;
}

export default function ProjectCard({ project }: ProjectCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, ease: "easeOut" }}
      className="bg-[#0f1020] rounded-2xl border border-white/[0.07] overflow-hidden hover:border-accent-purple/30 hover:-translate-y-1 transition-all group"
    >
      {/* Project Image */}
      <div className="relative h-48 bg-[#141528] overflow-hidden">
        <Image
          src={project.image}
          alt={project.name}
          fill
          className="object-cover group-hover:scale-105 transition-transform duration-500"
          sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-[#0f1020] to-transparent opacity-60" />
      </div>

      {/* Content */}
      <div className="p-6">
        <h3 className="text-xl font-semibold text-white mb-1">{project.name}</h3>
        <p className="text-accent-purpleLight text-sm mb-3">{project.tagline}</p>
        <p className="text-gray-400 text-sm mb-4 line-clamp-2">
          {project.description}
        </p>

        {/* Tech Tags */}
        <div className="flex flex-wrap gap-2 mb-4">
          {project.tech.map((tech) => (
            <span
              key={tech}
              className="px-2 py-1 bg-accent-purple/10 text-accent-purpleLight text-xs rounded-md"
            >
              {tech}
            </span>
          ))}
        </div>

        {/* Links */}
        <div className="flex items-center gap-3">
          {project.links.website && (
            <Link
              href={project.links.website}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-sm text-gray-400 hover:text-white transition-colors"
            >
              <ExternalLink className="w-4 h-4" />
              Website
            </Link>
          )}
          {project.links.source && (
            <Link
              href={project.links.source}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-sm text-gray-400 hover:text-white transition-colors"
            >
              <Github className="w-4 h-4" />
              Source
            </Link>
          )}
          {project.links.app && (
            <Link
              href={project.links.app}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-sm text-gray-400 hover:text-white transition-colors"
            >
              <Smartphone className="w-4 h-4" />
              App
            </Link>
          )}
        </div>
      </div>
    </motion.div>
  );
}
