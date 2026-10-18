# Home Information Screen — ein Bauplan statt Code

*English version: [README.md](README.md)*

Ein Haushalts-Dashboard an der Wand: Raspberry Pi plus Touchscreen im Hochformat.
Es zeigt den gemeinsamen Kalender, das Wetter, ein Essensbrett ("Was bestellen
wir heute?"), Aufgaben, Sensoren und Notizzettel. Es wacht auf, wenn jemand
vorbeigeht, und schläft, wenn niemand da ist.

Gebaut in etwa drei Wochen im September 2026 mit KI-Coding-Agenten. In diesem
Repository liegt **kein Code**, sondern das, was ich einem Freund geben würde,
der sich eine eigene Version bauen möchte:

- **Idee und Bildschirme:** [docs/01-concept.md](docs/01-concept.md)
- **Architektur** samt Begründungen: [docs/02-architecture.md](docs/02-architecture.md)
- **Design-System** "Ruhe": [docs/03-design-system.md](docs/03-design-system.md)
- **Hardware** und Wayland-Konfiguration: [docs/04-hardware.md](docs/04-hardware.md)
- **Lessons Learned:** [docs/05-lessons-learned.md](docs/05-lessons-learned.md)
- **Prompts** für den eigenen Coding-Agenten: [prompts/](prompts/README.md)

## Warum kein Code?

Solche Software ist schnell erzeugt, aber aufwendig anzupassen. Dein
Kalenderserver, dein Router, deine Familie und deine Sprache sind anders als
meine. Eine präzise Beschreibung dessen, *was* gebaut wird, *warum* so
entschieden wurde und *wo es bricht*, lässt sich besser übertragen als fertiger
Code. Dein Agent passt sie an deine Umgebung an.

## So gehst du vor

1. Konzept und Architektur lesen (ca. 15 Minuten).
2. Entscheiden, was du brauchst. Optional sind Anwesenheit, Sensoren,
   Bewegungs-Standby und das Essensbrett.
3. [prompts/00-project-brief.md](prompts/00-project-brief.md) als `CLAUDE.md`
   in ein neues Repo legen und die Platzhalter ausfüllen.
4. Die Prompts 01 bis 06 der Reihe nach abarbeiten und jeweils die
   Abnahmekriterien prüfen.
5. Von Anfang an ein Entscheidungsprotokoll führen. Es ist die nützlichste
   Datei im ganzen Projekt.

## Benötigt

Ein Full-HD-Touchscreen (ab 14", Hochformat), ein Raspberry Pi 4B mit
Raspberry Pi OS Trixie (labwc/Wayland), ein dauerhaft laufender Rechner mit
Docker (NAS, Mini-PC), optional PIR-Sensor, UniFi-Gateway und CalDAV-Server.

Die UI-Texte meiner Version sind deutsch; die Prompts sind so geschrieben, dass
die Sprache ein Parameter ist.

## Lizenz

Texte und Prompts: CC BY 4.0.

## Referenzmaterial

Der Ordner [`reference/`](reference/README.md) enthält bereinigte Pi-Skripte (Kiosk-Start, Bewegungs-Dienst, systemd-Units), den API-Vertrag, die Farbpaletten-Datei und einen erfundenen Demo-Haushalt als Testdaten. Die Admin-Oberfläche ist in [docs/06-admin-interface.md](docs/06-admin-interface.md) beschrieben (englisch). Der Anwendungscode selbst (Backend, Frontend) ist nicht enthalten.

## Lizenz

Doppelt lizenziert. Texte, Prompts und Screenshots (`README`, `docs/`, `prompts/`): [CC BY 4.0](LICENSE-docs.md). Code und Konfiguration unter `reference/`: [MIT](LICENSE).
