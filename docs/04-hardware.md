# Hardware and wiring

## Parts

| Item | Notes |
|---|---|
| Touchscreen | 14" Full HD, USB touch, mounted portrait (rotated 90° left). Any similar panel works; the touch controller's device name matters later. |
| Raspberry Pi 4B, 4 GB | The first version ran on a Pi 2 with 1 GB and was workable; the Pi 4 removes the squeeze. Use a 64-bit OS (arm64). |
| PIR motion sensor (HC-SR501 or similar) | Wakes and sleeps the panel. |
| Official Raspberry Pi 4 Case | The standard case from the [Raspberry Pi 4 Case product page](https://www.raspberrypi.com/products/raspberry-pi-4-case/). It is already ventilated and tested; only the mount is printed (see Mounting). |
| HDMI and USB cables | 20 to 30 cm is plenty if the Pi sits next to the screen. |
| 3D printer (optional) | The mount is printed in ASA, because it sits next to a warm Pi 16+ hours a day. PLA creeps under sustained mild heat. |
| Optional: PN532 NFC reader, status LEDs, USB BLE adapter | Only for the unbuilt extras (fob confirmation, status light, beacon presence). |

## Power: check before you trust it

I ran the Pi from the monitor's USB hub, with no separate supply. A Pi 4B is
specified for 5 V at 3 A. Many monitor USB-A ports supply only 0.5 to 1.5 A. It
will boot fine and then brown out under load: flaky USB peripherals, the
under-voltage warning, or random reboots when you add the NFC reader or LEDs.

- Measure or look up the port's real rating before wiring extra loads onto it.
- If it is short, the fix is a USB-C cable and a spare charger, not a redesign.
- If you do power through the monitor, keep extra peripherals to a minimum.
- There is no shutdown button on a wall appliance, so unplugging is "off".
  Patch the browser's saved exit state at startup (see lessons learned) so a
  hard power cut does not greet you with a "restore pages?" prompt.

## Wiring

All header numbering below is the standard 40-pin Raspberry Pi header. Double
check against a pinout diagram for your board before connecting anything.

### PIR sensor (HC-SR501)

| PIR pin | Pi header | Notes |
|---|---|---|
| VCC | Pin 2 (5 V) | The module wants 5 V |
| GND | Pin 6 (GND) | |
| OUT | Pin 12 (BCM GPIO18) | The output is 3.3 V logic, safe for a Pi input |

Advice:

- Female-to-female Dupont jumpers go straight onto the header pins.
- Use a plain GPIO input and poll or use edge detection from a small Go (or any)
  daemon; no kernel overlay needed.
- The module has two trimmers (sensitivity and hold time) and a retrigger
  jumper. Turn the hold time to minimum and do the "five minutes of no motion"
  logic in software, where you can change it.
- Let it warm up for about a minute after power-on; it reports false motion
  while it stabilises.
- Do not mount it behind plastic. The dome is a Fresnel lens; even thin
  "clear" printed plastic attenuates the infrared band unevenly and shrinks the
  detection cone. Leave the aperture open and facing the room, level rather
  than tilted at the floor.
- Heat from the Pi can cause false triggers if the sensor sits right on top of
  the SoC. Put some distance, or use the side of the case away from the chip.

### Optional: NFC reader (PN532)

- Chosen over the RC522 because copy-resistant tags need ISO 14443-4 / DESFire
  support. Use **DESFire EV1/EV2/EV3 or NTAG 424 DNA** fobs, not MIFARE Classic
  (its static UID is trivially clonable).
- The PN532 supports I²C, SPI and UART via a switch or solder jumpers. I²C is
  the simplest: SDA to pin 3, SCL to pin 5, 3.3 V power, GND.
- Keep the antenna coil clear of metal and carbon-fibre or metal-filled
  filament; plain ASA or PETG over it is fine.
- Not built into the running system. Treat it as an extension.

### Optional: status LEDs

- Discrete LEDs, one GPIO per color, each with a series resistor of about 330 Ω
  to 470 Ω. Avoid addressable LEDs (WS2812): they need a 5 V data line and
  precise timing for very little gain here.
- Two or three LEDs behind one diffuser is realistic. A status language with
  four hues plus "off" is more than that gives you; collapse states onto fewer
  colors. Match the UI's semantic colors: amber pending, green confirmed, red
  offline or stale.

## Mounting

The Pi lives in a standard Pi 4 case hung upside down under a shelf board, held
by magnets. Only the mount is printed.

- **Mount plate:** screwed up into the board with countersunk wood screws, with a
  through-cutout for a thin steel plate fixed to the board.
- **Magnet carrier:** taped to the case base with VHB, nests into that cutout and
  holds four 10 × 3 mm N52 magnets in blind pockets that open toward the case.
- **Corner posts** on the plate take sideways load, because magnets are weak in
  shear. To remove the Pi, pull straight down: no tools for SD-card swaps.
- A snap-tab variant works instead of magnets, but depends on a measured case
  height; retailer dimensions vary.
- Measure your actual case before printing. Parametric model recommended.
- Keep all four sides of the case open: power and micro-HDMI on one long side,
  the touch USB cable on the short side, the PIR on the header side facing out.
- An earlier fully custom enclosure (PIR pod, RFID pad, LED ring) was dropped for
  this. It was more work for little gain, and the official case is already
  ventilated and tested.

## Raspberry Pi OS: rotation and touch (Wayland, not X11)

Current Raspberry Pi OS (Trixie) uses **labwc**, a Wayland compositor. The X11
tools `xrandr` and `xinput` do not apply. Under labwc they fail outright, and
combined with `set -e` in a launch script they abort it before the browser even
starts. Do not use them.

1. **Rotation:** set the screen orientation to 270 (counter-clockwise) in the
   desktop's Screens control panel. Check the live value with `wlr-randr`,
   which works over plain SSH.
2. **Touch mapping:** labwc's own config (`~/.config/labwc/rc.xml`):

   ```xml
   <touch deviceName="<your touch controller's full device name>"
          mapToOutput="HDMI-A-1" mouseEmulation="no"/>
   ```

   labwc adjusts the touch transform for the output's rotation by itself.

   - The device name includes the USB port path, which **changes if you move the
     cable or swap the board**. If touch stops working, check the live device
     name first.
   - **`mouseEmulation` must be `"no"`.** With `"yes"` the compositor turns real
     touches into synthetic mouse events before the browser sees them, which
     breaks finger-drag scrolling everywhere: only grabbing the scrollbar works.
     Reload the compositor config with a HUP signal; no reboot needed.

If you lose the settings (new SD card, new panel), redo them exactly this way.

## Screen power: use `wlopm`

To blank the panel on idle, use `wlopm` (the output-power-management tool). Do
**not** disable the output with `wlr-randr --off`: it crashes the browser's
rendering surface, kills the kiosk, and leaves you at a bare desktop. `wlopm`
blanks the backlight without disabling the output, so the compositor and browser
survive.

Remember to enable the kiosk service at boot; a service only ever started by
hand will not come back after a power cycle.

## Kiosk browser

Chromium with the usual kiosk flags (`--kiosk`, no error dialogs, no info bars,
incognito or an app window pointing at the backend). On Debian Trixie the binary
is `chromium`, not `chromium-browser`. Run it as a systemd service with
`Restart=always`, because Chromium can exit *cleanly* after handing a URL to a
stray existing instance, and `Restart=on-failure` will not catch that.
