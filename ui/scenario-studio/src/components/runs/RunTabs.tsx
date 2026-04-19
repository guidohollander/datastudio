"use client";

import { useState } from "react";

type Tab = "capture" | "analysis" | "replay";

export default function RunTabs({
  isEnded,
  children,
}: {
  isEnded: boolean;
  children: {
    capture: React.ReactNode;
    analysis: React.ReactNode;
    replay: React.ReactNode;
  };
}) {
  const [activeTab, setActiveTab] = useState<Tab>("replay");

  const tabs: { id: Tab; label: string; description: string; disabled?: boolean }[] = [
    {
      id: "capture",
      label: "Capture",
      description: "Start/end capture and view captured data",
    },
    {
      id: "analysis",
      label: "Analysis",
      description: "Sequence diagram, relationships, and data structure",
      disabled: !isEnded,
    },
    {
      id: "replay",
      label: "Replay",
      description: "Configure variability and replay data",
      disabled: !isEnded,
    },
  ];

  return (
    <div className="w-full">
      {/* Tab Navigation */}
      <div className="border-b border-zinc-200 bg-white">
        <div className="flex gap-1">
          {tabs.map((tab) => {
            const isActive = activeTab === tab.id;
            const isDisabled = tab.disabled;

            return (
              <button
                key={tab.id}
                onClick={() => !isDisabled && setActiveTab(tab.id)}
                disabled={isDisabled}
                className={`relative px-6 py-4 text-sm font-medium transition-colors ${
                  isActive
                    ? "text-blue-600"
                    : isDisabled
                    ? "text-zinc-400 cursor-not-allowed"
                    : "text-zinc-600 hover:text-zinc-900"
                }`}
              >
                <div className="flex flex-col items-start gap-1">
                  <span>{tab.label}</span>
                  <span className="text-xs font-normal text-zinc-500">
                    {tab.description}
                  </span>
                </div>
                {isActive && (
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600" />
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Tab Content */}
      <div className="py-8">
        {activeTab === "capture" && children.capture}
        {activeTab === "analysis" && children.analysis}
        {activeTab === "replay" && children.replay}
      </div>
    </div>
  );
}
