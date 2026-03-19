# Importmap configuration for the ButterflyNet engine.
# These pins are merged into the host application's importmap so that the
# engine's Stimulus controllers can be loaded as ES modules.

# Vendored Stimulus files so this engine works regardless of whether the host
# app has stimulus-rails' asset path in the Propshaft/Sprockets load path.
pin "@hotwired/stimulus", to: "butterfly_net/vendor/stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "butterfly_net/vendor/stimulus-loading.js"
pin "butterfly_net/application", to: "butterfly_net/application.js"
pin "controllers/infinite_scroll_controller", to: "butterfly_net/controllers/infinite_scroll_controller.js"
pin "controllers/analytics_controller", to: "butterfly_net/controllers/analytics_controller.js"

# Pin FlatPack controllers without modulepreload for lazy loading
pin_all_from FlatPack::Engine.root.join("app/javascript/flat_pack/controllers"),
             under: "controllers/flat_pack",
             to: "flat_pack/controllers",
             preload: false

# Pin FlatPack TipTap helpers
pin_all_from FlatPack::Engine.root.join("app/javascript/flat_pack/tiptap"),
             under: "flat_pack/tiptap",
             to: "flat_pack/tiptap",
             preload: false

# Heroicons curated subset — used by FlatPack::Icon::Component
pin "flat_pack/heroicons", to: "flat_pack/heroicons.js", preload: false

# ── TipTap Rich Text Editor (built-in FlatPack support) ──────────────────────
# Packages pinned from esm.sh at a consistent version.
# Named BUTTERFLY_NET_TIPTAP_VERSION to avoid constant clash with the FlatPack
# engine's own config/importmap.rb (which defines TIPTAP_VERSION at 2.27.x).
BUTTERFLY_NET_TIPTAP_VERSION = "2.11.5"

# Core
pin "@tiptap/core",        to: "https://esm.sh/@tiptap/core@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/starter-kit", to: "https://esm.sh/@tiptap/starter-kit@#{BUTTERFLY_NET_TIPTAP_VERSION}"

# Menus
pin "@tiptap/extension-bubble-menu",   to: "https://esm.sh/@tiptap/extension-bubble-menu@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-floating-menu", to: "https://esm.sh/@tiptap/extension-floating-menu@#{BUTTERFLY_NET_TIPTAP_VERSION}"

# Minimal preset
pin "@tiptap/extension-placeholder",     to: "https://esm.sh/@tiptap/extension-placeholder@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-character-count", to: "https://esm.sh/@tiptap/extension-character-count@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-link",            to: "https://esm.sh/@tiptap/extension-link@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-underline",       to: "https://esm.sh/@tiptap/extension-underline@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-text-align",      to: "https://esm.sh/@tiptap/extension-text-align@#{BUTTERFLY_NET_TIPTAP_VERSION}"

# Content preset
pin "@tiptap/extension-highlight",           to: "https://esm.sh/@tiptap/extension-highlight@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-text-style",          to: "https://esm.sh/@tiptap/extension-text-style@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-color",               to: "https://esm.sh/@tiptap/extension-color@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-typography",          to: "https://esm.sh/@tiptap/extension-typography@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-image",               to: "https://esm.sh/@tiptap/extension-image@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-code-block-lowlight", to: "https://esm.sh/@tiptap/extension-code-block-lowlight@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-task-list",           to: "https://esm.sh/@tiptap/extension-task-list@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-task-item",           to: "https://esm.sh/@tiptap/extension-task-item@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-table",               to: "https://esm.sh/@tiptap/extension-table@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-table-row",           to: "https://esm.sh/@tiptap/extension-table-row@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-table-cell",          to: "https://esm.sh/@tiptap/extension-table-cell@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-table-header",        to: "https://esm.sh/@tiptap/extension-table-header@#{BUTTERFLY_NET_TIPTAP_VERSION}"

# Full preset
pin "@tiptap/extension-subscript",            to: "https://esm.sh/@tiptap/extension-subscript@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-superscript",          to: "https://esm.sh/@tiptap/extension-superscript@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-font-family",          to: "https://esm.sh/@tiptap/extension-font-family@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-mention",              to: "https://esm.sh/@tiptap/extension-mention@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-youtube",              to: "https://esm.sh/@tiptap/extension-youtube@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-audio",                to: "https://esm.sh/@tiptap/extension-audio@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-details",              to: "https://esm.sh/@tiptap/extension-details@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-details-content",      to: "https://esm.sh/@tiptap/extension-details-content@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-details-summary",      to: "https://esm.sh/@tiptap/extension-details-summary@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-trailing-node",        to: "https://esm.sh/@tiptap/extension-trailing-node@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-unique-id",            to: "https://esm.sh/@tiptap/extension-unique-id@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-focus",                to: "https://esm.sh/@tiptap/extension-focus@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-list-keymap",          to: "https://esm.sh/@tiptap/extension-list-keymap@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-collaboration",        to: "https://esm.sh/@tiptap/extension-collaboration@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-collaboration-cursor", to: "https://esm.sh/@tiptap/extension-collaboration-cursor@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-drag-handle",          to: "https://esm.sh/@tiptap/extension-drag-handle@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-mathematics",          to: "https://esm.sh/@tiptap/extension-mathematics@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-emoji",                to: "https://esm.sh/@tiptap/extension-emoji@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-invisible-characters", to: "https://esm.sh/@tiptap/extension-invisible-characters@#{BUTTERFLY_NET_TIPTAP_VERSION}"
pin "@tiptap/extension-table-of-contents",    to: "https://esm.sh/@tiptap/extension-table-of-contents@#{BUTTERFLY_NET_TIPTAP_VERSION}"
