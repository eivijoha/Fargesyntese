# App Store Connect og App Review – Kolorist 1.1

Tekster klare til å lime inn for versjon 1.1. Én app-post med universelt kjøp for iPhone, iPad og Mac (samme bundle-ID
`no.engenett.Kolorist`, plattformene iOS og macOS i samme post). Primærspråk: norsk (bokmål), i tillegg engelsk.
Tegngrensene står i parentes, og alle tekstene er innenfor. Tekstene og skjermbildene for 1.0 ligger uendret i
`Dokumentasjon/1.0/`.

Nytt i 1.1 i forhold til 1.0-tekstene: «Nytt i denne versjonen» for iOS og macOS, Munsell, LRV, fargebiblioteker,
palettkolonne, dra og slipp, plukkede farger, angre og tilpasning av paneler – og «colour» også i de engelske
overskriftene.

---

## 1. App-informasjon (gjelder alle versjoner)

| Felt | Verdi |
|---|---|
| Navn (30) | **Kolorist** – er navnet opptatt: «Kolorist – fargepaletter» / «Kolorist: Colour Palettes» |
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

## 2. Versjonstekster – iPhone og iPad, norsk (bokmål)

**Undertittel (30)** – uendret

```
Fargepaletter for designere
```

**Reklametekst (170)** – kan endres uten ny versjon

```
Bygg paletter i OKLCH, CMYK med ICC-profiler og Munsell, kontroller kontrast og fargesyn-problematikk, og kopier fargene rett inn i annen design-programvare.
```

**Nytt i denne versjonen (4000)**

```
Kolorist 1.1 er laget for flere fagfelt – også arkitektur og interiør – og gjør det raskere å jobbe med paletter.

• Fargebiblioteker: importer egne fargekart i ASE, ACO eller ACB med navngitte toner. Studio viser nærmeste tone, og farger, toner og harmonier kan låses til bibliotekets toner.
• Munsell: ny fargemodell med kulør i steg på 2,5, valør og kroma.
• LRV: lysrefleksjonsverdi og flatekontrast etter BS 8300 og NS 11001 under Vurdering › Kontrast.
• Rec. 2020 og ProPhoto RGB som innebygde fargerom.
• «Mine fargerom» samler ICC-profiler og fargebiblioteker – og alt kan slettes fra appen.
• Palettkolonne på store iPader i liggende format: dra farger rett inn i fargevalg som Fra og Til i Overgang.
• Plukkede farger fra kamera og bilder samles øverst i Paletter til du lagrer dem.
• Trykk på en farge i palettoversikten for å velge den. Trykk og hold på en palett for vurdering og kontrastmatrise.
• Angre overalt, også med ⌘Z på tastatur.
• Paneler kan legges sammen og flyttes, og verdier kan skjules og sorteres – oppsettet synkroniseres.
• Bedre paletter fra verdiord: bygget etter harmoniprinsipper med lesbar kontrast.
• Vurderingen av en palett viser hva den bygger på.
• Skriv ut en palett på A4 – fargeflater i CIELab med navn og verdier – eller lagre den som PDF.
• «Sammenlign» heter nå «Forskjell».
```

**Beskrivelse (4000)**

```
Kolorist er et fargeverktøy for designere og arkitekter på iPhone, iPad og Mac. Bygg paletter på tvers av fargerom, med perseptuelt jevne overganger, kontrastsjekk, simulering av fargesyn, ICC-profiler og egne fargebiblioteker – og få fargene inn i verktøyene du allerede bruker.

ALLE FARGEROMMENE
• Rediger i OKLCH, OKLab, CIE LCH, CIELab, Munsell, HSB, HSL, RGB og CMYK
• Display P3 side om side med sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK eller en hvilken som helst ICC-profil
• Varsel når fargen er utenfor fargeområdet – farger kartlegges inn i fargerommet uten å klippes
• Angi CMYK eller RGB direkte i en valgt ICC-profil
• Rene CMYK-verdier: grått innslag flyttes til sort (UCR/GCR)
• Feltet for fargeverdi forstår hex, CSS-farger, Munsell-notasjon og vanlige beskrivelser som «dyp havblå»

FARGEBIBLIOTEKER OG ICC-PROFILER
• Importer egne fargekart i ASE, ACO eller ACB (Adobe Color Book) med navngitte toner
• Studio viser nærmeste tone og avstanden i ΔE2000 – og kan låse farger, toner og harmonier til bibliotekets toner
• Importer egne .icc- og .icm-profiler
• Alt samles under «Mine fargerom» og følger med til de andre enhetene dine via iCloud Drive
• Konverter mellom profiler og sammenlign gjengivelseshensiktene med ΔE2000

OVERGANGER, TONER OG HARMONIER
• Overganger i like perseptuelle steg i OKLab, med lysere og mørkere rader
• CSS-gradient i oklab med sRGB-reserve – lineær, radiell eller konisk
• Toneskalaer fra 50 til 950
• Komplementær, split-komplementær, analog og jevn fordeling på fargesirkel i OKLCH, CIE LCH, HSL eller RYB

TILGJENGELIGHET OG FARGESYN
• WCAG 2.2-kontrast: AA og AAA, stor tekst og grafikk, og «Rett opp» som justerer fargen til den består
• Flatekontrast med LRV (lysrefleksjonsverdi) etter BS 8300 og NS 11001 – for dører, vegger, gulv og skilt
• Kontrastmatrise og vurdering av hele paletten
• Se paletten med protan-, deutan- og tritanavvik og akromatopsi – og hvilke farger som blir vanskelige å skille
• Kamera med fargesynsfilter: se omgivelsene slik de kan oppleves med hvert avvik

PLUKK FARGER
• Kamera med zoom, makrofokus og lykt
• Bilder, med dominerende farger
• Plukkede farger samles øverst i Paletter til du lagrer dem
• Skjermpipette på Mac

APPLE INTELLIGENCE PÅ ENHETEN
• Fra verdiord til palett – «trygg, varm, nordisk» – forankret i en kunnskapsbase med over hundre fargebegreper
• Palettene bygges etter harmoniprinsipper – lik valør eller metning, aksentfarge, lys eller mørk bakgrunn – med lesbar kontrast
• Beskriv en farge og se den i Studio
• Juster med fritekst, navngi farger og få en vurdering av paletten
Alt kjøres på enheten. Uten Apple Intelligence lages palettene direkte fra kunnskapsbasen.

KOPIER TIL OG EKSPORT
• «Kopier til» designverktøy, layout-, bilde- og presentasjonsprogrammer – i formatet hvert program tar imot
• Dra fargeprøver rett inn i andre programmer på Mac
• Eksport til ASE- og ACO-fargeprøver, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI og hex
• Fargene eksporteres i formatet de er lagret i – for eksempel som CMYK
• Skriv ut paletten på A4: fargeflater i CIELab med navn og verdier

PALETTER OG ICLOUD
Samle farger i paletter, lagre enkeltfarger og hele gradienter, og synkroniser via din egen, private iCloud. På store iPader i liggende format ligger palettene i en kolonne ved siden av verktøyene, og farger kan dras rett inn i fargevalgene. Angre overalt, også med ⌘Z.

SIRI OG SNARVEIER
Lag palett fra verdiord, beskriv en farge, lag overgang, konverter farge og sjekk kontrast.

ÅPENT OM METODENE
Hver del av appen viser hvilke metoder den bygger på – OKLab, CSS Color 4, CIEDE2000, WCAG, LRV, Munsell, simulering av fargesyn og ICC – med kilde og forklaring.

PERSONVERN
Ingen konto, ingen analyse, ingen reklame og ingen sporing. Utvikleren samler ikke inn data.

Krever iOS 26, iPadOS 26 eller macOS 26. Apple Intelligence krever en støttet enhet.
```

**Nøkkelord (100, kommaseparert uten mellomrom)**

```
farge,palett,fargekart,OKLCH,CMYK,ICC,Munsell,LRV,kontrast,WCAG,overgang,pipette,harmoni,fargeblind
```

---

## 3. Versjonstekster – iPhone og iPad, engelsk

**Subtitle (30)** – unchanged

```
Colour palettes for designers
```

**Promotional text (170)**

```
Build palettes in OKLCH, CMYK with ICC profiles and Munsell, check for contrast and colour vision challenges, and copy colours straight into other design software.
```

**What’s New in This Version (4000)**

```
Kolorist 1.1 reaches more disciplines – including architecture and interiors – and makes working with palettes faster.

• Colour libraries: import your own colour charts in ASE, ACO or ACB with named tones. Studio shows the nearest tone, and colours, tones and harmonies can be locked to the library’s tones.
• Munsell: a new colour model with hue in steps of 2.5, value and chroma.
• LRV: light reflectance value and surface contrast to BS 8300 and NS 11001 under Assess › Contrast.
• Rec. 2020 and ProPhoto RGB as built-in colour spaces.
• “My colour spaces” gathers ICC profiles and colour libraries – and everything can be deleted in the app.
• Palette column on large iPads in landscape: drag colours straight onto colour wells such as From and To in Gradient.
• Colours picked from the camera and photos gather at the top of Palettes until you save them.
• Tap a colour in the palette overview to select it. Touch and hold a palette for a critique and contrast matrix.
• Undo everywhere, including ⌘Z on a keyboard.
• Panels can be collapsed and reordered, and values hidden and sorted – the layout syncs.
• Better palettes from value words: built on harmony principles with legible contrast.
• A palette critique now shows what it is based on.
• Print a palette on A4 – CIELab swatches with names and values – or save it as a PDF.
• “Compare” is now called “Difference”.
```

**Description (4000)**

```
Kolorist is a colour tool for designers and architects on iPhone, iPad and Mac. Build palettes across colour spaces, with perceptually even gradients, contrast checks, colour vision simulation, ICC profiles and your own colour libraries – and get your colours into the tools you already use.

EVERY COLOUR SPACE
• Edit in OKLCH, OKLab, CIE LCH, CIELab, Munsell, HSB, HSL, RGB and CMYK
• Display P3 side by side with sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK or any ICC profile
• Out-of-gamut warnings – colours are gamut-mapped, never clipped
• Enter CMYK or RGB directly in a chosen ICC profile
• Clean CMYK values: grey components move to black (UCR/GCR)
• The colour field understands hex, CSS colours, Munsell notation and plain descriptions like “deep ocean blue”

COLOUR LIBRARIES AND ICC PROFILES
• Import your own colour charts in ASE, ACO or ACB (Adobe Color Book) with named tones
• Studio shows the nearest tone and its ΔE2000 distance – and can lock colours, tones and harmonies to the library’s tones
• Import your own .icc and .icm profiles
• Everything is gathered under “My colour spaces” and follows you to your other devices through iCloud Drive
• Convert between profiles and compare rendering intents with ΔE2000

GRADIENTS, TONES AND HARMONIES
• Gradients in equal perceptual steps in OKLab, with lighter and darker rows
• CSS gradients in oklab with an sRGB fallback – linear, radial or conic
• Tone scales from 50 to 950
• Complementary, split complementary, analogous and even distributions on an OKLCH, CIE LCH, HSL or RYB colour wheel

ACCESSIBILITY AND COLOUR VISION
• WCAG 2.2 contrast: AA and AAA, large text and graphics, and auto-fix that adjusts the colour until it passes
• Surface contrast with LRV (light reflectance value) to BS 8300 and NS 11001 – for doors, walls, floors and signage
• Contrast matrix and critique of the whole palette
• See the palette with protan, deutan and tritan deficiencies and achromatopsia – and which colours become hard to tell apart
• Camera with a colour vision filter: see your surroundings as they may appear with each deficiency

PICK COLOURS
• Camera with zoom, macro focus and torch
• Photos, with dominant colours
• Picked colours gather at the top of Palettes until you save them
• Screen eyedropper on Mac

APPLE INTELLIGENCE ON DEVICE
• From value words to a palette – “calm, warm, Nordic” – grounded in a knowledge base of more than a hundred colour concepts
• Palettes are built on harmony principles – equal value or saturation, an accent colour, a light or dark background – with legible contrast
• Describe a colour and see it in Studio
• Adjust with free text, name colours and get a critique of your palette
Everything runs on device. Without Apple Intelligence, palettes are built straight from the knowledge base.

COPY TO AND EXPORT
• “Copy to” design tools, layout, photo and presentation apps – in the format each app accepts
• Drag swatches straight into other apps on Mac
• Export to ASE and ACO swatches, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI and hex
• Colours are exported in the format they were saved in – for example as CMYK
• Print the palette on A4: CIELab swatches with names and values

PALETTES AND ICLOUD
Collect colours in palettes, save single colours and whole gradients, and sync through your own private iCloud. On large iPads in landscape your palettes sit in a column beside the tools, and colours can be dragged straight onto colour wells. Undo everywhere, including ⌘Z.

SIRI AND SHORTCUTS
Create a palette from value words, describe a colour, create a gradient, convert a colour and check contrast.

OPEN ABOUT METHODS
Every part of the app shows the methods it builds on – OKLab, CSS Color 4, CIEDE2000, WCAG, LRV, Munsell, colour vision simulation and ICC – with source and explanation.

PRIVACY
No account, no analytics, no ads and no tracking. The developer collects no data.

Requires iOS 26, iPadOS 26 or macOS 26. Apple Intelligence requires a supported device.
```

**Keywords (100)**

```
colour,color,palette,picker,OKLCH,CMYK,ICC,Munsell,LRV,contrast,WCAG,gradient,eyedropper,colorblind
```

---

## 3b. Mac-versjonen (macOS) – norsk (bokmål)

macOS har egen versjonsside i App Store Connect, med egen reklametekst, beskrivelse, nøkkelord, «Nytt i denne versjonen»
og skjermbilder. Navn og undertittel er felles (App-informasjon), og iPad deler tekst med iPhone. Support- og
markedsførings-URL er de samme som for iOS.

**Reklametekst (170)**

```
Bygg paletter i OKLCH, CMYK med ICC-profiler og Munsell, kontroller kontrast og fargesyn, plukk farger fra hele skjermen og dra dem rett inn i annen design-programvare.
```

**Nytt i denne versjonen (4000)**

```
Kolorist 1.1 er laget for flere fagfelt – også arkitektur og interiør – og utnytter Mac-vinduet bedre.

• Paletter fast til høyre: når vinduet er bredt nok, ligger palettene ved siden av alle verktøyene. Gjøres vinduet smalt, flytter de tilbake i sidefeltet.
• Dra og slipp: dra farger fra palettene rett inn i fargevalg som Fra og Til i Overgang, i tonerekka og på andre paletter – og dra farger inn fra fargepanelet og fargebrønner i andre programmer.
• Fargebiblioteker: importer egne fargekart i ASE, ACO eller ACB med navngitte toner. Studio viser nærmeste tone, og farger, toner og harmonier kan låses til bibliotekets toner.
• Munsell: ny fargemodell med kulør i steg på 2,5, valør og kroma.
• LRV: lysrefleksjonsverdi og flatekontrast etter BS 8300 og NS 11001 under Vurdering › Kontrast.
• Rec. 2020 og ProPhoto RGB som innebygde fargerom.
• «Mine fargerom» samler ICC-profiler og fargebiblioteker – og alt kan slettes fra appen.
• Plukkede farger fra kamera, bilder og skjermpipetten samles øverst i Paletter til du lagrer dem.
• Kamera: målepunktet følger pekeren, og et klikk fanger fargen der.
• Angre (⌘Z) overalt.
• Skriv ut en palett (⌘P) på A4 – fargeflater i CIELab med navn og verdier – eller arkiver den som PDF.
• Klikk på en farge i palettoversikten for å velge den. Høyreklikk på en palett for vurdering og kontrastmatrise.
• Paneler kan legges sammen og flyttes, og verdier kan skjules og sorteres – oppsettet synkroniseres.
• Bedre paletter fra verdiord: bygget etter harmoniprinsipper med lesbar kontrast.
• «Sammenlign» heter nå «Forskjell».
```

**Beskrivelse (4000)**

```
Kolorist er et fargeverktøy for designere og arkitekter på Mac – og på iPhone og iPad med samme kjøp. Bygg paletter på tvers av fargerom, med perseptuelt jevne overganger, kontrastsjekk, simulering av fargesyn, ICC-profiler og egne fargebiblioteker – og få fargene inn i programmene du allerede bruker.

PLUKK OG DRA
• Skjermpipette som plukker farger fra hvor som helst på skjermen
• Dra fargeprøver inn i andre programmer og fargebrønner – og dra farger inn fra dem
• Palettene ligger fast til høyre i et bredt vindu
• Bilder, med dominerende farger
• Kamera, også iPhone som kamera, med lysfelt på skjermen som lyskilde
• Kopier aktiv farge som OKLCH med ⌥⌘C, lim inn en farge med ⌥⌘V, og angre med ⌘Z

ALLE FARGEROMMENE
• Rediger i OKLCH, OKLab, CIE LCH, CIELab, Munsell, HSB, HSL, RGB og CMYK
• Display P3 side om side med sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK eller en hvilken som helst ICC-profil
• Varsel når fargen er utenfor fargeområdet – farger kartlegges inn i fargerommet uten å klippes
• Angi CMYK eller RGB direkte i en valgt ICC-profil
• Rene CMYK-verdier: grått innslag flyttes til sort (UCR/GCR)
• Feltet for fargeverdi forstår hex, CSS-farger, Munsell-notasjon og vanlige beskrivelser som «dyp havblå»

FARGEBIBLIOTEKER OG ICC-PROFILER
• Importer egne fargekart i ASE, ACO eller ACB (Adobe Color Book) med navngitte toner
• Studio viser nærmeste tone og avstanden i ΔE2000 – og kan låse farger, toner og harmonier til bibliotekets toner
• Bruk profilene som er installert på Macen, etter mappe
• Importer egne .icc- og .icm-profiler
• Alt samles under «Mine fargerom» og følger med til iPhone og iPad via iCloud Drive
• Konverter mellom profiler og sammenlign gjengivelseshensiktene med ΔE2000

OVERGANGER, TONER OG HARMONIER
• Overganger i like perseptuelle steg i OKLab, med lysere og mørkere rader
• CSS-gradient i oklab med sRGB-reserve – lineær, radiell eller konisk
• Toneskalaer fra 50 til 950
• Komplementær, split-komplementær, analog og jevn fordeling på fargesirkel i OKLCH, CIE LCH, HSL eller RYB

TILGJENGELIGHET OG FARGESYN
• WCAG 2.2-kontrast: AA og AAA, stor tekst og grafikk, og «Rett opp» som justerer fargen til den består
• Flatekontrast med LRV (lysrefleksjonsverdi) etter BS 8300 og NS 11001 – for dører, vegger, gulv og skilt
• Kontrastmatrise og vurdering av hele paletten
• Se paletten med protan-, deutan- og tritanavvik og akromatopsi – og hvilke farger som blir vanskelige å skille
• Kamera med fargesynsfilter: se omgivelsene slik de kan oppleves med hvert avvik

APPLE INTELLIGENCE PÅ MACEN
• Fra verdiord til palett – «trygg, varm, nordisk» – forankret i en kunnskapsbase med over hundre fargebegreper
• Palettene bygges etter harmoniprinsipper – lik valør eller metning, aksentfarge, lys eller mørk bakgrunn – med lesbar kontrast
• Beskriv en farge og se den i Studio
• Juster med fritekst, navngi farger og få en vurdering av paletten
Alt kjøres lokalt. Uten Apple Intelligence lages palettene direkte fra kunnskapsbasen.

KOPIER TIL OG EKSPORT
• «Kopier til» designverktøy, layout-, bilde- og presentasjonsprogrammer – i formatet hvert program tar imot
• Eksport til ASE- og ACO-fargeprøver, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI og hex
• Fargene eksporteres i formatet de er lagret i – for eksempel som CMYK
• Skriv ut paletten på A4: fargeflater i CIELab med navn og verdier

PALETTER OG ICLOUD
Samle farger i paletter, lagre enkeltfarger og hele gradienter, og synkroniser med iPhone og iPad via din egen, private iCloud.

SIRI OG SNARVEIER
Lag palett fra verdiord, beskriv en farge, lag overgang, konverter farge og sjekk kontrast.

ÅPENT OM METODENE
Hver del av appen viser hvilke metoder den bygger på – OKLab, CSS Color 4, CIEDE2000, WCAG, LRV, Munsell, simulering av fargesyn og ICC – med kilde og forklaring.

PERSONVERN
Ingen konto, ingen analyse, ingen reklame og ingen sporing. Utvikleren samler ikke inn data.

Krever macOS 26. Apple Intelligence krever en Mac med Apple-chip.
```

**Nøkkelord (100)**

```
farge,palett,fargekart,pipette,OKLCH,CMYK,ICC,Munsell,LRV,kontrast,WCAG,overgang,harmoni,fargeblind
```

---

## 3c. Mac-versjonen (macOS) – engelsk

**Promotional text (170)**

```
Build palettes in OKLCH, CMYK with ICC profiles and Munsell, check contrast and colour vision, pick colours anywhere on screen and drag them into other design apps.
```

**What’s New in This Version (4000)**

```
Kolorist 1.1 reaches more disciplines – including architecture and interiors – and makes better use of the Mac window.

• Palettes on the right: when the window is wide enough, your palettes sit beside every tool. Make the window narrow and they move back into the sidebar.
• Drag and drop: drag colours from your palettes straight onto colour wells such as From and To in Gradient, onto the tone row and onto other palettes – and drag colours in from the colour panel and colour wells in other apps.
• Colour libraries: import your own colour charts in ASE, ACO or ACB with named tones. Studio shows the nearest tone, and colours, tones and harmonies can be locked to the library’s tones.
• Munsell: a new colour model with hue in steps of 2.5, value and chroma.
• LRV: light reflectance value and surface contrast to BS 8300 and NS 11001 under Assess › Contrast.
• Rec. 2020 and ProPhoto RGB as built-in colour spaces.
• “My colour spaces” gathers ICC profiles and colour libraries – and everything can be deleted in the app.
• Colours picked from the camera, photos and the screen eyedropper gather at the top of Palettes until you save them.
• Camera: the sampling point follows the pointer, and a click captures the colour there.
• Undo (⌘Z) everywhere.
• Print a palette (⌘P) on A4 – CIELab swatches with names and values – or save it as a PDF.
• Click a colour in the palette overview to select it. Right-click a palette for a critique and contrast matrix.
• Panels can be collapsed and reordered, and values hidden and sorted – the layout syncs.
• Better palettes from value words: built on harmony principles with legible contrast.
• “Compare” is now called “Difference”.
```

**Description (4000)**

```
Kolorist is a colour tool for designers and architects on Mac – and on iPhone and iPad with the same purchase. Build palettes across colour spaces, with perceptually even gradients, contrast checks, colour vision simulation, ICC profiles and your own colour libraries – and get your colours into the apps you already use.

PICK AND DRAG
• Screen eyedropper that picks colours from anywhere on screen
• Drag swatches into other apps and colour wells – and drag colours in from them
• Your palettes stay on the right in a wide window
• Photos, with dominant colours
• Camera, including iPhone as a camera, with an on-screen light panel
• Copy as OKLCH with ⌥⌘C, paste with ⌥⌘V, undo with ⌘Z

EVERY COLOUR SPACE
• Edit in OKLCH, OKLab, CIE LCH, CIELab, Munsell, HSB, HSL, RGB and CMYK
• Display P3 side by side with sRGB, Adobe RGB, Rec. 2020, ProPhoto RGB, CMYK or any ICC profile
• Out-of-gamut warnings – colours are gamut-mapped, never clipped
• Enter CMYK or RGB directly in a chosen ICC profile
• Clean CMYK values: grey components move to black (UCR/GCR)
• The colour field understands hex, CSS colours, Munsell notation and plain descriptions like “deep ocean blue”

COLOUR LIBRARIES AND ICC PROFILES
• Import your own colour charts in ASE, ACO or ACB (Adobe Color Book) with named tones
• Studio shows the nearest tone and its ΔE2000 distance, and can lock colours to the library
• Use the profiles installed on your Mac, by folder
• Import your own .icc and .icm profiles
• All gathered under “My colour spaces”, synced to iPhone and iPad through iCloud Drive
• Convert between profiles and compare rendering intents with ΔE2000

GRADIENTS, TONES AND HARMONIES
• Gradients in equal perceptual steps in OKLab, with lighter and darker rows
• CSS gradients in oklab with an sRGB fallback – linear, radial or conic
• Tone scales from 50 to 950
• Complementary, split complementary, analogous and even distributions on an OKLCH, CIE LCH, HSL or RYB colour wheel

ACCESSIBILITY AND COLOUR VISION
• WCAG 2.2 contrast: AA and AAA, large text and graphics, and auto-fix that adjusts the colour until it passes
• Surface contrast with LRV (light reflectance value) to BS 8300 and NS 11001 – for doors, walls, floors and signage
• Contrast matrix and critique of the whole palette
• See the palette with protan, deutan and tritan deficiencies and achromatopsia – and which colours become hard to tell apart
• Camera with a colour vision filter: see your surroundings as they may appear with each deficiency

APPLE INTELLIGENCE ON YOUR MAC
• From value words to a palette – “calm, warm, Nordic” – grounded in a knowledge base of more than a hundred colour concepts
• Palettes are built on harmony principles – equal value or saturation, an accent colour, a light or dark background – with legible contrast
• Describe a colour and see it in Studio
• Adjust with free text, name colours and get a critique of your palette
Everything runs locally. Without Apple Intelligence, palettes are built straight from the knowledge base.

COPY TO AND EXPORT
• “Copy to” design tools, layout, photo and presentation apps – in the format each app accepts
• Export to ASE, ACO, Design Tokens (DTCG), SVG, CSS, GPL, SwiftUI and hex
• Colours are exported in the format they were saved in – for example as CMYK
• Print the palette on A4: CIELab swatches with names and values

PALETTES AND ICLOUD
Collect colours in palettes, save single colours and whole gradients, and sync with iPhone and iPad through your own private iCloud.

SIRI AND SHORTCUTS
Create a palette from value words, describe a colour, create a gradient, convert a colour and check contrast.

OPEN ABOUT METHODS
Every part of the app shows the methods it builds on – OKLab, CSS Color 4, CIEDE2000, WCAG, LRV, Munsell, colour vision simulation and ICC – with source and explanation.

PRIVACY
No account, no analytics, no ads and no tracking. The developer collects no data.

Requires macOS 26. Apple Intelligence requires a Mac with Apple silicon.
```

**Keywords (100)**

```
colour,color,palette,picker,eyedropper,OKLCH,CMYK,ICC,Munsell,LRV,contrast,WCAG,gradient,colorblind
```

---

## 3d. Skjermbilder

Alle i `Dokumentasjon/1.1/Skjermbilder/`, fem per plattform og språk: Studio (Farge), Harmoni, Overgang,
Kontrast (WCAG og LRV), Fargesyn. Bildene for 1.0 ligger i `Dokumentasjon/1.0/Skjermbilder/`.

| Mappe | Plattform | Størrelse |
|---|---|---|
| `nb/`, `en/` | iPhone 6,5" | 1284 × 2778 |
| `ipad-nb/`, `ipad-en/` | iPad 13" | 2064 × 2752 |
| `mac-nb/`, `mac-en/` | Mac | 2880 × 1800 |

iPhone og iPad er tatt i simulatorene «Skjermbilder 6,5» (iPhone 14 Plus) og «Skjermbilder iPad 13» (iPad Pro 13"),
begge iOS 26.5. Mac-bildene er vinduet alene (1440 × 900 pt på Retina-skjermen) og viser palettkolonnen med
plukkede farger. Alle er tatt fra et Debug-bygg med `-skjermbilde YES` (se `Kolorist/App/Skjermbildemodus.swift`):
eget lager i minnet med eksempelpaletter på appens språk og standardoppsett for paneler, så egne paletter og
innstillinger ikke kommer med. Overgang er tatt med `-overgangFra "#1B3A6B" -overgangTil "#F2B84B" -overgangAntall 7`,
Mac-bildene i tillegg med `-testmaalinger YES`.

## 4. App Review Information

| Felt | Verdi |
|---|---|
| Sign-in required | **Nei** – ikke kryss av; ingen demokonto trengs |
| Contact – first/last name | Eivind Arnstein Johansen |
| Contact – e-post | eivind.johansen@ntnu.no |
| Contact – telefon | *(fyll inn, med landskode +47)* |
| Vedlegg | Valgfritt: en kort skjermopptaksvideo av fargebibliotek-import og dra og slipp på Mac |

**Notes (4000)** – på engelsk, som App Review leser raskest:

```
Thank you for reviewing Kolorist 1.1, a colour palette tool for designers and architects on iPhone, iPad and Mac (one universal purchase).

NO ACCOUNT NEEDED
All features work without signing in. There is no account, no server of our own, no analytics, no ads and no in-app purchases. Palettes sync through the user's private iCloud database (CloudKit) when the device is signed in to iCloud; without iCloud everything is stored on device.

WHERE TO FIND THE MAIN FEATURES
• Studio (first tab): edit the active colour in OKLCH, Lab, Munsell, RGB, CMYK etc. "Also show" picks a second colour space, an ICC profile or a colour library shown side by side. Colour | Tones | Harmony switches between editing, tone scales and harmonies.
• Palettes: tap + to create a palette, either empty or "New palette from value words (AI)". Tap a colour to select it; tap a palette's title to open it. Touch and hold (right-click on Mac) a palette for "Critique the palette" and "Contrast matrix", or a colour for "Copy to" (Figma, Adobe apps, Pages/Keynote/Numbers, CSS, SwiftUI) and other actions.
• Gradient: perceptual gradients between two colours, with lighter/darker rows and CSS export.
• Pick: camera, photos and (on Mac) a screen eyedropper. Picked colours appear at the top of Palettes, marked "Not saved".
• Assess: Contrast (WCAG text contrast and LRV surface contrast), Difference (ΔE2000) and Colour vision (simulation of colour vision deficiencies). The camera button next to each deficiency opens the camera with that filter.

NEW IN 1.1 – HOW TO TEST
• Colour libraries: export any palette as ASE (open a palette › Export › ASE), then import that file under Studio › Also show › My colour spaces … › Import. Choose the library under "Also show" to see the nearest named tone.
• Munsell: Studio › Colour model › Munsell.
• LRV: Assess › Contrast › Surfaces (LRV).
• Palette column: on a 13-inch iPad in landscape, or on a Mac with a window at least 1300 points wide. Drag a colour from the column onto From or To in Gradient.
• Undo: ⌘Z (Edit › Undo) after changing a colour or editing a palette.
• Print: open a palette › Print … (or ⌘P on Mac), or Export › PDF with swatches (A4).

CAMERA
The camera is used live, on device only, to pick colours and to show the colour vision filter. No photos or video are stored or sent. If no camera is available (for example on a Mac without one), picking from photos and the screen eyedropper still work.

APPLE INTELLIGENCE
Value-word palettes, "Describe a colour", free-text adjustments, colour naming and palette critique use the on-device Foundation Models framework. On devices without Apple Intelligence, or when it is turned off, palettes are generated from a built-in knowledge base instead, and the app explains what is unavailable. No text leaves the device.

ICC PROFILES AND COLOUR LIBRARIES
No ICC profiles or colour libraries are bundled. The app uses the system's built-in colour spaces (sRGB, Display P3, Adobe RGB, Rec. 2020, ProPhoto RGB, Generic CMYK) and profiles and libraries the user imports under "My colour spaces". Imported files are stored in the app's iCloud Drive folder and can be deleted in the app. The Munsell conversion uses the published Munsell renotation data.

SIRI AND SHORTCUTS
App Shortcuts: "Describe a colour in Kolorist", "Create a palette in Kolorist", plus actions to create a gradient, convert a colour and check contrast.

MAC
The screen eyedropper uses the system colour sampler (NSColorSampler) and does not require screen recording permission. Swatches can be dragged into other apps, and colours can be dropped in from the system colour panel and other apps.

Methods and sources used by the app are listed in the app (bottom of Palettes › Methods and sources) and at https://kolorist.no/en/methods.html.

Contact: eivind.johansen@ntnu.no
```

---

## 5. Før du sender inn

- [ ] Nettsiden for 1.1 (`web/1.1/`) er publisert på kolorist.no.
- [x] `MARKETING_VERSION` er `1.1`. `CURRENT_PROJECT_VERSION` (nå `3`) økes for hver opplasting.
- [ ] Ny versjon opprettet i App Store Connect for både iOS og macOS (1.1), med «Nytt i denne versjonen» fra over.
- [ ] Nøkkelord og beskrivelse oppdatert (nye: Munsell, LRV, fargebiblioteker).
- [x] Skjermbilder for iPhone, iPad og Mac på norsk og engelsk (se 3d).
- [ ] CloudKit-skjemaet: ingen nye modellfelt i 1.1, så produksjonsskjemaet trenger ikke ny utrulling.
- [ ] Notes for App Review byttet til teksten over.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) med begrunnelse `CA92.1` for `UserDefaults` – finnes fortsatt ikke i prosjektet.
- [ ] `ITSAppUsesNonExemptEncryption = NO` – står fortsatt ikke i Info.plist eller byggeinnstillingene.
- [x] Lagringsformatet er bakoverkompatibelt: paletter med Munsell-farger og farger fra fargebiblioteker kan
      leses av 1.0 på enheter som ikke er oppdatert ennå (se `PalettFarge` i `Palett.swift` og `LagringsformatTests`).
