import { application } from "controllers/application"
import { eagerLoadControllersFrom, lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)

// Lazy load FlatPack controllers on first use.
// Must use "controllers" (not "controllers/flat_pack") so that the flat-pack--
// namespace prefix in identifiers like "flat-pack--sidebar-layout" resolves to
// the correct importmap path: controllers/flat_pack/sidebar_layout_controller.
lazyLoadControllersFrom("controllers", application)
