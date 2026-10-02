# App Store Connect og App Review – Kolorist

Tekster klare til å lime inn. Én app-post med universelt kjøp for iPhone, iPad og Mac (samme bundle-ID
`no.engenett.Kolorist`, plattformene iOS og macOS lagt til i samme post). Primærspråk: norsk (bokmål),
i tillegg engelsk. Tegngrensene står i parentes, og alle tekstene er innenfor.

---

## 1. App-informasjon (gjelder alle versjoner)

| Felt | Verdi |
|---|---|
| Navn (30) | **Kolorist** – er navnet opptatt: «Kolorist – fargepaletter» / «Kolorist: Color Palettes» |
| Bundle-ID | `no.engenett.Kolorist` |
| SKU | `kolorist-2026` (bare til eget bruk) |
| Primærkategori | Grafikk og design (Graphics & Design) |
| Sekundærkategori | Produktivitet (Productivity) |
| Opphavsrett | `2026 Eivind Arnstein Johansen` |
| Innholdsrettigheter | Nei, appen inneholder ikke, viser ikke og gir ikke tilgang til innhold fra tredjeparter |
| Aldersgrense | Svar «Nei/Ingen» på alt i spørreskjemaet → 4+. Ingen nettleser, ingen brukerinnhold som deles, ingen kjøp i appen. |
| Pris | Velg selv (gratis eller betalt). Ingen kjøp i appen. |
| Lisensavtale | Apples standard EULA |

### URL-er

| Felt | Norsk | Engelsk |
|---|---|---|
| Support URL | `https://kolorist.no/support.html` | `https://kolorist.no/en/support.html` |
| Marketing URL | `https://kolorist.no/` | `https://kolorist.no/en/` |
| Privacy Policy URL | `https://kolorist.no/privacy.html` | `https://kolorist.no/en/privacy.html` |

Nettsiden må være publisert før innsending; App Review åpner support- og personvernsidene.

### App Privacy (personvernetiketten)

- «Do you or your third-party partners collect data from this app?» → **No, we do not collect data from this app.**
- Resultat: **Data Not Collected**.
- Begrunnelse: ingen egne servere, ingen analyse, ingen krasjrapportering fra tredjepart, ingen reklame.
  CloudKit-synk går til brukerens private database, og det regnes ikke som innsamling hos utvikleren.
  Apple Intelligence kjøres på enheten.

### Eksportregler (kryptering)

Appen bruker bare kryptering som er innebygd i Apples operativsystem (HTTPS/CloudKit). Svar
**«None of the algorithms mentioned above»** / ingen ikke-unntatt kryptering. Settes
`ITSAppUsesNonExemptEncryption = NO` i Info.plist, slipper du spørsmålet ved hver opplasting (ikke lagt inn ennå).

---

## 2. Versjonstekster – norsk (bokmål)

**Undertittel (30)**

```
Fargepaletter for designere
```

**Reklametekst (170)**

```
Bygg paletter i OKLCH, CMYK med ICC-profiler, kontroller kontrast og fargesyn-problematikk, og kopier fargene rett inn i annen design-programvare.
```

**Beskrivelse (4000)**

```
Kolorist er et fargeverktøy for designere på iPhone, iPad og Mac. Bygg paletter på tvers av fargerom, med perseptuelt jevne overganger, kontrastsjekk, simulering av fargesyn og ICC-profiler – og få fargene inn i verktøyene du allerede bruker.

ALLE FARGEROMMENE
• Rediger i OKLCH, OKLab, CIE LCH, CIELab, HSB, HSL, RGB og CMYK
• Display P3 side om side med sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK eller en hvilken som helst ICC-profil
• Varsel når fargen er utenfor fargeområdet – farger kartlegges inn i fargerommet uten å klippes
• Angi CMYK eller RGB direkte i en valgt ICC-profil
• Rene CMYK-verdier: grått innslag flyttes til sort (UCR/GCR), med færrest mulig trykkfarger
• Feltet for fargeverdi forstår hex, CSS-farger og vanlige beskrivelser som «dyp havblå»

ICC-PROFILER
• Importer egne .icc- og .icm-profiler – de følger med til de andre enhetene dine via iCloud Drive
• Konverter mellom profiler og sammenlign gjengivelseshensiktene med ΔE2000

OVERGANGER, TONER OG HARMONIER
• Overganger i like perseptuelle steg i OKLab, med lysere og mørkere rader
• CSS-gradient i oklab med sRGB-reserve – lineær, radiell eller konisk
• Toneskalaer fra 50 til 950
• Komplementær, split-komplementær, analog og jevn fordeling på fargesirkel i OKLCH, CIE LCH, HSL eller RYB, med metning og lyshet for hele harmonien

TILGJENGELIGHET OG FARGESYN
• WCAG 2.2-kontrast: AA og AAA, stor tekst og grafikk, og «Rett opp» som justerer fargen til den består
• Kontrastmatrise for hele paletten
• Se paletten med protan-, deutan- og tritanavvik og akromatopsi, med valgfri alvorlighetsgrad – og hvilke farger som blir vanskelige å skille
• Kamera med fargesynsfilter: se omgivelsene slik de kan oppleves med hvert avvik

PLUKK FARGER
• Kamera med zoom, makrofokus og lykt
• Bilder, med dominerende farger
• Skjermpipette på Mac

APPLE INTELLIGENCE PÅ ENHETEN
• Fra verdiord til palett – «trygg, varm, nordisk» – forankret i en kunnskapsbase med over hundre fargebegreper
• Beskriv en farge og se den i Studio
• Juster med fritekst, navngi farger og få en vurdering av paletten
Alt kjøres på enheten. Uten Apple Intelligence lages palettene direkte fra kunnskapsbasen.

KOPIER TIL OG EKSPORT
• «Kopier til» designverktøy, layoutprogrammer, bilderedigering og presentasjonsprogrammer – i formatet hvert program tar imot, for enkeltfarger og hele paletter
• Dra fargeprøver rett inn i andre programmer på Mac
• Eksport til ASE- og ACO-fargeprøver, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI og hex
• Fargene eksporteres i formatet de er lagret i – for eksempel som CMYK

PALETTER OG ICLOUD
Samle farger i paletter, lagre enkeltfarger og hele gradienter, og synkroniser via din egen, private iCloud.

SIRI OG SNARVEIER
Lag palett fra verdiord, beskriv en farge, lag overgang, konverter farge og sjekk kontrast.

ÅPENT OM METODENE
Hver del av appen viser hvilke metoder den bygger på – OKLab, CSS Color 4, CIEDE2000, WCAG, simulering av fargesyn og ICC – med kilde og forklaring.

PERSONVERN
Ingen konto, ingen analyse, ingen reklame og ingen sporing. Utvikleren samler ikke inn data.

Krever iOS 26, iPadOS 26 eller macOS 26. Apple Intelligence krever en støttet enhet.
```

**Nøkkelord (100, kommaseparert uten mellomrom)**

```
farge,palett,fargekart,OKLCH,CMYK,ICC,kontrast,WCAG,overgang,gradient,pipette,harmoni,fargeblind,hex
```

**Nytt i denne versjonen** – brukes ikke for første versjon.

---

## 3. Versjonstekster – engelsk

**Subtitle (30)**

```
Color palettes for designers
```

**Promotional text (170)**

```
Build palettes in OKLCH, CMYK with ICC profiles, check for contrast and color vision challenges, and copy colors straight into other design software packages.
```

**Description (4000)**

```
Kolorist is a color tool for designers on iPhone, iPad and Mac. Build palettes across color spaces, with perceptually even gradients, contrast checks, color vision simulation and ICC profiles – and get your colors into the tools you already use.

EVERY COLOR SPACE
• Edit in OKLCH, OKLab, CIE LCH, CIELab, HSB, HSL, RGB and CMYK
• Display P3 side by side with sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK or any ICC profile
• Out-of-gamut warnings – colors are mapped into the color space instead of clipped
• Enter CMYK or RGB directly in a chosen ICC profile
• Clean CMYK values: grey components move to black (UCR/GCR), with as few inks as possible
• The color field understands hex, CSS colors and plain descriptions like “deep ocean blue”

ICC PROFILES
• Import your own .icc and .icm profiles – they follow you to your other devices through iCloud Drive
• Convert between profiles and compare rendering intents with ΔE2000

GRADIENTS, TONES AND HARMONIES
• Gradients in equal perceptual steps in OKLab, with lighter and darker rows
• CSS gradients in oklab with an sRGB fallback – linear, radial or conic
• Tone scales from 50 to 950
• Complementary, split complementary, analogous and even distributions on an OKLCH, CIE LCH, HSL or RYB color wheel, with saturation and lightness for the whole harmony

ACCESSIBILITY AND COLOR VISION
• WCAG 2.2 contrast: AA and AAA, large text and graphics, and auto-fix that adjusts the color until it passes
• Contrast matrix for the whole palette
• See the palette with protan, deutan and tritan deficiencies and achromatopsia, at any severity – and which colors become hard to tell apart
• Camera with a color vision filter: see your surroundings as they may appear with each deficiency

PICK COLORS
• Camera with zoom, macro focus and torch
• Photos, with dominant colors
• Screen eyedropper on Mac

APPLE INTELLIGENCE ON DEVICE
• From value words to a palette – “calm, warm, Nordic” – grounded in a knowledge base of more than a hundred color concepts
• Describe a color and see it in Studio
• Adjust with free text, name colors and get a critique of your palette
Everything runs on device. Without Apple Intelligence, palettes are built straight from the knowledge base.

COPY TO AND EXPORT
• “Copy to” design tools, layout apps, photo editors and presentation apps – in the format each app accepts, for single colors and whole palettes
• Drag swatches straight into other apps on Mac
• Export to ASE and ACO swatches, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI and hex
• Colors are exported in the format they were saved in – for example as CMYK

PALETTES AND ICLOUD
Collect colors in palettes, save single colors and whole gradients, and sync through your own private iCloud.

SIRI AND SHORTCUTS
Create a palette from value words, describe a color, create a gradient, convert a color and check contrast.

OPEN ABOUT METHODS
Every part of the app shows the methods it builds on – OKLab, CSS Color 4, CIEDE2000, WCAG, color vision simulation and ICC – with source and explanation.

PRIVACY
No account, no analytics, no ads and no tracking. The developer collects no data.

Requires iOS 26, iPadOS 26 or macOS 26. Apple Intelligence requires a supported device.
```

**Keywords (100)**

```
color,palette,picker,OKLCH,CMYK,ICC,contrast,WCAG,gradient,eyedropper,harmony,colorblind,hex,swatch
```

---

## 3b. Mac-versjonen (macOS) – norsk (bokmål)

macOS har egen versjonsside i App Store Connect, med egen reklametekst, beskrivelse, nøkkelord og skjermbilder.
Navn og undertittel er felles (App-informasjon), og iPad deler tekst med iPhone. Support- og markedsførings-URL
er de samme som for iOS.

**Reklametekst (170)**

```
Bygg paletter i OKLCH, CMYK med ICC-profiler, kontroller kontrast og fargesyn-problematikk, plukk farger fra hele skjermen og dra dem rett inn i annen design-programvare.
```

**Beskrivelse (4000)**

```
Kolorist er et fargeverktøy for designere på Mac – og på iPhone og iPad med samme kjøp. Bygg paletter på tvers av fargerom, med perseptuelt jevne overganger, kontrastsjekk, simulering av fargesyn og ICC-profiler – og få fargene inn i programmene du allerede bruker.

PLUKK OG DRA
• Skjermpipette som plukker farger fra hvor som helst på skjermen
• Dra fargeprøver rett inn i andre programmer – også i fargebrønner
• Bilder, med dominerende farger
• Kamera, også iPhone som kamera, med lysfelt på skjermen som lyskilde
• Kopier aktiv farge som OKLCH med ⌥⌘C, og lim inn en farge med ⌥⌘V

ALLE FARGEROMMENE
• Rediger i OKLCH, OKLab, CIE LCH, CIELab, HSB, HSL, RGB og CMYK
• Display P3 side om side med sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK eller en hvilken som helst ICC-profil
• Varsel når fargen er utenfor fargeområdet – farger kartlegges inn i fargerommet uten å klippes
• Angi CMYK eller RGB direkte i en valgt ICC-profil
• Rene CMYK-verdier: grått innslag flyttes til sort (UCR/GCR), med færrest mulig trykkfarger
• Feltet for fargeverdi forstår hex, CSS-farger og vanlige beskrivelser som «dyp havblå»

ICC-PROFILER
• Bruk profilene som allerede er installert på Macen, ordnet etter mappe
• Importer egne .icc- og .icm-profiler – de følger med til iPhone og iPad via iCloud Drive
• Konverter mellom profiler og sammenlign gjengivelseshensiktene med ΔE2000

OVERGANGER, TONER OG HARMONIER
• Overganger i like perseptuelle steg i OKLab, med lysere og mørkere rader
• CSS-gradient i oklab med sRGB-reserve – lineær, radiell eller konisk
• Toneskalaer fra 50 til 950
• Komplementær, split-komplementær, analog og jevn fordeling på fargesirkel i OKLCH, CIE LCH, HSL eller RYB, med metning og lyshet for hele harmonien

TILGJENGELIGHET OG FARGESYN
• WCAG 2.2-kontrast: AA og AAA, stor tekst og grafikk, og «Rett opp» som justerer fargen til den består
• Kontrastmatrise for hele paletten
• Se paletten med protan-, deutan- og tritanavvik og akromatopsi, med valgfri alvorlighetsgrad – og hvilke farger som blir vanskelige å skille
• Kamera med fargesynsfilter: se omgivelsene slik de kan oppleves med hvert avvik

APPLE INTELLIGENCE PÅ MACEN
• Fra verdiord til palett – «trygg, varm, nordisk» – forankret i en kunnskapsbase med over hundre fargebegreper
• Beskriv en farge og se den i Studio
• Juster med fritekst, navngi farger og få en vurdering av paletten
Alt kjøres lokalt. Uten Apple Intelligence lages palettene direkte fra kunnskapsbasen.

KOPIER TIL OG EKSPORT
• «Kopier til» designverktøy, layoutprogrammer, bilderedigering og presentasjonsprogrammer – i formatet hvert program tar imot, for enkeltfarger og hele paletter
• Eksport til ASE- og ACO-fargeprøver, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI og hex
• Fargene eksporteres i formatet de er lagret i – for eksempel som CMYK

PALETTER OG ICLOUD
Samle farger i paletter, lagre enkeltfarger og hele gradienter, og synkroniser med iPhone og iPad via din egen, private iCloud.

SIRI OG SNARVEIER
Lag palett fra verdiord, beskriv en farge, lag overgang, konverter farge og sjekk kontrast.

ÅPENT OM METODENE
Hver del av appen viser hvilke metoder den bygger på – OKLab, CSS Color 4, CIEDE2000, WCAG, simulering av fargesyn og ICC – med kilde og forklaring.

PERSONVERN
Ingen konto, ingen analyse, ingen reklame og ingen sporing. Utvikleren samler ikke inn data.

Krever macOS 26. Apple Intelligence krever en Mac med Apple-chip.
```

**Nøkkelord (100)**

```
farge,palett,fargevelger,pipette,OKLCH,CMYK,ICC,kontrast,WCAG,overgang,gradient,harmoni,fargeblind
```

---

## 3c. Mac-versjonen (macOS) – engelsk

**Promotional text (170)**

```
Build palettes in OKLCH, CMYK with ICC profiles, check for contrast and color vision challenges, pick colors anywhere on screen and drag them into other design software.
```

**Description (4000)**

```
Kolorist is a color tool for designers on Mac – and on iPhone and iPad with the same purchase. Build palettes across color spaces, with perceptually even gradients, contrast checks, color vision simulation and ICC profiles – and get your colors into the apps you already use.

PICK AND DRAG
• Screen eyedropper that picks colors from anywhere on screen
• Drag swatches straight into other apps – including color wells
• Photos, with dominant colors
• Camera, including iPhone as a camera, with a light panel on screen as a light source
• Copy the active color as OKLCH with ⌥⌘C, and paste a color with ⌥⌘V

EVERY COLOR SPACE
• Edit in OKLCH, OKLab, CIE LCH, CIELab, HSB, HSL, RGB and CMYK
• Display P3 side by side with sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK or any ICC profile
• Out-of-gamut warnings – colors are mapped into the color space instead of clipped
• Enter CMYK or RGB directly in a chosen ICC profile
• Clean CMYK values: grey components move to black (UCR/GCR), with as few inks as possible
• The color field understands hex, CSS colors and plain descriptions like “deep ocean blue”

ICC PROFILES
• Use the profiles already installed on your Mac, organized by folder
• Import your own .icc and .icm profiles – they follow you to iPhone and iPad through iCloud Drive
• Convert between profiles and compare rendering intents with ΔE2000

GRADIENTS, TONES AND HARMONIES
• Gradients in equal perceptual steps in OKLab, with lighter and darker rows
• CSS gradients in oklab with an sRGB fallback – linear, radial or conic
• Tone scales from 50 to 950
• Complementary, split complementary, analogous and even distributions on an OKLCH, CIE LCH, HSL or RYB color wheel, with saturation and lightness for the whole harmony

ACCESSIBILITY AND COLOR VISION
• WCAG 2.2 contrast: AA and AAA, large text and graphics, and auto-fix that adjusts the color until it passes
• Contrast matrix for the whole palette
• See the palette with protan, deutan and tritan deficiencies and achromatopsia, at any severity – and which colors become hard to tell apart
• Camera with a color vision filter: see your surroundings as they may appear with each deficiency

APPLE INTELLIGENCE ON YOUR MAC
• From value words to a palette – “calm, warm, Nordic” – grounded in a knowledge base of more than a hundred color concepts
• Describe a color and see it in Studio
• Adjust with free text, name colors and get a critique of your palette
Everything runs locally. Without Apple Intelligence, palettes are built straight from the knowledge base.

COPY TO AND EXPORT
• “Copy to” design tools, layout apps, photo editors and presentation apps – in the format each app accepts, for single colors and whole palettes
• Export to ASE and ACO swatches, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI and hex
• Colors are exported in the format they were saved in – for example as CMYK

PALETTES AND ICLOUD
Collect colors in palettes, save single colors and whole gradients, and sync with iPhone and iPad through your own private iCloud.

SIRI AND SHORTCUTS
Create a palette from value words, describe a color, create a gradient, convert a color and check contrast.

OPEN ABOUT METHODS
Every part of the app shows the methods it builds on – OKLab, CSS Color 4, CIEDE2000, WCAG, color vision simulation and ICC – with source and explanation.

PRIVACY
No account, no analytics, no ads and no tracking. The developer collects no data.

Requires macOS 26. Apple Intelligence requires a Mac with Apple silicon.
```

**Keywords (100)**

```
color,palette,picker,eyedropper,OKLCH,CMYK,ICC,contrast,WCAG,gradient,harmony,colorblind,hex,swatch
```

---

## 3d. Skjermbilder

Alle i `Dokumentasjon/Skjermbilder/`, fem per plattform og språk: Studio, Harmoni, Overgang, Kontrast, Fargesyn.

| Mappe | Plattform | Størrelse |
|---|---|---|
| `nb/`, `en/` | iPhone 6,5" | 1284 × 2778 |
| `ipad-nb/`, `ipad-en/` | iPad 13" | 2064 × 2752 |
| `mac-nb/`, `mac-en/` | Mac | 2880 × 1800 |

iPhone og iPad er tatt i simulatorene «Skjermbilder 6,5» (iPhone 14 Plus) og «Skjermbilder iPad 13» (iPad Pro 13"),
begge iOS 26.5. Mac-bildene er vinduet alene (1440 × 900 pt), tatt fra et Debug-bygg med
`-skjermbilde YES -startfane <fane>` (se `Kolorist/App/Skjermbildemodus.swift`).

## 4. App Review Information

| Felt | Verdi |
|---|---|
| Sign-in required | **Nei** – ikke kryss av; ingen demokonto trengs |
| Contact – first/last name | Eivind Arnstein Johansen |
| Contact – e-post | eivind.johansen@ntnu.no |
| Contact – telefon | *(fyll inn, med landskode +47)* |
| Vedlegg | Valgfritt: en kort skjermopptaksvideo av kamerafilteret og «Kopier til» |

**Notes (4000)** – på engelsk, som App Review leser raskest:

```
Thank you for reviewing Kolorist, a color palette tool for designers on iPhone, iPad and Mac (one universal purchase).

NO ACCOUNT NEEDED
All features work without signing in. There is no account, no server of our own, no analytics, no ads and no in-app purchases. Palettes sync through the user's private iCloud database (CloudKit) when the device is signed in to iCloud; without iCloud everything is stored on device.

WHERE TO FIND THE MAIN FEATURES
• Studio (first tab): edit the active color in OKLCH, Lab, RGB, CMYK etc. "Also show" picks a second color space or an ICC profile shown side by side. Below: harmonies, tones and ICC conversion.
• Palettes: tap + to create a palette, either empty or "New palette from value words (AI)". Touch and hold a color or palette for "Copy to" (Figma, Adobe apps, Pages/Keynote/Numbers, CSS, SwiftUI) and other actions.
• Gradient: perceptual gradients between two colors, with lighter/darker rows and CSS export.
• Pick: camera, photos and (on Mac) a screen eyedropper.
• Assess: WCAG contrast, color comparison (ΔE2000), palette critique and Color vision (simulation of color vision deficiencies). The camera button next to each deficiency opens the camera with that filter.

CAMERA
The camera is used live, on device only, to pick colors and to show the color vision filter. No photos or video are stored or sent. If no camera is available (for example on a Mac without one), picking from photos and the screen eyedropper still work.

APPLE INTELLIGENCE
Value-word palettes, "Describe a color", free-text adjustments, color naming and palette critique use the on-device Foundation Models framework. On devices without Apple Intelligence, or when it is turned off, palettes are generated from a built-in knowledge base instead, and the app explains what is unavailable. No text leaves the device.

ICC PROFILES
No ICC profiles are bundled. The app uses the system's built-in color spaces (sRGB, Display P3, Adobe RGB, Rec. 2020, ProPhoto RGB, Generic CMYK) and profiles the user imports ("Import profile …" in Studio). Imported profiles are stored in the app's iCloud Drive folder.

SIRI AND SHORTCUTS
App Shortcuts: "Describe a color in Kolorist", "Create a palette in Kolorist", plus actions to create a gradient, convert a color and check contrast.

MAC
The screen eyedropper uses the system color sampler (NSColorSampler) and does not require screen recording permission. Swatches can be dragged into other apps.

Methods and sources used by the app are listed in the app (bottom of Palettes › Methods and sources) and at https://kolorist.no/en/methods.html.

Contact: eivind.johansen@ntnu.no
```

---

## 5. Før du sender inn

- [ ] Nettsiden er publisert på kolorist.no (support- og personvernsidene må svare).
- [ ] `MARKETING_VERSION` settes til `1.0` (er `0.1` nå) og `CURRENT_PROJECT_VERSION` økes for hver opplasting.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`): appen bruker `UserDefaults` (`@AppStorage`), som krever
      begrunnelse `CA92.1`. Mangler i dag – uten den kommer det varsel/avvisning ved opplasting.
- [ ] `ITSAppUsesNonExemptEncryption = NO` i Info.plist.
- [ ] CloudKit-skjemaet er distribuert til produksjon (CloudKit Console › Deploy Schema Changes), ellers
      synkroniserer ikke TestFlight- og App Store-bygg.
- [x] Skjermbilder for iPhone, iPad og Mac på norsk og engelsk (se 3d).
      Samme bilder kan legges inn på nettsiden der det står «Skjermbilde kommer».
- [ ] Appikon 1024 × 1024 følger med i bygget (Icon Composer-ikonet).
- [ ] App Store-ID inn på nettsiden (Smart App Banner) og «Kommer snart» byttes med App Store-lenke etter godkjenning.
