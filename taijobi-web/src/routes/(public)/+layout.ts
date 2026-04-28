// Override the root `ssr = false` so public pages (marketplace + about) get
// prerendered HTML at build time. That bakes <svelte:head> meta tags
// (incl. OG / description) into the static output so social previews and
// search engines can read them without running JS.
export const ssr = true;
export const prerender = true;
