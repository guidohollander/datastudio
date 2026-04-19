"use client";

import { useState } from "react";

export default function ExpressionHelp() {
  const [isOpen, setIsOpen] = useState(false);

  const expressions = [
    {
      name: "seq()",
      description: "Sequential numbers starting from 1",
      example: "seq()",
      result: "1, 2, 3, 4, 5...",
      useCase: "Generate unique IDs, sequential names, or counters",
    },
    {
      name: "unique(table, column)",
      description: "Generate unique values starting from max existing value + 1",
      example: "unique(SC_PERSONREGISTRATION_PROPERTIES, CASEID)",
      result: "175039, 175040, 175041... (continues from max)",
      useCase: "Avoid primary key violations by generating unique IDs",
    },
    {
      name: "newguid()",
      description: "Generate unique GUID for each item",
      example: "newguid()",
      result: "A7F3B2C1-..., 8D4E5F6A-..., 2B1C3D4E-... (unique GUIDs)",
      useCase: "Business keys like PERSONGUID that need unique identifiers",
    },
    {
      name: "ctx(variableName)",
      description: "Retrieve value from person context for consistency",
      example: "ctx(firstName), ctx(surname), ctx(gender)",
      result: "Same value across all components for one person",
      useCase: "Ensure firstName, surname, gender, dateOfBirth are consistent across individual, properties, etc.",
    },
    {
      name: "lookup(refTableName)",
      description: "Pick random valid CODE from reference table",
      example: "lookup(NATIONALITY), lookup(COUNTRY), lookup(GENDER)",
      result: "Valid reference ID from SC_PERSONREGISTRATION_CONVERSION_REF_* table",
      useCase: "Use for lookup/reference fields that must reference valid IDs from reference tables",
    },
    {
      name: "pool(poolName)",
      description: "Random value from reference data pool with weighting",
      example: "pool(firstNames.male)",
      result: "Jan, Willem, Daan, Piet... (weighted random)",
      useCase: "Realistic names, cities, occupations from curated lists",
    },
    {
      name: "weighted(A:51|B:49)",
      description: "Weighted random selection with percentages",
      example: "weighted(Male:51|Female:49)",
      result: "51% Male, 49% Female distribution",
      useCase: "Realistic demographic distributions",
    },
    {
      name: "random(min, max)",
      description: "Random integer in range",
      example: "random(1, 100)",
      result: "42, 17, 89, 3...",
      useCase: "Random numbers, IDs, quantities",
    },
    {
      name: "dateRange(start, end)",
      description: "Random date in range",
      example: "dateRange(2020-01-01, 2025-12-31)",
      result: "2022-05-15, 2024-03-22...",
      useCase: "Random dates for events, registrations",
    },
    {
      name: "ageRange(min, max)",
      description: "Date of birth based on age range",
      example: "ageRange(25, 65)",
      result: "1985-03-12, 1972-11-05... (current age 25-65)",
      useCase: "Realistic birth dates for working age population",
    },
    {
      name: "pick(A|B|C)",
      description: "Rotate through values separated by |",
      example: "pick(Male|Female)",
      result: "Male, Female, Male, Female...",
      useCase: "Cycle through predefined options",
    },
    {
      name: "literal('text')",
      description: "Fixed value for all items",
      example: "literal('Test User')",
      result: "Test User, Test User, Test User...",
      useCase: "Set constant values",
    },
    {
      name: "concat(...)",
      description: "Combine multiple values or expressions",
      example: "concat('User ', seq())",
      result: "User 1, User 2, User 3...",
      useCase: "Build complex values from multiple parts",
    },
    {
      name: "email(first, last, domain)",
      description: "Generate email addresses",
      example: "email(pool(firstNames.male), pool(surnames.dutch), pool(emailDomains))",
      result: "jan.dejong@gmail.com, willem.jansen@hotmail.com...",
      useCase: "Realistic email addresses",
    },
  ];

  return (
    <div className="rounded-xl border border-blue-200 bg-blue-50">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex w-full items-center justify-between p-4 text-left"
      >
        <div>
          <div className="text-sm font-medium text-blue-900">
            📖 Expression Language Help
          </div>
          <div className="mt-1 text-xs text-blue-700">
            Learn how to use transformation expressions
          </div>
        </div>
        <div className="text-blue-600">{isOpen ? "▼" : "▶"}</div>
      </button>

      {isOpen && (
        <div className="border-t border-blue-200 p-4">
          <div className="space-y-4">
            {expressions.map((expr) => (
              <div key={expr.name} className="rounded-lg bg-white p-4">
                <div className="flex items-start gap-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <code className="rounded bg-zinc-100 px-2 py-1 text-sm font-medium text-zinc-900">
                        {expr.name}
                      </code>
                      <span className="text-xs text-zinc-600">{expr.description}</span>
                    </div>

                    <div className="mt-3 grid gap-2 text-xs">
                      <div>
                        <span className="font-medium text-zinc-700">Example:</span>
                        <code className="ml-2 rounded bg-zinc-50 px-2 py-1 text-zinc-900">
                          {expr.example}
                        </code>
                      </div>
                      <div>
                        <span className="font-medium text-zinc-700">Result:</span>
                        <span className="ml-2 text-zinc-600">{expr.result}</span>
                      </div>
                      <div>
                        <span className="font-medium text-zinc-700">Use case:</span>
                        <span className="ml-2 text-zinc-600">{expr.useCase}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}

            <div className="rounded-lg bg-yellow-50 p-4">
              <div className="text-xs font-medium text-yellow-900">💡 Tips & Context System</div>
              <ul className="mt-2 space-y-1 text-xs text-yellow-800">
                <li>• Leave empty to use the example value from captured data</li>
                <li>• <strong>Context variables (auto-generated per person):</strong> firstName, surname, gender, dateOfBirth, personGuid, nationality, placeOfBirth</li>
                <li>• Use ctx(firstName), ctx(surname), etc. to ensure consistency across components</li>
                <li>• <strong>Available pools:</strong> firstNames.male, firstNames.female, surnames.dutch, cities.netherlands, countries.iso, occupations, gender, resident, emailDomains</li>
                <li>• pool() uses weighted random - more common values appear more often</li>
                <li>• Nest expressions: concat(ctx(firstName), &apos; &apos;, ctx(surname))</li>
              </ul>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
