// The replica's three switches. Each flips its own state, worded as the app words it: a switch that follows a
// schedule reads "Until Tomorrow" once it is changed by hand, and one without a schedule reads plain On or Off.
// The stage carries each state, and the stylesheet does the rest: Dark Mode turns the monitor and the panel light
// or dark, Night Shift warms the monitor's picture, and True Tone leaves it alone, because only the built-in display
// has True Tone. Dark Mode cross-fades, as macOS does, through a snapshot. Without this script the switches show
// their first state and stay disabled.
const stage = document.querySelector<HTMLElement>("[data-console]");
const calm = matchMedia("(prefers-reduced-motion: reduce)");
const doc = document as Document & { startViewTransition?: (update: () => void) => unknown };

const flip = (stage: HTMLElement, button: HTMLButtonElement) => {
  const mode = button.dataset.mode ?? "";
  const state = button.querySelector<HTMLElement>("[data-state]");
  const scheduled = button.dataset.until !== undefined;
  button.disabled = false;
  button.addEventListener("click", () => {
    const on = button.getAttribute("aria-pressed") !== "true";
    const apply = () => {
      button.setAttribute("aria-pressed", String(on));
      stage.dataset[mode] = on ? "on" : "off";
      if (!state) return;
      // The line breaks after "Until", as Control Center breaks it.
      const word = on ? "On" : "Off";
      const lines = scheduled ? [`${word} Until`, "Tomorrow"] : [word];
      state.replaceChildren(
        ...lines.flatMap((text, i) => {
          const line = document.createElement("span");
          line.textContent = text;
          return i ? [" ", line] : [line];
        }),
      );
    };
    if (mode === "dark" && doc.startViewTransition && !calm.matches) doc.startViewTransition(apply);
    else apply();
  });
};

if (stage) stage.querySelectorAll<HTMLButtonElement>("button[data-mode]").forEach((button) => flip(stage, button));
