import { NextResponse } from "next/server";

export function middleware() {
  // Basic Auth temporarily disabled for development
  // Re-enable only with environment-provided credentials; do not commit fallback values.
  
  /*
  import basicAuth from "basic-auth";
  import type { NextRequest } from "next/server";

  const user = process.env.BASIC_AUTH_USER;
  const pass = process.env.BASIC_AUTH_PASSWORD;

  if (!user || !pass) {
    throw new Error("BASIC_AUTH_USER and BASIC_AUTH_PASSWORD must be set");
  }

  const auth = basicAuth({
    headers: {
      authorization: req.headers.get("authorization") ?? undefined,
    },
  });

  if (!auth || auth.name !== user || auth.pass !== pass) {
    return new NextResponse("Authentication required", {
      status: 401,
      headers: {
        "WWW-Authenticate": "Basic realm=\"Scenario Studio\"",
      },
    });
  }
  */

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|robots.txt).*)"],
};
