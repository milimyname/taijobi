import { LS_THEME } from "./config";

export type Theme = "light" | "dark" | "system";

function getStored(): Theme {
  if (typeof localStorage === "undefined") return "system";
  const v = localStorage.getItem(LS_THEME);
  if (v === "light" || v === "dark") return v;
  return "system";
}

function shouldBeDark(theme: Theme): boolean {
  if (theme === "dark") return true;
  if (theme === "light") return false;
  return typeof matchMedia !== "undefined" && matchMedia("(prefers-color-scheme: dark)").matches;
}

function apply(dark: boolean): void {
  if (typeof document === "undefined") return;
  document.documentElement.classList.toggle("dark", dark);
}

let current = $state<Theme>(getStored());

export const themeStore = {
  get theme() {
    return current;
  },

  get isDark() {
    return shouldBeDark(current);
  },

  set(t: Theme) {
    current = t;
    if (t === "system") {
      localStorage.removeItem(LS_THEME);
    } else {
      localStorage.setItem(LS_THEME, t);
    }
    apply(shouldBeDark(t));
  },

  init() {
    apply(shouldBeDark(current));

    if (typeof matchMedia !== "undefined") {
      matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
        if (current === "system") apply(shouldBeDark("system"));
      });
    }
  },
};
