# Concept

## The problem

A family's coordination lives in five apps and nobody opens any of them at the
right moment. Who has what appointment today? What is the weather doing? Who is
home? Whose turn is it to do the dishes? Is anything leaking in the basement?
The answer should be visible from four steps away, without unlocking anything.

## The idea

One screen in the hallway that answers those questions and otherwise stays out
of the way. It is shared, not personal: nobody owns a session, nothing needs a
login to read, and everything makes sense to whoever happens to be standing
there.

Design principles that came out of living with it:

- **Shared, not personal.** No ambient login. Anything that acts on someone's
  behalf should need an explicit gesture.
- **Always on, so dark and calm.** It hangs there 16 hours a day. A bright white
  dashboard at 7 a.m. is a light source nobody asked for.
- **One glance tells the state.** Whose chores are open, what is next, who is
  home: answerable without touching it.
- **Stale beats blank.** If the network or an API fails, show the last good data
  with an age indicator rather than an error.
- **Read-mostly.** The screen displays what lives in other systems (calendar
  server, weather service, router). It owns little data itself.

## The seven screens

Navigation is a floating, icon-only tab bar at the bottom. A screen never names
itself; the tab bar already did.

| Screen | What it shows |
|---|---|
| **Idle** | Huge clock and date, a one-line weather summary, and who is home. Deliberately sparse. |
| **Calendar** | A rolling 7-day strip with colored dots per person, a large "next up", then one continuous list of events. Read-only. |
| **Food** | A grid of restaurant tiles, a random-pick button, per-person "usual orders", and order tracking. Ordering itself happens on the restaurant's own site; the screen only tracks it. |
| **Chores** | Today's chores grouped by person with round checkboxes in the person's color, plus a two-day read-only preview. |
| **Weather** | An Apple-Weather-style layout: animated sky, hourly strip, a rain-versus-sunshine chart, range bars for the coming days. |
| **Sensors** | Doors and windows, water leaks (a loud red banner until dismissed), temperature and humidity threshold status. |
| **Notes** | A freeform board of draggable sticky notes with an on-screen keyboard. "Back around 7" without texting someone who will not look at their phone. |

### The default screen follows the clock

The home screen is not a fixed tab. A time-of-day schedule picks it: calendar in
the morning, weather over lunch, food in the evening, idle at night. A manual tap
overrides the schedule until the panel next sleeps. A new note outranks the
schedule only after the idle timer fires, never the instant it appears, so it
cannot pull the screen away from someone mid-task.

### Sleep and wake

A PIR sensor wired to the Pi drives power: no motion for five minutes and the
backlight blanks; any motion or touch wakes it to whatever the schedule says for
that time. This runs locally on the Pi and must work even when the network is
down.

## Presence is not authentication

Two different questions with two different bars of evidence:

- **Who is home?** Weak evidence is fine (phone on the WiFi, a ping, a door
  event). Being wrong just fades a status chip.
- **Who is standing at the screen?** A much higher bar. Being on the LAN says
  nothing about who is touching the panel. This was designed (tap an RFID fob to
  confirm a chore) but never built; chores tick off without a gate.

Keeping these separate in the design stopped me from building a clever but
misleading "smart" login out of presence data.

## What it deliberately is not

- Not a smart-home controller. It reads sensors; it does not switch things.
- Not a payment system. "Paid" is a tracked state, not a transaction.
- Not multi-tenant, not internet-facing, no accounts. One household, one LAN.
- Not a product. It is an appliance for one family.

## How it was built

Documentation-first with AI coding agents. A short project brief
(`CLAUDE.md`) holds the settled decisions and is read at the start of every
session. A separate decision-and-incident log records why things are the way
they are. Each integration was built as a vertical slice and verified against
the real hardware before the next began. The prompts in this repo are that
process, distilled.
