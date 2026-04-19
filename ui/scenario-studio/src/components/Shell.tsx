import { AppLink } from "@/lib/links";
import { RecordingBadge } from "@/components/RecordingBadge";

const nav = [
  { href: "/runs", label: "Runs" },
  { href: "/scenarios", label: "Scenarios" },
  { href: "/admin", label: "Admin" },
];

export default async function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-dvh" style={{ background: 'var(--background)', color: 'var(--foreground)' }}>
      <header 
        className="sticky top-0 z-20 border-b" 
        style={{ 
          borderColor: 'var(--border)', 
          backgroundColor: '#ffffff',
          boxShadow: 'var(--shadow-sm)'
        }}
      >
        <div className="flex w-full items-center justify-between gap-4 px-6 py-4">
          <div className="flex items-center gap-4">
            <AppLink 
              href="/runs" 
              className="text-xl font-bold tracking-tight" 
              target="_self"
              style={{ color: 'var(--primary)' }}
            >
              Scenario Studio
            </AppLink>
            <nav className="hidden items-center gap-1 md:flex">
              {nav.map((n) => (
                <AppLink
                  key={n.href}
                  href={n.href}
                  target="_self"
                  className="rounded-full px-3 py-1.5 text-sm font-medium transition-colors"
                  style={{ color: 'var(--text-secondary)' }}
                >
                  {n.label}
                </AppLink>
              ))}
            </nav>
          </div>
          <div className="flex items-center gap-3">
            <RecordingBadge />
          </div>
        </div>
      </header>

      <main className="w-full px-6 py-10">{children}</main>
    </div>
  );
}
