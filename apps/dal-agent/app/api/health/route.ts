import { NextResponse } from "next/server";
export function GET() {
  return NextResponse.json({
    name: "dal-agent",
    status: "ok",
    mode: process.env.DAL_MODE || "live",
    time: new Date().toISOString()
  });
}