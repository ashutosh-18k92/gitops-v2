import mermaid from "mermaid";
import { icons } from "@iconify-json/logos";

/**
 * Icons are registered for mermaid diagrams
 * @see https://iconify.design/docs/icon-packs/js/
 * Pick Icons from @visit https://icones.js.org/collection/logos
 */
mermaid.registerIconPacks([
  {
    name: "logos", // This is the prefix you will use in your diagrams
    icons: icons,
  },
]);
