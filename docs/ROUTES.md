# Named routes and ordered stops

Use GitHub Desktop to select `codex/mouse-track-building`, Fetch origin, then
Pull origin. Close Godot before pulling and reopen the existing project afterward.
This update uses save version 14. Start a fresh game; older saves are not migrated.

## Try a three-stop passenger service

1. Pause the game and connect Station A (4,8) to Station B (20,8).
2. Extend east from Station B to the new Station C (36,8). Each platform remains
   horizontal. Existing construction costs, previews and Undo still apply.
3. Click **Routes** on the toolbar. Opening the window pauses the game.
4. Select **Passenger service**, enter a name, select **Station C**, then **Add**.
5. Select a stop and use **Up** or **Down** to change its order. **Remove** removes
   it from the service, not from the map. Keep at least two different stops.
6. Click **Apply**, close the window, then resume using the pause button.
7. With A, B, C selected, the train visits A → B → C → B → A. It stops to exchange
   passengers at every listed station. An unlisted station can be passed through.
8. Save using the toolbar. Reload to restore the names, stop order, station queues,
   train position, dwell and current direction.

You can pan east using the existing camera controls or click Station C on the map.
Station C appears in the minimap and supports the existing station inspector.

## Editing behaviour

- Each existing train has one named service. Purchasing more trains is a later step.
- Passenger routes use two or three unique stations. Lists run as shuttles, not loops.
- Renaming a route does not interrupt its train.
- Applying a different stop order returns onboard passengers to their departure
  station and places the train at the new first stop. No fares are awarded for this.
- All legs must be connected before the passenger service runs. A missing leg is
  identified in the status message. Repairing the track restores the service.
- Withdrawal completes the round trip and parks at the configured first stop.
- Closing without Apply discards draft edits; Apply updates the game, and the Save
  button writes it to disk. The game remains paused when the Routes window closes.
- Freight can be renamed, but Forest → Terminal keeps its fixed load/unload roles.
- Passengers currently travel to the next listed stop. Individual destinations and
  transfers are not included yet.

## Automated checks

With Godot 4 on PATH, from the project directory:

```sh
godot --headless --path . --script res://tests/test_mouse_tracks.gd
godot --headless --path . --script res://tests/test_service_routes.gd
```

These integration tests write saves. On Linux set separate `XDG_CONFIG_HOME`,
`XDG_DATA_HOME` and `XDG_CACHE_HOME` directories to avoid replacing a playing save.
The cloud checks used Godot 4.6.3. Windows mouse interaction requires a local check.
