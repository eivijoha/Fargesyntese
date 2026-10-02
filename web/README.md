# Nettsider for Kolorist

Statiske nettsider for App Store-oppføringen: markedsføring, støtte, personvern og vilkår – på norsk bokmål
og engelsk. Ren HTML og ett felles stilark. Ingen byggesteg, ingen rammeverk, ingen eksterne skript eller
skrifter, ingen sporing og ingen informasjonskapsler (cookies). Alle lenker er relative, så sidene fungerer
både lokalt (åpne `index.html` i nettleseren) og på GitHub Pages.

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

Sidene publiseres på **https://kolorist.no/** (GitHub Pages med eget domene; `CNAME` i denne mappen).

| Felt i App Store Connect | Norsk (nb) | Engelsk (en) |
|---|---|---|
| Marketing URL | `https://kolorist.no/` | `https://kolorist.no/en/` |
| Support URL | `https://kolorist.no/support.html` | `https://kolorist.no/en/support.html` |
| Privacy Policy URL | `https://kolorist.no/privacy.html` | `https://kolorist.no/en/privacy.html` |

## Publisering på kolorist.no

1. **DNS hos domeneleverandøren** (apex-domenet `kolorist.no`):
   - `A`: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `AAAA`: `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`
   - `CNAME` for `www`: `eivijoha.github.io`
2. **GitHub › Settings › Pages:** *Source* = «GitHub Actions», *Custom domain* = `kolorist.no`, og slå på
   *Enforce HTTPS* når sertifikatet er klart (kan ta opptil et døgn etter at DNS er på plass).
   Med Actions-publisering er det innstillingen i GitHub som teller; `CNAME`-filen er med for ordens skyld.
3. Anbefalt: verifiser domenet under GitHub › Settings (konto) › Pages › *Add a verified domain*, så ingen
   andre kan ta det i bruk på GitHub Pages.
4. Arbeidsflyten `.github/workflows/pages.yml` publiserer ved hver push til `main` som endrer `web/`.

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
| `<!-- TODO: skjermbilder -->` / `<!-- TODO: screenshots -->` | `index.html`, `en/index.html` | Bytt `<div class="ramme">` med `<img>` (legg bildene i `assets/`), med beskrivende `alt`-tekst |

Når alt er fylt inn, skal dette ikke gi treff:

```bash
grep -rn 'TODO\|\[kontakt-e-post\]\|\[contact email\]\|\[app-store' web
```

## Publisering med GitHub Pages

GitHub Pages kan publisere direkte fra en gren («Deploy from a branch»), men da kan du bare velge rotmappen
(`/`) eller `/docs` – **`/web` kan ikke velges**. Det er to løsninger:

1. **Anbefalt: GitHub Actions.** Arbeidsflyten `.github/workflows/pages.yml` (i roten av repoet) publiserer
   innholdet i `./web` hver gang noe i `web/` endres på `main`, og kan også kjøres manuelt.
   - Gå til **Settings › Pages › Build and deployment › Source** og velg **GitHub Actions**.
   - Push til `main` (eller kjør «Publiser nettsider» under *Actions*).
   - Adressen vises i jobben og under *Settings › Pages*.
   - Arbeidsflyten bruker `actions/configure-pages`, `actions/upload-pages-artifact` (med `path: web`) og
     `actions/deploy-pages`.
2. **Alternativ: flytt mappen til `/docs`.** Gi mappen nytt navn til `docs`, og velg *Deploy from a branch* →
   `main` → `/docs`. Da trengs ikke arbeidsflyten.

Eget domene: legg til domenet under *Settings › Pages › Custom domain* (med arbeidsflyten trengs ingen
`CNAME`-fil). Slå på *Enforce HTTPS*.

Merk: Siden hele `web/` lastes opp, blir også denne `README.md` tilgjengelig som ren tekst på nettstedet.
Det er ufarlig, men flytt den ut av `web/` om du ikke vil ha det slik.

## Endringer

- Stilen ligger i `assets/stil.css`. Fargene er definert som variabler i `:root`; mørk modus i
  `@media (prefers-color-scheme: dark)`. `oklch()`/`oklab()` brukes der nettleseren støtter det, med hex først
  som reserve.
- Topptekst, meny og bunntekst er kopiert i hver side (ingen byggesteg). Endrer du menyen, endre alle åtte
  sidene.
- Oppdater «Sist oppdatert» i `privacy.html` og `en/privacy.html` (og `terms.html`) når innholdet endres.
