// The hero's one interaction. The popover's slider and the icon's dial are two handles on one number: moving either
// lights the rays and brightens or dims the monitor. The slider is the accessible one (a real slider with keys);
// the dial is a pointer shortcut and stays out of the tab order. Without this script the page shows 75 %, still.
const stage = document.querySelector<HTMLElement>("[data-console]");
const slider = stage?.querySelector<HTMLElement>("[data-slider]");
const dial = stage?.querySelector<SVGSVGElement>("svg.dial");
const out = stage?.querySelector<HTMLElement>("[data-pct]");

if (stage && slider && dial && out) {
  const rays = [...dial.querySelectorAll<SVGLineElement>(".ray")];
  const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let level = Number.parseInt(out.textContent ?? "75", 10);
  let lit = rays.filter((r) => r.classList.contains("on")).length;

  // Upgrade the picture of a slider into one.
  slider.removeAttribute("aria-hidden");
  slider.setAttribute("role", "slider");
  slider.tabIndex = 0;
  slider.setAttribute("aria-label", slider.dataset.label ?? "Brightness");
  slider.setAttribute("aria-valuemin", "0");
  slider.setAttribute("aria-valuemax", "100");
  slider.setAttribute("aria-describedby", "console-hint");

  const paint = (jump: boolean) => {
    const p = level / 100;
    const next = Math.round(p * rays.length);
    stage.style.setProperty("--l", String(p));
    slider.style.setProperty("--p", String(p));
    slider.setAttribute("aria-valuenow", String(level));
    slider.setAttribute("aria-valuetext", `${level} percent`);
    out.textContent = `${level}%`;
    rays.forEach((ray, i) => {
      // A long jump sweeps: each ray waits a little longer than its neighbour. A drag stays immediate.
      ray.style.transitionDelay = jump && !calm ? `${Math.abs(i - lit) * 16}ms` : "";
      ray.classList.toggle("on", i < next);
    });
    lit = next;
  };
  const set = (value: number, jump = false) => {
    const next = Math.min(100, Math.max(0, Math.round(value)));
    if (next === level) return;
    jump = jump && Math.abs(Math.round((next / 100) * rays.length) - lit) > 2;
    level = next;
    paint(jump);
  };

  // Level under the pointer. The slider has a 20px knob, so its travel is the width less 20.
  const fromSlider = (e: PointerEvent) => {
    const box = slider.getBoundingClientRect();
    return ((e.clientX - box.left - 10) / (box.width - 20)) * 100;
  };
  // The dial: angle round its centre, as the icon draws it (7:30 clockwise to 4:30). The 90 degree gap at the
  // bottom belongs to whichever end is nearer.
  const fromDial = (e: PointerEvent) => {
    const box = dial.getBoundingClientRect();
    const dx = e.clientX - (box.left + box.width / 2);
    const dy = box.top + box.height / 2 - e.clientY;
    let sweep = (((225 - (Math.atan2(dy, dx) * 180) / Math.PI) % 360) + 360) % 360;
    if (sweep > 270) sweep = sweep - 270 < 45 ? 270 : 0;
    return (sweep / 270) * 100;
  };

  const drag = (el: Element, read: (e: PointerEvent) => number, wraps = false) => {
    let down = false;
    el.addEventListener("pointerdown", (e) => {
      const ev = e as PointerEvent;
      if (ev.button !== 0) return;
      down = true;
      (el as HTMLElement | SVGElement).setPointerCapture(ev.pointerId);
      stage.classList.add("drag");
      set(read(ev), true);
    });
    el.addEventListener("pointermove", (e) => {
      if (!down) return;
      const next = read(e as PointerEvent);
      // Going round the dial past the gap would jump from full to empty; stop at the end instead.
      if (wraps && Math.abs(next - level) > 60) return set(level > 50 ? 100 : 0);
      set(next);
    });
    const end = () => {
      down = false;
      stage.classList.remove("drag");
    };
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
  };
  paint(false);
  drag(slider, fromSlider);
  drag(dial, fromDial, true);

  const keys: Record<string, (v: number) => number> = {
    ArrowRight: (v) => v + 1,
    ArrowUp: (v) => v + 1,
    ArrowLeft: (v) => v - 1,
    ArrowDown: (v) => v - 1,
    PageUp: (v) => v + 10,
    PageDown: (v) => v - 10,
    Home: () => 0,
    End: () => 100,
  };
  slider.addEventListener("keydown", (e) => {
    const step = keys[e.key];
    if (!step) return;
    e.preventDefault();
    set(step(level), Math.abs(step(level) - level) >= 10);
  });
}
