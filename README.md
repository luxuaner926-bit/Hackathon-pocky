# SilverSight AI: Hackathon Package

A visual wayfinding companion for older residents. This package holds the working prototype, the data behind it and the concept proposal.

Pilot route: **Block 124, Ang Mo Kio Ave 6 → NHG Ang Mo Kio Polyclinic, 21 Ang Mo Kio Central 2.**

## Open the demos

**Online, recommended.** All features work there, including photo matching. These links are private until shared from each page's Share menu.
- Phone & Watch app: https://claude.ai/artifact/7rRfcF1oYbFgcTsvHqr4fH
- Route analysis & team view: https://claude.ai/artifact/Tajr3rESk7D2qGnCr337LM

**GitHub Pages:** in the repository, go to *Settings → Pages*, set *Source* to *Deploy from a branch*, then choose `main` and `/ (root)`. After a minute the demos are live at `https://<your-username>.github.io/<repo-name>/`, with every feature working, including photo matching.

**Offline:** open `index.html` in Chrome, Edge or Safari. Everything works except one thing: the "Take a photo" matching may report "can't match" when the page is opened straight from a file. This is because browsers block reading image pixels from `file://` pages. To fix it, serve the folder from a local web server, for example `npx serve .` (Node) or `python -m http.server` (Python), then open http://localhost:3000 or http://localhost:8000.

## What's inside

| Path | What it is |
|---|---|
| `index.html` | Start page linking everything |
| `phone-and-watch.html` | Phone app and Apple Watch companion, kept in sync |
| `planner-view.html` | Step-by-step demo with route comparison and the team/planner view |
| `photos/` | Street View photos per turn (`amk-*`, `est-*`), test photos (`test-*`), mini maps (`maps/`), overhead shade photos (`sky/`), route map |
| `analysis/analyse.ps1` | Samples each route every 40 m and measures open sky overhead (shade) |
| `analysis/match-calibration.ps1` | Checks the photo-matching thresholds on the test photos |
| `analysis/*.json` | Raw Google Routes API responses and the shade analysis output |
| `docs/` | Concept proposal (PDF) |

## Suggested demo script (about 3 minutes)

1. **Profile:** turn on Stairs, Resting points and Shelter, then tap *Save my preferences*.
2. **Home:** tap *Clinic*.
3. **Route options:** the Comfort route is "Best for you" (42% shade, 2 rest points, quiet paths). Switch to *Shortest* to show the trade-off. The Park route is High risk with 5 sets of stairs.
4. **Start walking:** follow the glowing landmark and arrows. The watch shows the same step and shakes ("Tap tap") at each turn.
5. **At the plaza step:** tap *?*, then *Plaza* in the samples. The app recognises the colourful tables. Then try *Mall*: the app says it can't match the photo and offers help rather than guessing.
6. **Arrive:** flag "Needed more shade" and send. Show it under *Journeys*.
7. **Planner angle:** open the team view and show that two routes share the same steps 245 m from Block 124. A ramp there would remove the stair risk on both.

## How the route decisions are made

- **Routes:** Google Routes API, walking mode. Alternatives were made by routing through points east and west of Ave 6.
- **Steps:** counted where Google's directions say "Take the steps".
- **Shade:** a Street View photo pointed straight up every 40 m. A point counts as shaded when less than 45% of the view is open sky (roofs, trees).
- **Risk score:** each set of steps adds 2 points; little shade adds up to 3; a long sunny stretch adds 1–2; a walk over 900 m adds 1–2; more than 300 m beside a main road adds 1. Under 4 is Low, 4 to under 8 is Medium, 8 or more is High. The resident's profile doubles the factors they care about when ranking routes.
- **Photo help:** compares the resident's photo with the route's checked photos by colour and layout. It answers only when one match is clearly ahead; otherwise it offers choices or a helper. This is a stand-in for Gemini in the full app.

## Limits

- **Nothing has been walked on site yet.** Every step is a draft from Google data. The step-1 photo (inside the estate) is missing because Street View has no coverage there.
- **Street View photos are taken from the road, not the footpath, and date from 2021–2024.** The construction site on the Shortest route has probably changed.
- **Shade is an estimate.** A white tent roof can be mistaken for cloudy sky.
- **Ramps and rest points come from photos, not from a survey.**
- **There is no lighting data yet.**
- **"Mdm Tan" and the helper's phone number are example data.**
- **Google's terms limit storing Street View images.** These copies are for this prototype only. A real app should load images live with a restricted API key.

## Re-running the analysis

The scripts run in Windows PowerShell 5.1 and need a Google Maps Platform key with the Routes, Street View Static and Maps Static APIs enabled. No key is stored in this package.

```powershell
.\analysis\analyse.ps1 -Key "<your key>" -Scratch .\analysis -OutDir .\photos
```

The route JSON files the script reads are already in `analysis/`. To analyse a new walk, request it from the Routes API and save it there first.
