import { application } from "controllers/application"
import { eagerLoadControllersFrom, lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)

// Lazy load FlatPack controllers on first use.
lazyLoadControllersFrom("controllers", application)
