# VAE editorial UI

The creator journey is Home → Create → Publish → Analytics, with Profile and secondary tools accessible from the account/command menu. Desktop web includes Profile in its rail; phone web gives Create the center position. Flutter uses bottom navigation on phones and a rail at 720px and above.

## Shared design tokens

Edit `packages/shared/design-tokens.json`, then run:

```sh
python scripts/design_tokens.py
python scripts/design_tokens.py --check
```

The generated CSS and Dart files supply the shared dark/light palette. Existing web and Flutter themes consume these values. The manifest also records typography, spacing, radii, and motion timing.

## Implemented behavior

- Editorial landing copy, preserved MOV artwork, delayed WebGL, and reduced-motion/visibility-aware web video.
- Focused navigation with brand knowledge and admin tools under More/Command.
- Home metrics, recent assets, and publishing timeline.
- Image/text composer, aspect ratio and explicit output count, retained draft prompts, compact paginated asset libraries, and full-screen previews.
- Asset uploads and direct selection for publishing, caption editing, channel selection, schedule validation, review confirmation, and channel delivery results.
- Flutter provider connection handoff to the system browser, reconnect/disconnect controls, and refresh on return.
- Scrollable profile editing with avatar uploads, account fields, password updates, theme controls, and sign-out confirmation.
- Channel/date filters, performance summaries, recent post metrics, and empty states.
- Flutter brand creation, source ingestion, source search, and admin usage details under More/Command.
- Shared Flutter headers, glass cards, metrics, primary actions, status pills, asset tiles, bottom navigation, and profile sheet.
- Web dialog focus containment and Escape handling, larger touch targets, and a natural document scroll on phones.

## Verification

Screenshots in this directory use synthetic local fixture data, not a real account or published content. The fixture at `tests/e2e/fixtures/mock_ui_api.py` accepts GET only and rejects write requests. It is not part of the production application.

Browser checks covered the landing page at 1280px and 320px, the authenticated creator composer at 320px, the desktop shell in light mode at 1440px, direct asset-to-publish selection, and a 320px profile dialog with internal scrolling. Final modal verification confirmed that background content becomes inert, root scrolling locks, and Escape restores both. Observed document widths matched the viewport widths. Desktop screenshots cover Home, Create, Publish, and Analytics. Phone captures cover Publish and Profile in light mode. Production checks also confirmed retained composer drafts and no horizontal overflow at 768px, 1024px, and 1440px.

Flutter regression tests cover Home at 320px in both themes, the one-output default, retained prompt drafts, prevention of publishing without channels/content, and source validation/ingestion. Existing theme and brand-mark tests are retained.

## Remaining acceptance checks and API-dependent scope

- Verify Android/iOS file pickers, OAuth return behavior, media codecs, background lifecycle, and screen readers on actual devices. iOS builds require macOS.
- Exercise live generation, payment review, profile/password changes, and provider delivery against an authenticated backend. No live writes or publishing were performed during QA.
- The existing generation API contract exposes prompts and aspect ratios, but no reference-image conditioning parameter. Uploads add assets to the library; they are not silently passed off as generation references.
- Account deletion entries lead to deletion guidance; deletion execution is outside the available client API contract.
- No baseline before screenshots or mid-range-device performance measurements were captured.

Final automated checks: web Biome lint, TypeScript typecheck, and Next.js production build passed. Flutter analysis reported no issues, and all ten tests passed. Shared generated-token validation passed.

For local visual QA, run `python tests/e2e/fixtures/mock_ui_api.py` with port 8000 free, and start the web app on port 3000. Stop the fixture before connecting a real backend. The fixture only binds to loopback and must never be deployed.
