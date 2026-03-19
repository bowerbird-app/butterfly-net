# Importmap configuration for the ButterflyNet engine.
# These pins are merged into the host application's importmap so that the
# engine's Stimulus controllers can be loaded as ES modules.

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "butterfly_net/application", to: "butterfly_net/application.js"
pin "controllers/infinite_scroll_controller", to: "butterfly_net/controllers/infinite_scroll_controller.js"
pin "controllers/analytics_controller", to: "butterfly_net/controllers/analytics_controller.js"
