import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "VAE — Create. Publish. Connect.",
  description: "A quiet space to create media, connect your channels, and share what matters.",
  icons: { icon: "/favicon.svg" },
};

// Kept in sync with --bg in globals.css (the Nocturne obsidian ground), so
// the browser chrome on mobile matches the app rather than sitting a few
// shades off it.
export const viewport: Viewport = { themeColor: "#171014", colorScheme: "dark" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <head>
        {/*
          Fonts are loaded with plain <link> tags rather than `next/font/google`
          on purpose. `next/font` downloads and self-hosts the files at BUILD
          time, which turns every production build into something that needs
          network access to Google — a CI or air-gapped build fails outright.
          These links resolve at request time instead, so a build never depends
          on them, and the `--font-*` stacks in globals.css all carry real
          system fallbacks for when they don't resolve either.

          Three families, three jobs: Playfair Display for display type only,
          Manrope for all UI text, JetBrains Mono for anything tabular.
        */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=Playfair+Display:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
