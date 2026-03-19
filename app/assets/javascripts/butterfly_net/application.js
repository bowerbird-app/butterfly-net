import { Application } from "@hotwired/stimulus"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
import InfiniteScrollController from "controllers/infinite_scroll_controller"
import AnalyticsController from "controllers/analytics_controller"

const application = Application.start()
application.debug = false
window.Stimulus = application

application.register("infinite-scroll", InfiniteScrollController)
application.register("analytics", AnalyticsController)

// Lazy load FlatPack controllers on first use
// Use the top-level controllers namespace so identifiers like
// "flat-pack--sidebar-layout" resolve to "controllers/flat_pack/sidebar_layout_controller".
lazyLoadControllersFrom("controllers", application)
