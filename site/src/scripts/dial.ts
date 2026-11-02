// The hero's sliders. The Dell row's slider and the icon's dial are two handles on one number: moving either lights
// the rays and brightens or dims the monitor. The built-in row's slider moves only its own number, since no built-in
// display is drawn. The sliders are the accessible handles (real sliders with keys); the dial is a pointer shortcut
// and stays out of the tab order. Without this script the page shows the levels, still.
const stage = document.querySelector<HTMLElement>("[data-console]");
const dial = stage?.querySelector<SVGSVGElement>("svg.dial");
const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;

type Control = { level: () => number; set: (value: number, jump?: boolean) => void };

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

// Level under the pointer. The knob is 26px wide, so its centre travels the width less 26.
const fromSlider = (slider: HTMLElement) => (e: PointerEvent) => {
  const box = slider.getBoundingClientRect();
  return ((e.clientX - box.left - 13) / (box.width - 26)) * 100;
};
// The dial: angle round its centre, as the icon draws it (7:30 clockwise to 4:30). The 90 degree gap at the bottom
// belongs to whichever end is nearer.
const fromDial = (svg: SVGSVGElement) => (e: PointerEvent) => {
  const box = svg.getBoundingClientRect();
  const dx = e.clientX - (box.left + box.width / 2);
  const dy = box.top + box.height / 2 - e.clientY;
  let sweep = (((225 - (Math.atan2(dy, dx) * 180) / Math.PI) % 360) + 360) % 360;
  if (sweep > 270) sweep = sweep - 270 < 45 ? 270 : 0;
  return (sweep / 270) * 100;
};

// Upgrade the picture of a slider into one. `also` paints whatever else follows its level.
const bind = (slider: HTMLElement, out: HTMLElement, also?: (p: number, jump: boolean) => void): Control => {
  let level = Number.parseInt(out.textContent ?? "0", 10);
  slider.removeAttribute("aria-hidden");
  slider.setAttribute("role", "slider");
  slider.tabIndex = 0;
  slider.setAttribute("aria-label", slider.dataset.label ?? "Brightness");
  slider.setAttribute("aria-valuemin", "0");
  slider.setAttribute("aria-valuemax", "100");
  slider.setAttribute("aria-describedby", "console-hint");

  const paint = (jump: boolean) => {
    const p = level / 100;
    slider.style.setProperty("--p", String(p));
    slider.setAttribute("aria-valuenow", String(level));
    slider.setAttribute("aria-valuetext", `${level} percent`);
    out.textContent = `${level}%`;
    also?.(p, jump);
  };
  const set = (value: number, jump = false) => {
    const next = Math.min(100, Math.max(0, Math.round(value)));
    if (next === level) return;
    level = next;
    paint(jump);
  };
  paint(false);
  slider.addEventListener("keydown", (e) => {
    const step = keys[e.key];
    if (!step) return;
    e.preventDefault();
    set(step(level), Math.abs(step(level) - level) >= 10);
  });
  return { level: () => level, set };
};

// While held, an element carries `held` (a slider's knob turns to clear glass) and the stage `drag` (no easing).
const drag = (el: Element, read: (e: PointerEvent) => number, control: Control, wraps = false) => {
  let down = false;
  el.addEventListener("pointerdown", (e) => {
    const ev = e as PointerEvent;
    if (ev.button !== 0) return;
    down = true;
    el.setPointerCapture(ev.pointerId);
    stage?.classList.add("drag");
    el.classList.add("held");
    control.set(read(ev), true);
  });
  el.addEventListener("pointermove", (e) => {
    if (!down) return;
    const next = read(e as PointerEvent);
    // Going round the dial past the gap would jump from full to empty; stop at the end instead.
    if (wraps && Math.abs(next - control.level()) > 60) return control.set(control.level() > 50 ? 100 : 0);
    control.set(next);
  });
  const end = () => {
    down = false;
    stage?.classList.remove("drag");
    el.classList.remove("held");
  };
  el.addEventListener("pointerup", end);
  el.addEventListener("pointercancel", end);
};

if (stage) {
  const rays = dial ? [...dial.querySelectorAll<SVGLineElement>(".ray")] : [];
  let lit = rays.filter((r) => r.classList.contains("on")).length;

  // The monitor's picture and the dial's rays follow the slider marked for the dial.
  const monitor = (p: number, jump: boolean) => {
    const next = Math.round(p * rays.length);
    // A long jump sweeps: each ray waits a little longer than its neighbour. A drag stays immediate.
    const sweep = jump && !calm && Math.abs(next - lit) > 2;
    stage.style.setProperty("--l", String(p));
    dial?.style.setProperty("--l", String(p));
    rays.forEach((ray, i) => {
      ray.style.transitionDelay = sweep ? `${Math.abs(i - lit) * 16}ms` : "";
      ray.classList.toggle("on", i < next);
    });
    lit = next;
  };

  stage.querySelectorAll<HTMLElement>("[data-slider]").forEach((slider) => {
    const out = slider.closest(".row")?.querySelector<HTMLElement>("[data-pct]");
    if (!out) return;
    const linked = dial && slider.hasAttribute("data-dial");
    const control = bind(slider, out, linked ? monitor : undefined);
    drag(slider, fromSlider(slider), control);
    if (linked) drag(dial, fromDial(dial), control, true);
  });
}
