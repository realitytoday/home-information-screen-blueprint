# API contract

Extracted from the working implementation. Two HTTP listeners:

- **API listener** (`{{API_PORT}}`): serves the built frontend at `/` and the REST API under `/api/`.
  Every `/api/` route except `GET /api/health` requires the header `X-API-Key: <key>`.
- **Webhook listener** (`{{WEBHOOK_PORT}}`): `POST` only, no API key. Each endpoint has its own token,
  sent as header `X-Webhook-Token` or query parameter `?token=` (alarm systems often cannot set headers,
  so the query parameter is the one you will actually use). Tokens are compared in constant time.
  An unset token disables that one endpoint and logs it at startup.

Request bodies for the CRUD routes mirror the stored YAML types in `../fixtures/`. Responses use JSON with
the field names shown. JSON and YAML field names are identical.

## Health

| Route | Notes |
|---|---|
| `GET /api/health` | No key. `{"status":"ok","version":"<git short sha>"}`. The version is baked in at build time and is how you detect a stale deploy. |
| `GET /api/config` | `{"orderWhatsappNumber": "..."}`. Optional deep-link target for submitting food orders. |

## People, schedule, notes

| Route | Notes |
|---|---|
| `GET/POST /api/people`, `PUT/DELETE /api/people/{id}` | `{id,name,initials,color,home}` plus optional `fobUid`. `home` is derived from presence at read time. Deleting a person does not clean up references elsewhere. |
| `GET/PUT /api/schedule` | `{rules:[{startHour,endHour,tab}], idleTimeoutMs}`. `tab` is `calendar`, `weather` or `orders`. |
| `GET/POST /api/notes`, `PUT/DELETE /api/notes/{id}`, `POST /api/notes/{id}/position` | `{id,text,personId,showUntil,x,y}`. `personId:""` means the whole family. `x,y` are 0..1 fractions of the canvas. Expired notes are not returned. |

## Calendar

| Route | Response |
|---|---|
| `GET /api/calendar/today` | `{events: CalendarEvent[], error?}`. `CalendarEvent` is `{id,time:"HH:MM",endTime?,title,personId}`, sorted by time. `personId:""` is the shared family calendar. |
| `GET /api/calendar/week` | `{days: WeekDay[], error?}`. `WeekDay` is `{dow:"Mo".."So",date:<day of month>,isToday,events:CalendarEvent[]}`. Rolling seven days starting today. |

Both accept a bare `?refresh` flag that bypasses the cache (the reload button on the screen) and send an ETag.
When a configured calendar is unreachable they return `error` with a human-readable message and **no events**:
never fake events for a real calendar. Without a configured calendar they serve the fixture week.
An optional school-timetable integration (WebUntis) merges extra events per person; it is not required.

## Weather

`GET /api/weather` returns:

```json
{
  "now":    {"tempC":16,"feelsLikeC":15,"hiC":18,"loC":9,"condition":"Regen","icon":"rain",
             "windKmh":14,"humidityPc":78,"rainPc":60,"isDay":true},
  "hourly": [{"hour":15,"tempC":16,"icon":"rain","rainPc":60,"isDay":true}],
  "outlook":[{"dow":"Do","isToday":true,"condition":"...","icon":"cloud","hiC":18,"loC":9,
              "rainByHour":[0,0,10],"sunByHour":[0,0,1800]}]
}
```

`icon` is one of `sun partly cloud fog rain snow storm dust`. `sunByHour` is seconds of sunshine per hour
(0..3600), a real forecast quantity. `hourly` and `now.isDay` are optional for older clients.
Source: Open-Meteo (`forecast` with `current`, `daily`, `hourly` incl. `sunshine_duration`, and the
`air-quality` endpoint for dust). WMO weather codes are mapped to the icon set.

## Chores

Chores are a **weekly rotation table**, not per-day records.

| Route | Notes |
|---|---|
| `GET/PUT /api/chores` | `{chores:[{task,weekday(0=Sunday..6),personId}]}` |
| `POST /api/chores/parse` | Validate pasted YAML and return the parsed rotation (admin editor). |
| `GET /api/tasks/today` | `Task[]`: `{id:"chore-<index>",personId,title,state:"open"|"confirming"|"done",due?,warn?}` |
| `GET /api/tasks/upcoming` | `[{date:"YYYY-MM-DD",dow,day,tasks:Task[]}]`, the next two days, read-only. |
| `POST /api/tasks/{choreId}/state` | Body `{"state":"open"|"confirming"|"done"}`, answers `204`. Stored per day in `tasks/state.yaml`. No per-person authentication (a known gap). |

## Food

| Route | Notes |
|---|---|
| `GET /api/orders` | `{restaurants: Restaurant[]}` for the board. |
| `POST /api/restaurants`, `PUT /api/restaurants/order`, `PUT/DELETE /api/restaurants/{id}` | Restaurant: `{id,name,cuisine?,color,icon,logoUrl?,minEta?,maxEta?,trackingUrl?,defaultFulfillment:"delivery"|"pickup"|"selber",cartEnabled}`. `icon` is `burger pizza bowl kebab snowflake generic`. |
| `GET /api/shops/{id}` | Shop: `{id,name,menuUrl,catalog,usuals,menu,pendingOrder,eaters}`. `pendingOrder` and `eaters` are runtime state. |
| `GET /api/shops/{id}/catalog?q=` | Search a numbered catalog (for restaurants with menu numbers). |
| `POST /api/shops/{id}/usuals`, `DELETE /api/shops/{id}/usuals/{usualId}` | A person's saved "usual" order. |
| `POST /api/shops/{id}/order-items`, `DELETE .../order-items/{itemId}`, `POST .../order-items/{itemId}/decrement` | The running shared order for this week. |
| `POST /api/shops/{id}/eaters/toggle` | Who is eating tonight. |
| `POST /api/shops/{id}/order/submit` | Sends the whole order as one message (chat webhook or `wa.me` link) and records it. Ordering and payment happen on the restaurant's own site; the screen only tracks. |
| `PUT /api/shops/{id}/menu`, `POST /api/shops/{id}/menu/parse` | Menu categories `[{name,items:[string],hidden?}]` from pasted YAML. |

## Presence and activity

| Route | Notes |
|---|---|
| `GET /api/presence`, `PUT/DELETE /api/presence/{personId}` | Device list: `{personId, ip, mac?}`. `PUT` body `{"ip":"...","mac":"..."}`. |
| `GET /api/admin/presence-history`, `DELETE /api/admin/presence-history/today` | Seven-day history, one file per day. |
| `GET /api/motion` | `{"lastMotion": "<RFC3339>"|null}` from the motion webhook. |
| `POST /api/activity/touch`, `GET /api/admin/activity` | Per-day activity counters for the admin graph (calendar and weather fetches, touch activations). |

## Sensors

| Route | Notes |
|---|---|
| `GET /api/sensors` | `{doors:[{id,room,open,since,lowBattery,tamper}], leaks:[{id,room,leak,lowBattery,tamper}], temps:[{id,room,type,status:"normal"|"cold"|"hot"|"alert",lowBattery,tamper}]}`. `type` is `temperature`, `humidity` or `light`. |
| `POST /api/sensors/{id}/clear` | Dismiss a latched alert **for that sensor id only**, not its siblings on the same device. |
| `GET/POST /api/admin/sensors`, `PUT/DELETE /api/admin/sensors/{id}`, `PUT /api/admin/sensors/order` | Config `{id,room,type:"door"|"leak"|"temperature"|"humidity"|"light",deviceMac}`. Order body `{"ids":[...]}`. |

## Admin and operations

| Route | Notes |
|---|---|
| `GET /api/admin/apikey`, `POST /api/admin/apikey/regenerate` | Reveal and rotate the shared key. |
| `GET/PUT /api/admin/caldav`, `POST /api/admin/caldav/test` | Server URL, username, write-only password, calendar allow-list. `PUT` swaps the live client with no restart. `test` is a dry run. |
| `GET/PUT /api/admin/mattermost`, `POST /api/admin/mattermost/test` | Optional pickup notification webhook (any incoming chat webhook works). |
| `GET /api/admin/webhooks` | `{doorUrl,motionUrl,presenceUrl,sensorsUrl}`, fully formed with tokens, ready to paste. |
| `GET /api/admin/backup`, `POST /api/admin/backup/restore` | Whole data volume as an archive. |
| `GET /api/admin/files`, `GET/PUT /api/admin/files/{path...}` | Raw YAML editor over the data volume. |

## Webhooks (separate listener)

| Route | Body | Effect |
|---|---|---|
| `POST /webhook/door` | ignored | Presence re-check now, and again after `DOOR_RECHECK_DELAY` (default 5 min), because phones rejoin Wi-Fi after the door opens. |
| `POST /webhook/motion` | none | Records a timestamp. The Pi's motion agent sends it at most every 30 s. |
| `POST /webhook/presence` | `{"results":{"<personId>":true}}` | Sets presence per person. Omitted people are left unchanged, not set to away. Generic: any script can call it. |
| `POST /webhook/sensor` | alarm envelope, below | Records the latest event per **device and trigger key**. |

### Sensor webhook envelope

Only these fields are read. Shape observed from a UniFi Protect alarm webhook:

```json
{
  "alarm": {
    "triggers": [
      {
        "key": "sensor_extreme_value",
        "device": "AABBCCDDEEFF",
        "notificationEventKey": "sensor_extreme_value_high_humidity",
        "value": "high"
      }
    ]
  }
}
```

- `key` is `sensor_water_leak` or `sensor_extreme_value`. Unknown keys are logged and ignored, so a new
  trigger type is visible in the logs instead of silently dropped.
- For `sensor_extreme_value`, the temperature/humidity/light **type** comes from the suffix of
  `notificationEventKey`, and the direction from `value` (`high` or `low`). The trigger carries no
  numeric reading.
- Stored under keys like `sensor_extreme_value:humidity:high`, so one device reporting several things
  does not collide. Normalize MACs (lowercase, no separators) at every write and match.
- Leaks latch until dismissed (the vendor never sends "cleared"). Extreme-value alerts expire after
  `SENSOR_EXTREME_TIMEOUT` (default 6 h).

## Persistence layout (data volume)

```
api_key                   generated on first boot
people.yaml  schedule.yaml  chores.yaml  notes.yaml  restaurants.yaml
sensor-config.yaml  caldav-config.yaml  mattermost-config.yaml
shops/<restaurantId>.yaml      menu, catalog, usuals
orders/<restaurantId>.yaml     pending shared order
tasks/state.yaml               per-day chore tick-off state
activity.yaml  presence history (one file per day)
```

See `../fixtures/` for a complete invented example household.
