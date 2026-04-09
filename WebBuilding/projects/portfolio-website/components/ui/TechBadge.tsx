"use client";

import * as SiIcons from "react-icons/si";
import { cn } from "@/lib/utils";

interface TechBadgeProps {
  name: string;
  icon?: string | null;
}

export default function TechBadge({ name, icon }: TechBadgeProps) {
  const IconComponent = icon
    ? (SiIcons as Record<string, React.ComponentType<{ className?: string }>>)[icon]
    : null;

  return (
    <div
      className={cn(
        "inline-flex items-center gap-2 px-3 py-1.5",
        "bg-[#0f1020] border border-white/[0.07] rounded-full",
        "text-sm text-gray-300 hover:border-accent-purple/30 transition-colors"
      )}
    >
      {IconComponent && <IconComponent className="w-4 h-4 text-accent-purple" />}
      <span>{name}</span>
    </div>
  );
}
