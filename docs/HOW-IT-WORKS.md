# How it works

## How each display is controlled

Every display macOS is driving gets one row and one slider, the built-in display included. Which path a row takes is
decided by a real read each time the displays are enumerated (launch, plug, wake, popover open), so a monitor that
starts answering DDC/CI is picked up without a restart.

- **Hardware.** An external display that answers DDC/CI. The slider moves the monitor's own backlight over its cable:
  one feature, brightness (VCP `0x10`).
- **Software dim.** A display that did not answer. The picture is dimmed through the display's gamma table, never
  below 10 %, and only while the app runs. It lowers the picture, not the backlight.
- **Built-in.** The Mac's own panel, through macOS.

### What a row can show

A row shows exceptions only. A display under hardware control carries no glyph.

- **Half-filled circle.** Software dimming: the display did not answer DDC/CI.
- **Question mark.** The write went through but the display did not confirm the level.
- **Warning triangle.** The display did not accept the change.

A level is shown as set only once the display has reported it. While a write is in flight the percentage is dimmed.

### Scroll to nudge

Scrolling over the menu bar icon nudges the display you used last, by 5 % a notch on a wheel and in finer steps on a
trackpad, and shows the new level in the icon itself. The popover stays closed.

## Why every request goes twice

Some monitors, the Dell U2723QE among them, swallow the first DDC/CI command after sitting idle and answer only the
second. A single request on those displays gets nothing but a null message back, which looks exactly like DDC/CI
being off. So every request is sent twice, 40 ms apart, before the reply is read. A display that answers both returns
the same answer twice, and setting the same level again is harmless.

### What is checked before a level is believed

Every reply is validated: source, length, checksum, opcode and the echoed feature. The echoed feature matters because
a display with another client on its channel hands each client the other's answers. After every write the level is
read back, up to three times, and shown only once it matches. If it never does, the row says so with a question mark.
