# How it works

## How each display is controlled

Every display macOS is driving gets one row and one slider, the built-in display included. Which path a row takes is
decided by a real read each time the displays are enumerated (launch, plug, wake, popover open), so a monitor that
starts answering DDC/CI is picked up without a restart.

- **Hardware.** An external display that answers DDC/CI. The slider moves the monitor's own backlight over its cable:
  one feature, brightness (VCP `0x10`). True Tone, Dark Mode and Night Shift are not DDC: they are set on the Mac
  itself (CoreBrightness and SkyLight).
- **Software dim.** A display that did not answer. The picture is dimmed through the display's gamma table, never
  below 10 %, and only while the app runs. It lowers the picture, not the backlight.
- **Built-in.** The Mac's own panel, through macOS.

### What a row can show

A row shows exceptions only. A display under hardware control carries no glyph.

- **Half-filled circle.** Software dimming: the display did not answer DDC/CI.
- **Question mark.** The write went through but the display did not confirm the level.
- **Warning triangle.** The display did not accept the change.

A level is shown as set only once the display has reported it. While a write is in flight the percentage is dimmed.

### The menu bar icon and scroll

The lit rays are the level of the focused external monitor: the one you used last, else the first. The centre dot
means an external monitor is attached. With none attached the rays show the built-in display's level and the dot is
off.

Scrolling over the icon nudges the display the icon shows, by 5 % a notch on a wheel and in finer steps on a
trackpad, and shows the new level in the icon itself. The popover stays closed. With no external monitor that display
is the built-in panel.

Monitors are read on launch, wake, display change and popover open (skipped when the last read is under 10 s old).
They are never polled. The only repeating read is for the built-in panel: while it is what the icon shows, its level is
re-read every 2 s, because the brightness keys and auto-brightness change it without telling the app. That read is
macOS's own brightness and never touches a monitor, and it stops when an external monitor takes the icon over.

## Why every request goes twice

Some monitors, the Dell U2723QE among them, swallow the first DDC/CI command after sitting idle and answer only the
second. A single request on those displays gets nothing but a null message back, which looks exactly like DDC/CI
being off. So every request is sent twice, 40 ms apart, before the reply is read. A display that answers both returns
the same answer twice, and setting the same level again is harmless.

### What is checked before a level is believed

Every reply is validated: source, length, checksum, opcode and the echoed feature. The echoed feature matters because
a display with another client on its channel hands each client the other's answers. After every write the level is
read back, up to three times, and shown only once it matches. If it never does, the row says so with a question mark.

## The switches on the Mac

Dark Mode, Night Shift and True Tone belong to the Mac, not to a monitor, so none of them goes over DDC/CI. They are a
row of three round Liquid Glass circles under the displays. Below them, "Display Settings…" opens System Settings >
Displays and closes the panel; schedules, arrangement and resolution stay there.

### Which ones appear

Only the modes this Mac has. True Tone is hidden when the Mac does not support it, Night Shift when CoreBrightness is
missing. Dark Mode is always shown, because it has a fallback.

### How each is set

Night Shift and True Tone go through CoreBrightness (`CBBlueLightClient`, `CBTrueToneClient`) by way of the
Objective-C runtime. The framework is loaded at runtime and every selector is checked before it is called, so a
selector that has gone is a missing feature, not a crash.

Dark Mode goes through SkyLight (`SLSSetAppearanceThemeLegacy`), inside a WindowServer cross-fade, as System Settings'
own switch fades. `SLSNewTransition` holds the screen, the switch happens, the hold lasts 200 ms so apps can redraw
in the new appearance, and `SLSInvokeTransition` fades the hold away over 0.4 s. If a transition symbol is missing the
switch is instant.

If the SkyLight call has not taken effect after about 300 ms, the app asks System Events to switch it through
AppleScript. macOS then asks for Automation, once. This is the only path in the app that can raise a permission
prompt; the one usage description (`NSAppleEventsUsageDescription`) and the one entitlement
(`com.apple.security.automation.apple-events`) exist for it.

### What is shown

A toggle flips at once and shows pending until the system's own read-back confirms the change. The read-back is
repeated up to three times, 100 ms apart. If it never matches, the row says "Did not change" and shows what the
system reported.

The state text is worded as macOS words it: "On Until Sunrise", "Off Until Sunset", a custom schedule's time, and
"Until Tomorrow" after a manual change inside a schedule. When the app cannot tell what applies, it says plain On or
Off. The "Until Tomorrow" memory is held in memory for the session, so a relaunch shows the schedule's own wording
again. While a change settles, the text keeps its wording and line count, so the row does not jump.

### Why the panel is key

The panel is macOS 26 Liquid Glass (`glassEffect`). Glass draws its inactive, flat look in a window that is not key: it
drops every tint and frosts clear glass. So the panel is made key while it is shown, and showing it activates the app
and takes focus from the app you were in, deliberately.

### If macOS removes an interface

IOAVService, DisplayServices, CoreBrightness and SkyLight are private, and all four are resolved at runtime
(`dlsym` or the Objective-C runtime); none is hard-linked. If one disappears, the matching feature hides or falls
back: software dimming for displays, a hidden toggle for Night Shift or True Tone, System Events for Dark Mode.
