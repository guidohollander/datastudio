import { NextResponse } from "next/server";

export function proxy() {
  // Basic Auth temporarily disabled for development.
  // Re-enable only with environment-provided credentials; do not commit fallback values.
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|robots.txt).*)"],
};
