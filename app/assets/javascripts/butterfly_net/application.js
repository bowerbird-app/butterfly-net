import { Application } from "@hotwired/stimulus"
import InfiniteScrollController from "controllers/infinite_scroll_controller"
import AnalyticsController from "controllers/analytics_controller"

const application = Application.start()
application.debug = false
window.Stimulus = application

application.register("infinite-scroll", InfiniteScrollController)
application.register("analytics", AnalyticsController)
