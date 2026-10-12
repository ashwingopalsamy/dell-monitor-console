// The page is calm until you move it. The logo's rays follow how far down you are, and the island follows the
// section in view. Everything here is decoration: the document reads and works the same without it.
const logo = [...document.querySelectorAll<SVGLineElement>(".logo .ray")];
let queued = false;

const paint = () => {
  queued = false;
  const room = document.documentElement.scrollHeight - innerHeight;
  const progress = room > 0 ? Math.min(1, Math.max(0, scrollY / room)) : 0;
  const lit = Math.round(progress * logo.length);
  logo.forEach((ray, i) => ray.classList.toggle("on", i < lit));
};
const queue = () => {
  if (queued) return;
  queued = true;
  requestAnimationFrame(paint);
};

const island = document.querySelector<HTMLElement>(".island");
const hl = island?.querySelector<HTMLElement>(".hl");
const links = island ? [...island.querySelectorAll<HTMLAnchorElement>("a[data-s]")] : [];
const sections = links.map((a) => document.getElementById(a.dataset.s ?? ""));
let current: HTMLAnchorElement | undefined;
let hover: HTMLAnchorElement | undefined;

// The active section keeps its white pill. Hovering another one lays a second, softer pill over it and lights its text,
// so it is always clear which section you are in and which one a click would take you to.
const hv = island?.querySelector<HTMLElement>(".hv");
const fit = (pill: HTMLElement, a: HTMLElement) => {
  pill.style.width = `${a.offsetWidth}px`;
  pill.style.height = `${a.offsetHeight}px`;
  pill.style.transform = `translate(${a.offsetLeft}px, ${a.offsetTop}px)`;
};
const place = () => {
  if (!hl) return;
  links.forEach((l) => {
    l.classList.toggle("on", l === current);
    l.classList.toggle("hot", l === hover && l !== current);
    if (l === current) l.setAttribute("aria-current", "true");
    else l.removeAttribute("aria-current");
  });
  if (current) {
    hl.style.opacity = "1";
    fit(hl, current);
  } else {
    hl.style.opacity = "0";
  }
  if (hv) {
    if (hover && hover !== current) {
      // Start from where the active pill is when the hover pill first appears, so it slides out of it.
      if (hv.style.opacity !== "1") fit(hv, current ?? hover);
      requestAnimationFrame(() => {
        hv.style.opacity = "1";
        fit(hv, hover!);
      });
    } else {
      hv.style.opacity = "0";
    }
  }
};

const spy = () => {
  // the last section whose top has crossed 40% of the viewport
  const line = innerHeight * 0.4;
  let found: HTMLAnchorElement | undefined;
  sections.forEach((s, i) => {
    if (s && s.getBoundingClientRect().top <= line) found = links[i];
  });
  if (found !== current) {
    current = found;
    place();
  }
};

addEventListener(
  "scroll",
  () => {
    queue();
    spy();
  },
  { passive: true },
);
links.forEach((a) => {
  a.addEventListener("pointerenter", () => {
    hover = a;
    place();
  });
  a.addEventListener("focus", () => {
    hover = a;
    place();
  });
  a.addEventListener("pointerleave", () => {
    hover = undefined;
    place();
  });
  a.addEventListener("blur", () => {
    hover = undefined;
    place();
  });
});
addEventListener("resize", () => {
  place();
  queue();
});
document.fonts?.ready.then(place);
// open the FAQ entry a link points at
const target = location.hash ? document.getElementById(location.hash.slice(1)) : null;
if (target instanceof HTMLDetailsElement) target.open = true;
spy();
paint();

// Copy buttons: the icon turns into a check for a moment, and the label (or the accessible name) says so.
document.querySelectorAll<HTMLButtonElement>("[data-copy]").forEach((button) => {
  const label = button.querySelector<HTMLElement>("[data-label]");
  const idle = label?.textContent ?? "";
  const name = button.getAttribute("aria-label") ?? "";
  let timer: number | undefined;
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy ?? "");
    } catch {
      return; // the commands are shown in the Install section
    }
    button.classList.add("done");
    if (label) label.textContent = "Copied";
    else button.setAttribute("aria-label", "Copied");
    clearTimeout(timer);
    timer = window.setTimeout(() => {
      button.classList.remove("done");
      if (label) label.textContent = idle;
      else button.setAttribute("aria-label", name);
    }, 1600);
  });
});
