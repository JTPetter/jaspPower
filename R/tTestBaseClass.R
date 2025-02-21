tTestBaseClass <- R6::R6Class(
  "tTestBaseClass",
  inherit = basicShimClass,
  private = list(
    .check = function () {
      alternative <- self$options$alt
      d <- self$options$es
      # Check whether the provided effect size is valid
      if (alternative == "two.sided") {
        if (d == 0) {
          stop(gettext("Effect size d can't be 0 with a two-sided alternative hypothesis."))
        }
      } else if (alternative == "less") {
        if (d >= 0) {
          stop(gettext("Effect size d has to be lower than 0 with an alternative hypothesis of lesser."))
        }
      } else if (alternative == "greater") {
        if (d <= 0) {
          stop(gettext("Effect size d has to be greater than 0 with an alternative hypothesis of greater."))
        }
      } else {
        stop(gettext("Invalid alternative."))
      }
    },
    #### Init + run functions ----
    .run = function() {

      ## Get options from interface
      n <- self$options$n
      n_ratio <- self$options$n_ratio
      pow <- self$options$power
      alt <- self$options$alt
      es <- self$options$es
      alpha <- self$options$alpha

      if (pow >= 1) stop(gettext("Power must be less than 1."))

      stats <- list(
        # Independentend samples
        n1 = n,
        n2 = ceiling(n_ratio * n),
        # Rest
        n = n,
        # Shared
        n_ratio = n_ratio,
        pow = pow,
        alt = alt,
        es = es,
        alpha = alpha
      )

      ## Compute results
      results <- private$.compute(stats)

      private$.initPowerTab(results)

      if (self$options$text) {
        private$.initPowerESTab(results, stats)
      }

      ## Populate tables and plots
      if (self$options$text) {
        private$.populateIntro()
      }

      if (self$options$powerContour) {
        private$.preparePowerContour(results, stats)
        if (self$options$text) {
          private$.populateContourText(results, stats)
        }
      }
      if (self$options$powerCurveES) {
        private$.preparePowerCurveES(results, stats)
        if (self$options$text) {
          private$.populatePowerCurveESText(results, stats)
        }
      }
      if (self$options$powerCurveN) {
        private$.preparePowerCurveN(results, stats)
        if (self$options$text) {
          private$.populatePowerCurveNText(results, stats)
        }
      }
      if (self$options$powerDist) {
        private$.preparePowerDist(results, stats)
        if (self$options$text) {
          private$.populateDistText(results, stats)
        }
      }
    },

    # ==== Functions to Populate Text ====
    .populateIntro = function() {
      calc <- self$options$calc

      html <- self$jaspResults[["intro"]]
      if (is.null(html)) {
        html <- createJaspHtml(title = "Introduction")
        html$dependOn(c("test", "text"))
        html$position <- 1
        self$jaspResults[["intro"]] <- html
      }

      str <- gettext(
        "The purpose of a <i>power analysis</i> is to evaluate the sensitivity of a design and test. "
      )

      test_names <- c(
        ttest_independent = gettext("an indipendent samples"),
        ttest_paired = gettext("a paired samples"),
        ttest_onesample = gettext("a one sample)")
      )
      test_sentence_end <- gettextf(
        "when using <i>%s</i> t-test.", test_names[[self$options$test]]
      )

      if (calc == "n") {
        mid_sentence <- gettextf(
          "You have chosen to calculate the minimum sample size needed to have an experiment sensitive enough to consistently detect the specified hypothetical effect size"
        )
      } else if (calc == "es") {
        mid_sentence <- gettextf(
          "You have chosen to calculate the minimum hypothetical effect size for which the chosen design will have the specified sensitivity"
        )
      } else if (calc == "power") {
        mid_sentence <- gettextf(
          "You have chosen to calculate the sensitivity of the chosen design for detecting the specified effect size"
        )
      }
      str <- paste0(
        str,
        mid_sentence,
        test_sentence_end
      )

      html[["text"]] <- str
    },

    # ==== Plotting Functions ====
    .powerContour = function(state, ggtheme, ...) {
      calc <- self$options$calc

      z.delta <- state$z.delta
      z.pwr <- state$z.pwr
      ps <- state$ps
      pow <- state$pow
      n <- state$n
      n1 <- state$n1
      n2 <- state$n2
      alpha <- state$alpha
      dd <- state$dd
      nn <- state$nn
      ps <- state$ps
      delta <- state$delta
      n_ratio <- state$n_ratio

      if (is.null(n_ratio)) {
        # Use ratio of 1 for one or paired samples
        n_ratio <- 1
      }

      if (is.null(n)) {
        # Add n for indipendent samples
        n <- n1
      }

      # If group sizes differ, provide a secondary axis
      secondary_axis <- ggplot2::waiver()
      if (n_ratio != 1) {
        secondary_axis <- ggplot2::sec_axis(
          ~ . * n_ratio,
          name = gettext("Sample size (group 2)")
        )
      }

      # Checking whether geom_contour_filled is availaible
      # (as it is e.g. not yet in the ggplot2 version of JASP 0.14.1)
      # TODO: Remove this check in the future
      if (!exists("geom_contour_filled", where = asNamespace("ggplot2"), mode = "function")) {
        return(
          ggplot2::ggplot() +
            ggplot2::labs(title = "ERROR: The power contour plot needs a newer version of ggplot / JASP to function")
        )
      }

      # Dirty fix for a bug where ggplot is unable to properly bin values of 1...
      z.pwr[z.pwr == 1] <- 0.999999999

      p <- ggplot2::ggplot(
        transformContourMatrix(x = nn, y = dd, z = z.pwr),
        ggplot2::aes(x = x, y = y, z = z)
      ) +
        ggplot2::geom_contour_filled(breaks = pretty(c(0, 1), n = ps$pow.n.levels), alpha = ps$background.alpha) +
        ggplot2::scale_x_log10(sec.axis = secondary_axis) +
        ggplot2::labs(
          x = gettext("Sample size (group 1)"),
          y = gettextf("Hypothetical effect size (%s)", "\u03B4"),
          fill = gettext("Power")
        ) +
        ggplot2::guides(fill = ggplot2::guide_colorsteps(barheight = ggplot2::unit(7, "cm"))) +
        # Highlight boundary of power
        # Note: This doesn't render quite perfectly right now
        # ggplot2::scale_y_continuous(limits = c(min(dd), max(dd))) +
        # ggplot2::annotate("line", x = nn, y = z.delta) +
        # Highlight N on axis
        .segment(
          x = n, y = delta, xend = n, yend = min(dd)
        ) +
        # Highlight effect size on axis
        .segment(
          x = n, y = delta, xend = min(nn), yend = delta
        ) +
        # Add point highlighting intersection
        ggplot2::annotate("point", x = n, y = delta, size = 3) +
        ggtheme

      return(p)
    },
    .powerCurveES = function(state, ggtheme, ...) {
      y <- state$y
      cols <- state$cols
      yrect <- state$yrect
      pow <- state$pow
      n1 <- state$n1
      n2 <- state$n2
      n <- state$n
      alpha <- state$alpha
      dd <- state$dd
      delta <- state$delta

      ps <- ttestPlotSettings

      if (is.null(n2)) {
        # Paired or one sample
        plot_subtitle <- substitute(
          paste(N == n, ", ", alpha == a),
          list(a = alpha, n = n)
        )
      } else {
        # Indipendent Samples
        plot_subtitle <- substitute(
          paste(N[1] == n1, ", ", N[2] == n2, ", ", alpha == a),
          list(a = alpha, n1 = n1, n2 = n2)
        )
      }

      p <- ggplot2::ggplot(data.frame(), ggplot2::aes(x = dd, y = y))

      # Add shaded background
      for (i in 1:ps$pow.n.levels) {
        p <- p +
          ggplot2::annotate(geom = "rect", xmin = min(dd), ymin = yrect[i], xmax = max(dd), ymax = yrect[i + 1], fill = cols[i])
      }

      p <- p +
        ggplot2::geom_line(size = 1.5) +
        ggplot2::labs(
          x = gettextf("Hypothetical effect size (%s)", "\u03B4"),
          y = gettext("Power"),
          subtitle = plot_subtitle
        ) +
        .segment(
          x = delta, y = pow,
          xend = delta, yend = 0
        ) +
        .segment(
          x = min(dd), y = pow,
          xend = delta, yend = pow,
        ) +
        ggtheme

      return(p)
    },
    .powerCurveN = function(state, ggtheme, ...) {
      cols <- state$cols
      yrect <- state$yrect
      lims <- state$lims
      delta <- state$delta
      alpha <- state$alpha
      n_ratio <- state$n_ratio
      nn <- state$nn
      pow <- state$pow
      n <- state$n
      y <- state$y

      ps <- ttestPlotSettings

      if (is.null(n_ratio)) {
        # Paired or one sample
        plot_subtitle <- substitute(
          paste(delta == d, ", ", alpha == a),
          list(a = alpha, d = round(delta, 3))
        )
      } else {
        # Indipendent Samples
        plot_subtitle <- substitute(
          paste(delta == d, ", ", N[2] == nr %*% N[1], ", ", alpha == a),
          list(a = alpha, nr = n_ratio, d = round(delta, 3))
        )
      }

      # Creat basic plot
      p <- ggplot2::ggplot(data.frame(), ggplot2::aes(x = nn, y = y))

      # Add shaded background
      for (i in 1:ps$pow.n.levels) {
        p <- p +
          ggplot2::annotate(geom = "rect", xmin = lims$xlim[1], ymin = yrect[i], xmax = lims$xlim[2], ymax = yrect[i + 1], fill = cols[i])
      }

      # Add main plot
      p <- p +
        ggplot2::geom_line(size = 1.5) +
        ggplot2::scale_x_log10(limits = lims$xlim) +
        ggplot2::scale_y_continuous(limits = lims$ylim) +
        ggplot2::labs(
          x = gettext("Sample size (group 1)"),
          y = gettext("Power"),
          subtitle = plot_subtitle
        ) +
        .segment(
          x = n, y = pow,
          xend = n, yend = 0
        ) +
        .segment(
          x = min(nn), y = pow,
          xend = n, yend = pow,
        ) +
        ggtheme

      return(p)
    },
    .powerDist = function(state, ggtheme, ...) {
      ps <- ttestPlotSettings

      if (is.null(state)) {
        return(FALSE)
      }

      curves <- state$curves
      rect <- state$rect
      lims <- state$lims
      alt <- self$options$alt

      themeSpec <- ggplot2::theme(
        axis.text.y = ggplot2::element_blank(),
        axis.ticks.y = ggplot2::element_blank(),
        legend.position = "none"
      )

      p <- ggplot2::ggplot() +
        ggplot2::geom_ribbon(data = curves, ggplot2::aes(x = x, ymin = ymin, ymax = ymax, fill = group), color = "#333333", alpha = .6) +
        ggplot2::geom_rect(data = rect, ggplot2::aes(xmin = x1, xmax = x2, ymin = y1, ymax = y2), fill = "white", alpha = 0.4) +
        ggplot2::geom_vline(data = rect, ggplot2::aes(xintercept = x1), linetype = "dashed") +
        ggplot2::geom_vline(data = rect, ggplot2::aes(xintercept = x2), linetype = "dashed") +
        ggplot2::coord_cartesian(xlim = lims$xlim, ylim = lims$ylim, expand = FALSE) +
        ggplot2::labs(x = gettext("Observed standardized effect size (d)"), y = gettext("Probability Density")) +
        ggtheme +
        themeSpec +
        ggplot2::scale_fill_manual(values = ps$pal(5)[c(4, 1)])

      return(p)
    }
  )
)