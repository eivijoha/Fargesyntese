# Nettsider for Kolorist

Statiske nettsider for App Store-oppføringen: markedsføring, støtte, personvern og vilkår – på norsk bokmål
og engelsk. Ren HTML og ett felles stilark. Ingen byggesteg, ingen rammeverk, ingen eksterne skript eller
skrifter, ingen sporing og ingen informasjonskapsler (cookies). Alle lenker er relative, så sidene fungerer
både lokalt (åpne `index.html` i nettleseren) og på kolorist.no.

## Versjoner

Nettstedet ligger i én mappe per appversjon, så siden som er publisert alltid beskriver den versjonen
som ligger i App Store:

| Mappe | Innhold |
|---|---|
| `1.0/` | Versjon 1.0 – det som sendes til App Review først |
| `1.1/` | Versjon 1.1 – i tillegg fargebiblioteker (ASE/ACO/ACB) og «Mine fargerom», Munsell som fargemodell, LRV og kontrast mellom flater |

Publiser **innholdet** i mappen for versjonen som er godkjent i App Store (se «Publisering på kolorist.no»).
Ny versjon: kopier forrige mappe (`cp -R 1.1 1.2`) og oppdater tekstene der. Rett feil i alle mapper
der de finnes.

Stiene i tabellen under gjelder innenfor hver versjonsmappe.

## Filer

| Fil | Innhold |
|---|---|
| `index.html` | Forside/markedsføring (norsk) – funksjoner, plass til skjermbilder, plattformer, App Store-knapp |
| `support.html` | Støtte (norsk) – kontakt og ofte stilte spørsmål |
| `privacy.html` | Personvernerklæring (norsk), sist oppdatert 2026-10-02 |
| `terms.html` | Vilkår for bruk (norsk) – viser til Apples standard EULA |
| `methods.html` | Metoder og kilder (norsk) – samme innhold som «Metoder og kilder» i appen |
| `en/index.html`, `en/support.html`, `en/privacy.html`, `en/terms.html`, `en/methods.html` | Engelske versjoner av de samme sidene |
| `assets/stil.css` | Felles stilark: lys/mørk modus, OKLCH/OKLab-farger med sRGB-reserve |
| `assets/ikon.svg` | Forenklet appikon (favicon og logo), avledet av `App-ikon.icon` |

Hver side har språkvelger, riktig `<html lang>` og `hreflang`-lenker (`nb`, `en`, `x-default` → norsk).

## Hvilken URL går hvor i App Store Connect

Sidene publiseres manuelt på **https://kolorist.no/**.

| Felt i App Store Connect | Norsk (nb) | Engelsk (en) |
|---|---|---|
| Marketing URL | `https://kolorist.no/` | `https://kolorist.no/en/` |
| Support URL | `https://kolorist.no/support.html` | `https://kolorist.no/en/support.html` |
| Privacy Policy URL | `https://kolorist.no/privacy.html` | `https://kolorist.no/en/privacy.html` |

## Publisering på kolorist.no

Nettstedet publiseres manuelt. Last opp **innholdet** i versjonsmappen (for eksempel `web/1.0/`, ikke selve
mappen) til rotmappen for kolorist.no, slik at `index.html` ligger øverst og `en/` og `assets/` ved siden av.

- Last opp alle `.html`-filene, `en/`, `assets/`, `robots.txt` og `sitemap.xml`.
- Ikke last opp `README.md`, `.DS_Store` eller `CNAME` (`CNAME` var bare for GitHub Pages).
- Sjekk etterpå at support- og personvernsidene svarer på adressene i tabellen over – App Review åpner dem.
- Oppdater `lastmod` i `sitemap.xml` når innholdet endres.

`robots.txt` og `sitemap.xml` peker på kolorist.no. Hver side har `canonical` og absolutte `hreflang`-lenker.

### Generelt om adressene

| Felt i App Store Connect | Norsk (nb) | Engelsk (en) |
|---|---|---|
| **Marketing URL** (App Information / versjon) | `…/` (dvs. `index.html`) | `…/en/` |
| **Support URL** (påkrevd) | `…/support.html` | `…/en/support.html` |
| **Privacy Policy URL** (påkrevd, App Privacy) | `…/privacy.html` | `…/en/privacy.html` |
| **Lisensavtale (EULA)** | Standard EULA fra Apple – ingen URL trengs | |

Support URL og Marketing URL settes per lokalisering (Norsk / English) under versjonen. Privacy Policy URL
settes under *App Privacy* (også per lokalisering). Bruk de engelske adressene for engelsk lokalisering.

`terms.html` er ikke påkrevd av App Store Connect. Den kan lenkes fra appens beskrivelse eller fra
innstillingene i appen om ønskelig. Bruker du Apples standard EULA, trenger du ikke laste opp egen lisensavtale.

**App Privacy-etiketten:** Personvernerklæringen beskriver at utvikleren ikke samler inn data. Det svarer til
«Data Not Collected» i App Privacy-spørreskjemaet. Kontroller at det fortsatt stemmer før innsending
(f.eks. hvis det legges til krasjrapportering eller nettverkstjenester senere).

## Plassholdere som må fylles inn

Søk etter `TODO:` i HTML-filene, og etter den synlige teksten i hakeparenteser.

| Plassholder | Hvor | Hva |
|---|---|---|
| «Kommer snart i App Store» | `index.html`, `en/index.html` | Bytt `<span class="knapp knapp-kommer">` med `<a class="knapp" href="https://apps.apple.com/…">` og teksten «Last ned i App Store» når appen er godkjent. Vurder Apples offisielle «Download on the App Store»-merke (App Store Marketing Guidelines) |
| `<!-- TODO: app-id -->` | `index.html`, `en/index.html` (i `<head>`) | Fjern kommentarene rundt `<meta name="apple-itunes-app" content="app-id=…">` og sett inn App Store-ID-en for Smart App Banner |
| Skjermbilder | `assets/skjermbilde-*.png` (norsk side) og `assets/en/skjermbilde-*.png` (engelsk side) | Studio, Harmoni, Overgang, Kontrast og Fargesyn. De engelske er kopier av `Dokumentasjon/Skjermbilder/en/` (1284 × 2778); bytt filene med samme navn for å oppdatere |

Når alt er fylt inn, skal dette ikke gi treff:

```bash
grep -rn 'TODO\|\[kontakt-e-post\]\|\[contact email\]\|\[app-store' web
```

## Endringer

- Stilen ligger i `assets/stil.css`. Fargene er definert som variabler i `:root`; mørk modus i
  `@media (prefers-color-scheme: dark)`. `oklch()`/`oklab()` brukes der nettleseren støtter det, med hex først
  som reserve.
- Topptekst, meny og bunntekst er kopiert i hver side (ingen byggesteg). Endrer du menyen, endre alle ti
  sidene (fem på norsk, fem på engelsk).
- Oppdater «Sist oppdatert» i `privacy.html` og `en/privacy.html` (og `terms.html`) når innholdet endres.
