# Originally based on https://github.com/richarddmorey/jpower

ttestISClass <- R6::R6Class(
  "ttestISClass",
  inherit = tTestBaseClass,
  private = list(
    # Functions are called from .run in the parent class

    #### Compute results ----
    .compute = function(stats) {


      ## Compute numbers for table
      pow.n <- try(ceiling(pwr.t2n.ratio(n_ratio = stats$n_ratio, d = stats$es, sig.level = stats$alpha, power = stats$pow, alternative = stats$alt)), silent = TRUE)
      pow.es <- try(pwr.t2n.test(n1 = stats$n1, n2 = stats$n2, power = stats$pow, sig.level = stats$alpha, alternative = stats$alt)$d, silent = TRUE)
      pow.pow <- try(pwr.t2n.test(n1 = stats$n1, n2 = stats$n2, d = stats$es, sig.level = stats$alpha, alternative = stats$alt)$power, silent = TRUE)
      #            pow.alpha = try(pwr.t2n.test(n1 = stats$n1, n2 = stats$n2, d = stats$es, sig.level = NULL, power = stats$pow, alternative = stats$alt)$sig.level, silent=TRUE)

      #            if (class(pow.alpha) == 'try-error')
      #                pow.alpha <- 0

      d50 <- pwr.t2n.test(
        n1 = stats$n1,
        n2 = stats$n2,
        sig.level = stats$alpha,
        power = .5, alternative = stats$alt
      )$d

      return(list(n1 = pow.n, n2 = ceiling(pow.n * stats$n_ratio), es = pow.es, power = pow.pow, d50 = d50))
    },

    #### Init table ----
    .initPowerTab = function(results) {
      table <- self$jaspResults[["powertab"]]

      if (is.null(table)) {
        # Create table if it doesn't exist yet
        table <- createJaspTable(title = gettext("A Priori Power Analysis"))
        table$dependOn(c(
          "test",
          "es",
          "power",
          "n",
          "alt",
          "alpha",
          "calc",
          "n_ratio"
        ))
        table$position <- 2
        self$jaspResults[["powertab"]] <- table
      } else {
        return()
      }

      calc <- self$options$calc

      if (calc == "n") {
        order <- c(1, 2, 3, 4, 5)
      } else if (calc == "es") {
        order <- c(3, 1, 2, 4, 5)
      } else if (calc == "power") {
        order <- c(4, 1, 2, 3, 5)
      } else {
        order <- c(5, 1, 2, 3, 4)
      }

      colNames <- c("n1", "n2", "es", "power", "alpha", "d50")
      colLabels <- c(
        "N\u2081",
        "N\u2082",
        gettext("Effect Size"),
        gettext("Power"),
        "\u03B1",
        gettext("ES for design<br/>to have 50% power")
      )
      colType <- c("integer", "integer", "number", "number", "number", "number")

      for (i in seq_along(order)) {
        table$addColumnInfo(colNames[order[i]],
          title = colLabels[order[i]],
          overtitle = if (calc == "n" && i > 2 || calc != "n" && i > 1) "User Defined" else NULL,
          type = colType[order[i]]
        )
      }

      row <- list()
      for (i in 2:5) {
        row[[colNames[order[i]]]] <- self$options[[colNames[order[i]]]]
      }

      if (self$options$calc != "n") {
        row[["n1"]] <- self$options[["n"]]
        row[["n2"]] <- ceiling(self$options[["n"]] * self$options[["n_ratio"]])
      }

      table$addRows(rowNames = 1, row)

      private$.populatePowerTab(results)
    },
    .initPowerESTab = function(results, stats) {
      table <- self$jaspResults[["powerEStab"]]

      if (is.null(table)) {
        # Create table if it doesn't exist yet
        table <- createJaspTable(title = gettext("Power by Effect Size"))
        table$dependOn(c(
          "test",
          "es",
          "power",
          "n",
          "alt",
          "alpha",
          "calc",
          "n_ratio",
          "text"
        ))
        table$position <- 4
        self$jaspResults[["powerEStab"]] <- table
      } else {
        return()
      }

      table$addColumnInfo(
        name = "es",
        title = gettext("True effect size"),
        type = "string"
      )
      table$addColumnInfo(
        name = "power",
        title = gettext("Power to detect"),
        type = "string"
      )
      table$addColumnInfo(
        name = "desc",
        title = gettext("Description"),
        type = "string"
      )

      pow <- c("\u226450%", "50% \u2013 80%", "80% \u2013 95%", "\u226595%")
      desc <- c(
        gettext("Likely miss"),
        gettext("Good chance of missing"),
        gettext("Probably detect"),
        gettext("Almost surely detect")
      )

      for (i in 1:4) {
        row <- list("power" = pow[i], "desc" = desc[i])
        table$addRows(rowNames = i, row)
      }

      private$.populatePowerESTab(results, stats)
    },
    .populatePowerESTab = function(r, lst) {
      html <- self$jaspResults[["tabText"]]
      if (is.null(html)) {
        html <- createJaspHtml()
        html$dependOn(c("test", "text"))
        html$position <- 3
        self$jaspResults[["tabText"]] <- html
      }

      # This table is created in init
      table <- self$jaspResults[["powerEStab"]]

      ## Get options from interface
      calc <- self$options$calc
      n_ratio <- lst$n_ratio
      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      n_text <- ifelse(n1 == n2,
        gettextf("a sample size of %s in each group ", n1),
        gettextf("group sample sizes of %s and %s respectively, ", n1, n2)
      )
      tail_text <- ifelse(alt == "two.sided",
        "two-sided",
        "one-sided"
      )

      print("===> pre-calc")
      probs <- c(.5, .8, .95)
      probs_es <- sapply(probs, function(p) {
        pwr.t2n.test(
          n1 = n1, n2 = n2,
          sig.level = alpha, power = p,
          alternative = alt
        )$d
      })
      print("===> post-calc")
      print(probs_es)

      if (calc == "n") {
        str <- gettextf(
          "We would need %s to reliably (with probability greater than %s) detect an effect size of <i>%s%s</i>%s, assuming a %s criterion for detection that allows for a maximum Type I error rate of <i>α=</i>%s.",
          n_text, power, "\u03B4", "\u2265", d, tail_text, alpha
        )
      } else if (calc == "es") {
        str <- gettextf(
          "A design with %s will reliably (with probability greater than %s) detect effect sizes of <i>%s%s</i>%s, assuming a %s criterion for detection that allows for a maximum Type I error rate of <i>α=</i>%s.",
          n_text, power, "\u03B4", "\u2265", round(d, 3), tail_text, alpha
        )
      } else if (calc == "power") {
        str <- gettextf(
          "A design with %s can detect effect sizes of %s<i>%s%s</i>%s with a probability of at least %s, assuming a %s criterion for detection that allows for a maximum Type I error rate of <i>α=</i>%s.",
          n_text, d, "\u03B4", "\u2265", round(power, 3), tail_text, alpha
        )
      }

      hypo_text <- ifelse(alt == "two.sided",
        "|<i>\u03B4</i>|><i>0</i>",
        "<i>\u03B4>0</i>"
      )

      str <- paste0(
        str,
        gettextf(
          "<p>To evaluate the design specified in the table, we can consider how sensitive it is to true effects of increasing sizes; that is, are we likely to correctly conclude that %s when the effect size is large enough to care about?",
          hypo_text
        )
      )

      html[["text"]] <- str

      esText <- c(
        gettextf("0 < %s %s  %s", "\u03B4", "\u2264", format(round(probs_es[1], 3), nsmall = 3)),
        gettextf("%s < %s %s %s", format(round(probs_es[1], 3), nsmall = 3), "\u03B4", "\u2264", format(round(probs_es[2], 3), nsmall = 3)),
        gettextf("%s < %s %s %s",format(round(probs_es[2], 3), nsmall = 3), "\u03B4", "\u2264", format(round(probs_es[3], 3), nsmall = 3)),
        gettextf("%s %s %s", "\u03B4", "\u2265", format(round(probs_es[3], 3), nsmall = 3))
      )

      cols <- list("es" = esText)
      table$addColumns(cols)
    },
    #### Populate table ----
    .populatePowerTab = function(results) {
      table <- self$jaspResults[["powertab"]]

      calc <- self$options$calc

      # Note: It is unclear what this value actualyl corresponds to
      # row[["d50"]] <- results[["d50"]]

      if (calc == "n") {
        table$addColumns(list(n1 = results[["n1"]]))
        table$addColumns(list(n2 = results[["n2"]]))
      } else {
        row <- list()
        row[[calc]] <- results[[calc]]
        table$addColumns(row)
      }
    },

    #### Plot functions ----
    .preparePowerContour = function(r, lst) {
      image <- self$jaspResults[["powerContour"]]
      if (is.null(image)) {
        image <- createJaspPlot(
          title = gettext("Power Contour"),
          width=400,
          height=350
        )
        image$dependOn(c(
          "test",
          "es",
          "power",
          "n",
          "alt",
          "alpha",
          "calc",
          "n_ratio",
          "powerContour"
        ))
        image$position <- 5
        self$jaspResults[["powerContour"]] <- image
      }

      ps <- ttestPlotSettings

      calc <- self$options$calc

      n_ratio <- lst$n_ratio
      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt


      maxn <- pwr.t2n.ratio(
        n_ratio = n_ratio,
        power = max(0.9, power),
        d = d,
        sig.level = alpha,
        alternative = alt
      )

      if (n1 > maxn && n1 >= ps$maxn) {
        maxn <- ceiling(n1 * ps$max.scale)
      } else if (maxn < ps$maxn) {
        maxn <- ps$maxn
      }


      minn <- ifelse(n_ratio < 1,
        max(ceiling(3 / (1 + n_ratio)), 2 / n_ratio),
        max(ceiling(3 / (1 + n_ratio)), 2 * n_ratio)
      )

      nn <- unique(ceiling(exp(seq(log(minn), log(maxn), len = ps$lens)) - .001))
      dd <- seq(ps$mind, ps$maxd, len = ps$lens)
      nn2 <- ceiling(n_ratio * nn)

      z.pwr <- sapply(dd, function(delta) {
        pwr.t2n.test(nn, nn2,
          d = delta,
          sig.level = alpha,
          alternative = alt
        )$power
      })

      z.delta <- sapply(nn, function(N) {
        n2 <- ceiling(n_ratio * N)
        pwr.t2n.test(N, n2,
          sig.level = alpha,
          power = power,
          alternative = alt
        )$d
      })

      state = list(
        z.pwr = z.pwr,
        z.delta = z.delta,
        ps = ps,
        nn = nn,
        dd = dd,
        n1 = n1,
        n_ratio = n_ratio,
        delta = d,
        alpha = alpha,
        minn = minn,
        maxn = maxn
      )
      image$plotObject <- private$.powerContour(state = state, ggtheme = pwr_plot_theme())
    },
    .populateContourText = function(r, lst) {
      html <- self$jaspResults[["contourText"]]
      if (is.null(html)) {
        html <- createJaspHtml()
        html$dependOn(c("test", "text", "powerContour"))
        html$position <- 6
        self$jaspResults[["contourText"]] <- html
      }

      ## Get options from interface
      calc <- self$options$calc
      n_ratio <- lst$n_ratio
      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      str <- gettextf(
        "<p>The power contour plot shows how the sensitivity of the test changes with the hypothetical effect size and the sample sizes in the design. As we increase the sample sizes, smaller effect sizes become reliably detectable.<p>Conversely, if one is satisfied to reliably detect only larger effect sizes, smaller sample sizes are needed. The solid black curve on the contour plot shows sample size/effect size combinationswith a power of %s. The point shows the specified  design and effect size.",
        round(power, 3)
      )

      html[["text"]] <- str
    },
    .preparePowerCurveES = function(r, lst) {
      image <- self$jaspResults[["powerCurveES"]]
      if (is.null(image)) {
        image <- createJaspPlot(
          title = gettext("Power Curve by Effect Size"),
          width = 400,
          height = 350
        )
        image$dependOn(c(
          "test",
          "es",
          "power",
          "n",
          "alt",
          "alpha",
          "calc",
          "n_ratio",
          "powerCurveES"
        ))
        image$position <- 7
        self$jaspResults[["powerCurveES"]] <- image
      }

      ps <- ttestPlotSettings

      calc <- self$options$calc

      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      dd <- seq(ps$mind, ps$maxd, len = ps$curve.n)

      y <- pwr.t2n.test(n1 = n1, n2 = n2, d = dd, sig.level = alpha, alternative = alt)$power
      cols <- ps$pal(ps$pow.n.levels)
      yrect <- seq(0, 1, 1 / ps$pow.n.levels)

      state = list(cols = cols, dd = dd, y = y, yrect = yrect, n1 = n1, n2 = n2, alpha = alpha, delta = d, pow = power)
      image$plotObject <- private$.powerCurveES(state = state, ggtheme = pwr_plot_theme())
    },
    .populatePowerCurveESText = function(r, lst) {
      html <- self$jaspResults[["curveESText"]]
      if (is.null(html)) {
        html <- createJaspHtml()
        html$dependOn(c("test", "text", "powerCurveES"))
        html$position <- 8
        self$jaspResults[["curveESText"]] <- html
      }

      ## Get options from interface
      calc <- self$options$calc
      n_ratio <- lst$n_ratio
      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      d <- round(d, 3)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      n_text <- ifelse(n1 == n2,
        gettextf("sample sizes of %s in each group", n1),
        gettextf("group sample sizes of %s and %s, respectively", n1, n2)
      )

      if (alt == "two.sided") {
        tail_text <- "two-sided"
        null_text <- "<i>\u03B4\u2264</i>0,"
        alt_text <- "|<i>\u03B4</i>|<i>\u003E</i>"
        crit_text <- "criteria"
      } else {
        tail_text <- "one-sided"
        null_text <- "<i>\u03B4=</i>0,"
        alt_text <- "<i>\u03B4\u003E</i>"
        crit_text <- "criterion"
      }

      if (calc == "power") {
        pwr_string <- gettextf("have power of at least %s", round(power, 3))
      } else {
        pwr_string <- gettextf("only be sufficiently sensitive (power >%s)", round(power, 3))
      }

      d50 <- pwr.t2n.test(n1 = n1, n2 = n2, sig.level = alpha, power = .5, alternative = alt)$d

      str <- gettextf(
        "<p>The power curve above shows how the sensitivity of the test and design is larger for larger effect sizes. If we obtained %s our test and design would %s to effect sizes of %s%s. <p>We would be more than likely to miss (power less than 50%%) effect sizes less than <i>%s=</i>%s.",
        n_text, pwr_string, alt_text, d, "\u03B4", round(d50, 3)
      )

      html[["text"]] <- str
    },
    .preparePowerCurveN = function(r, lst) {
      image <- self$jaspResults[["powerCurveN"]]
      if (is.null(image)) {
        image <- createJaspPlot(title="Power Curve by N", width=400, height=350)
        image$dependOn(c(
          "test",
          "es",
          "power",
          "n",
          "alt",
          "alpha",
          "calc",
          "n_ratio",
          "powerCurveN"
        ))
        image$position <- 9
        self$jaspResults[["powerCurveN"]] <- image
      }

      calc <- self$options$calc

      ps <- ttestPlotSettings

      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      n_ratio <- lst$n_ratio
      d <- ifelse(calc == "es", r$es, lst$es)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      maxn <- pwr.t2n.ratio(
        n_ratio = n_ratio,
        power = max(0.9, power),
        d = d,
        sig.level = alpha,
        alternative = alt
      )

      if (n1 > maxn && n1 >= ps$maxn) {
        maxn <- ceiling(n1 * ps$max.scale)
      } else if (maxn < ps$maxn) {
        maxn <- ps$maxn
      }


      minn <- ifelse(n_ratio < 1,
        max(ceiling(3 / (1 + n_ratio)), 2 / n_ratio),
        max(ceiling(3 / (1 + n_ratio)), 2 * n_ratio)
      )

      nn <- seq(minn, maxn)

      y <- pwr.t2n.test(
        n1 = nn,
        n2 = ceiling(nn * lst$n_ratio),
        d = d, sig.level = alpha, alternative = alt
      )$power

      cols <- ps$pal(ps$pow.n.levels)
      yrect <- seq(0, 1, 1 / ps$pow.n.levels)

      lims <- data.frame(
        xlim = c(minn, maxn),
        ylim = c(0, 1)
      )

      state = list(n = n1, cols = cols, nn = nn, y = y, yrect = yrect, lims = lims, delta = d, alpha = alpha, n_ratio = n_ratio, pow = power)
      image$plotObject <- private$.powerCurveN(state = state, ggtheme = pwr_plot_theme())
    },
    .preparePowerDist = function(r, lst) {
      image <- self$jaspResults[["powerDist"]]
      if (is.null(image)) {
        image <- createJaspPlot(title="Power Demonstration", width=400, height=300)
        image$dependOn(c(
          "test",
          "es",
          "power",
          "n",
          "alt",
          "alpha",
          "calc",
          "n_ratio",
          "powerDist"
        ))
        image$position <- 11
        self$jaspResults[["powerDist"]] <- image
      }

      calc <- self$options$calc

      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      effN <- n1 * n2 / (n1 + n2)
      df <- n1 + n2 - 2
      ncp <- sqrt(effN) * d

      if (alt == "two.sided") {
        crit <- qt(p = 1 - alpha / 2, df = df) / sqrt(effN)
      } else {
        crit <- qt(p = 1 - alpha, df = df) / sqrt(effN)
      }

      if (lst$es > 0) {
        xlims <- c(qt(.001, df), qt(.999, df, ncp)) / sqrt(effN)
      } else {
        xlims <- c(qt(.001, df, ncp), qt(.999, df)) / sqrt(effN)
      }

      y.max <- dt(0, df) / sqrt(effN)

      xx <- seq(xlims[1], xlims[2], len = 100)
      yy.null <- dt(xx * sqrt(effN), df) / sqrt(effN)
      yy.alt <- dt(xx * sqrt(effN), df, ncp) / sqrt(effN)

      curves <- data.frame(
        x = rep(xx, 2),
        ymin = rep(0, length(xx) * 2),
        ymax = c(yy.null, yy.alt),
        group = rep(c("Null", "Alt"), each = length(xx))
      )

      if (alt == "two.sided") {
        rect <- data.frame(
          x1 = -crit, x2 = crit,
          y1 = 0, y2 = y.max * 1.1
        )
      } else {
        rect <- data.frame(
          x1 = xlims[1] - 1, x2 = crit,
          y1 = 0, y2 = y.max * 1.1
        )
      }

      lims <- data.frame(
        xlim = c(xlims[1], xlims[2]),
        ylim = c(0, y.max * 1.1)
      )

      state = list(curves = curves, rect = rect, lims = lims)
      image$plotObject <- private$.powerDist(state = state, ggtheme = pwr_plot_theme())
    },
    .populatePowerCurveNText = function(r, lst) {
      html <- self$jaspResults[["curveNText"]]
      if (is.null(html)) {
        html <- createJaspHtml()
        html$dependOn(c("test", "text", "powerCurveN"))
        html$position <- 10
        self$jaspResults[["curveNText"]] <- html
      }

      ## Get options from interface
      calc <- self$options$calc
      n_ratio <- lst$n_ratio
      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      d <- round(d, 3)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      n_text <- ifelse(n1 == n2,
        gettextf("sample sizes of at least %s in each group", n1),
        gettextf("group sample sizes of at least %s and %s, respectively", n1, n2)
      )

      if (alt == "two.sided") {
        tail_text <- "two-sided"
        null_text <- "<i>\u03B4\u2264</i>0,"
        alt_text <- "|<i>\u03B4</i>|<i>\u003E</i>0,"
        crit_text <- "criteria"
      } else {
        tail_text <- "one-sided"
        null_text <- "<i>\u03B4=</i>0,"
        alt_text <- "<i>\u03B4\u2260</i>0,"
        crit_text <- "criterion"
      }

      str <- gettextf(
        "<p>The power curve above shows how the sensitivity of the test and design is larger for larger effect sizes. In order for our test and design to have sufficient sensitivity (power > %s) to detect that %s when the effect size is %s or larger, we would need %s.",
        round(power, 3), alt_text, d, n_text
      )

      html[["text"]] <- str
    },
    .populateDistText = function(r, lst) {
      html <- self$jaspResults[["distText"]]
      if (is.null(html)) {
        html <- createJaspHtml()
        html$dependOn(c("test", "text", "powerDist"))
        html$position <- 12
        self$jaspResults[["distText"]] <- html
      }

      ## Get options from interface
      calc <- self$options$calc
      n_ratio <- lst$n_ratio
      n1 <- ifelse(calc == "n", r$n1, lst$n1)
      n2 <- ifelse(calc == "n", r$n2, lst$n2)
      d <- ifelse(calc == "es", r$es, lst$es)
      d <- round(d, 2)
      power <- ifelse(calc == "power", r$power, lst$pow)
      alpha <- ifelse(calc == "alpha", r$alpha, lst$alpha)
      alt <- lst$alt

      n_text <- ifelse(n1 == n2,
        gettextf("a sample size of %s in each group", n1),
        gettextf("group sample sizes of %s and %s, respectively", n1, n2)
      )

      if (alt == "two.sided") {
        tail_text <- gettext("two-sided")
        null_text <- "<i>\u03B4=</i>0,"
        alt_text <- "|<i>\u03B4</i>|<i>\u2265</i>"
        crit_text <- gettext("criteria")
      } else {
        tail_text <- gettext("one-sided")
        null_text <- "<i>\u03B4\u2264</i>0,"
        alt_text <- "<i>\u03B4\u2265</i"
        crit_text <- gettext("criterion")
      }

      str <- paste(
        "<p>",
        gettextf("The figure above shows two sampling distributions: the sampling distribution of the <i>estimated</i> effect size when <i>%s=</i>0 (left), and when <i>%s=</i>%s (right).", "\u03B4", "\u03B4", d),
        gettextf("Both assume %s.", n_text),
        "</p><p>",
        gettextf("The vertical dashed lines show the %s we would set for a %s test with <i>α=</i>%s.", crit_text, tail_text, alpha),
        gettextf("When the observed effect size is far enough away from 0 to be more extreme than the %s we say we 'reject' the null hypothesis.", crit_text),
        gettextf("If the null hypothesis were true and %s the evidence would lead us to wrongly reject the null hypothesis at most %s%% of the time.", null_text, 100 * alpha),
        "</p><p>",
        gettextf("On the other hand, if <i>%s%s</i>%s, the evidence would exceed the criterion  &mdash; and hence we would correctly claim that <i>%s%s</i>0 &mdash; at least %s%% of the time.", "\u03B4", "\u2265", d, "\u03B4", "\u2265", 100 * round(power, 3)),
        gettextf("The design's power for detecting effects of %s%s is thus %s.", alt_text, d, round(power, 3)),
        "</p>"
      )


      html[["text"]] <- str
    }
  )
)