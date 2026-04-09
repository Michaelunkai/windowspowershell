"use client";

import { motion } from "framer-motion";
import type { Stat } from "@/data/portfolio";

interface StatCardProps {
  stat: Stat;
  index: number;
}

export default function StatCard({ stat, index }: StatCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, ease: "easeOut", delay: index * 0.1 }}
      className="bg-[#0f1020] rounded-xl border border-white/[0.07] p-4 text-center"
    >
      <div className="text-2xl sm:text-3xl font-bold text-accent-purple mb-1">
        {stat.value}
      </div>
      <div className="text-sm text-gray-400">{stat.label}</div>
    </motion.div>
  );
}
