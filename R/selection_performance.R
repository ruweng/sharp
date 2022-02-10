#' Selection performance
#'
#' Computes different metrics of selection performance by comparing the set of
#' selected features to the set of true predictors/edges. This function can only
#' be used in simulation studies (i.e. when the true model is known).
#'
#' @inheritParams GraphicalModel
#' @param theta output from \code{VariableSelection} or \code{GraphicalModel}.
#'   Alternatively, it can be a binary matrix of selected variables (in variable
#'   selection) or a binary adjacency matrix (in graphical modelling)
#' @param theta_star output from \code{SimulateRegression} or
#'   \code{SimulateGraphical}. Alternatively, it can be a binary matrix of true
#'   predictors (in variable selection) or the true binary adjacency matrix (in
#'   graphical modelling).
#' @param cor optional correlation matrix. Only used in graphical modelling.
#' @param thr optional threshold in correlation. Only used in graphical
#'   modelling and when argument "cor" is not NULL.
#'
#' @return A matrix of selection metrics including:
#'
#'   \item{TP}{number of True Positives (TP)} \item{FN}{number of False
#'   Negatives (TN)} \item{FP}{number of False Positives (FP)} \item{TN}{number
#'   of True Negatives (TN)} \item{sensitivity}{sensitivity, i.e. TP/(TP+FN)}
#'   \item{specificity}{specificity, i.e. TN/(TN+FP)} \item{accuracy}{accuracy,
#'   i.e. (TP+TN)/(TP+TN+FP+FN)} \item{precision}{precision (p), i.e.
#'   TP/(TP+FP)} \item{recall}{recall (r), i.e. TP/(TP+FN)}
#'   \item{F1_score}{F1-score, i.e. 2*p*r/(p+r)}
#'
#'   If argument "cor" is provided, the number of False Positives among
#'   correlated (FP_c) and uncorrelated (FP_i) pairs, defined as having
#'   correlations (provided in "cor") above or below the threshold "thr", are
#'   also reported.
#'
#'   Block-specific performances are reported if "pk" is not NULL. In this case,
#'   the first row of the matrix corresponds to the overall performances, and
#'   subsequent rows correspond to each of the blocks. The order of the blocks
#'   is defined as in \code{\link{BlockStructure}}.
#'
#' @family functions for evaluation of model performance
#'
#' @examples
#' \dontrun{
#'
#' # Variable selection model
#' set.seed(1)
#' simul <- SimulateRegression(pk = 30)
#' stab <- VariableSelection(xdata = simul$xdata, ydata = simul$ydata)
#' perf <- SelectionPerformance(theta = stab, theta_star = simul)
#' perf <- SelectionPerformance(
#'   theta = SelectedVariables(stab),
#'   theta_star = simul$theta
#' ) # alternative formulation
#'
#' # Single-block graphical model
#' set.seed(1)
#' simul <- SimulateGraphical(pk = 30)
#' stab <- GraphicalModel(xdata = simul$data)
#' perf <- SelectionPerformance(theta = stab, theta_star = simul)
#' perf <- SelectionPerformance(
#'   theta = stab, theta_star = simul,
#'   cor = cor(simul$data), thr = 0.5
#' )
#' perf <- SelectionPerformance(
#'   theta = Adjacency(stab),
#'   theta_star = simul$theta
#' ) # alternative formulation
#'
#' # Multi-block graphical model
#' set.seed(1)
#' simul <- SimulateGraphical(pk = c(10, 10))
#' stab <- GraphicalModel(xdata = simul$data, pk = c(10, 10), lambda_other_blocks = rep(0, 3))
#' perf <- SelectionPerformance(theta = stab, theta_star = simul, pk = c(10, 10))
#' perf <- SelectionPerformance(
#'   theta = stab, theta_star = simul, pk = c(10, 10),
#'   cor = cor(simul$data), thr = 0.5
#' )
#' perf <- SelectionPerformance(
#'   theta = Adjacency(stab),
#'   theta_star = simul$theta,
#'   pk = c(10, 10)
#' ) # alternative formulation
#'
#' # Sparse PLS model
#' set.seed(1)
#' simul <- SimulateRegression(n = 50, pk = c(5, 5, 5), family = "gaussian")
#' stab <- BiSelection(
#'   xdata = simul$xdata, ydata = simul$ydata,
#'   family = "gaussian", ncomp = 3,
#'   LambdaX = 1:(ncol(x) - 1),
#'   LambdaY = 1:(ncol(y) - 1),
#'   implementation = SparsePLS,
#'   n_cat = 2
#' )
#' perf <- SelectionPerformance(theta = stab, theta_star = simul)
#' perf <- SelectionPerformance(
#'   theta = stab$selected,
#'   theta_star = simul$theta
#' ) # alternative formulation
#' }
#'
#' @export
SelectionPerformance <- function(theta, theta_star, pk = NULL, cor = NULL, thr = 0.5) {
  # Re-formatting input theta
  if (any(class(theta) %in% c("variable_selection", "graphical_model", "bi_selection"))) {
    if (class(theta) == "graphical_model") {
      theta <- Adjacency(theta)
    } else {
      if (class(theta) == "variable_selection") {
        theta <- SelectedVariables(theta)
        theta <- as.vector(theta)
      } else {
        theta <- theta$selected
      }
    }
  }

  # Re-formatting input theta_star
  if (any(class(theta_star) %in% c("simulation_regression", "simulation_graphical_model"))) {
    theta_star <- theta_star$theta
  }
  if (is.vector(theta)) {
    theta_star <- as.vector(theta_star)
  }

  # Storing similarities/differences between estimated and true sets
  Asum <- theta + 2 * theta_star

  # Extracting block-specific performances
  if (is.null(pk)) {
    if (is.vector(Asum)) {
      out <- SelectionPerformanceSingle(Asum, cor = cor, thr = thr)
    } else {
      if (isSymmetric(theta_star)) {
        out <- SelectionPerformanceSingle(Asum, cor = cor, thr = thr)
      } else {
        out <- NULL
        for (k in 1:ncol(Asum)) {
          out <- rbind(out, SelectionPerformanceSingle(Asum[, k], cor = cor, thr = thr))
        }
        rownames(out) <- colnames(Asum)
      }
    }
  } else {
    Asum_vect <- Asum[upper.tri(Asum)]
    bigblocks <- BlockMatrix(pk)
    bigblocks_vect <- bigblocks[upper.tri(bigblocks)]
    if (!is.null(cor)) {
      cor_vect <- cor[upper.tri(cor)]
    } else {
      cor_vect <- NULL
    }

    out <- SelectionPerformanceSingle(Asum, cor = cor, thr = thr)
    for (k in sort(unique(bigblocks_vect))) {
      tmp <- SelectionPerformanceSingle(Asum_vect[bigblocks_vect == k],
        cor = cor_vect[bigblocks_vect == k], thr = thr
      )
      out <- rbind(out, tmp)
    }
  }

  return(out)
}


#' Graph representation of selection performance
#'
#' Generates an igraph object representing the True Positive, False Positive and
#' False Negative edges by comparing the set of selected edges to the set of
#' true edges. This function only applies to graphical models and can only be
#' used in simulation studies (i.e. when the true model is known).
#'
#' @inheritParams Graph
#' @param theta binary adjacency matrix or output from \code{GraphicalModel}.
#' @param theta_star true binary adjacency matrix or output from
#'   \code{SimulateGraphical}.
#' @param colours vector of edge colours. The first entry of the vector defines
#'   the colour of False Positive edges, second entry is for True Negatives and
#'   third entry is for True Positives.
#' @param lty vector of line types for edges. The first entry of the vector
#'   defines the colour of False Positive edges, second entry is for True
#'   Negatives and third entry is for True Positives.
#' @param plot logical indicating if the generated graph should be plotted.
#' @param show_labels logical indicating if the node labels should be displayed.
#' @param filename file path to saved figure. If \code{filename=NULL}, the plot
#'   is not saved.
#' @param fileformat format of the saved figure. Possible values are
#'   \code{"pdf"} or \code{"png"}. Only used if argument \code{filename} is
#'   provided.
#' @param res resolution of the png figure (see \code{\link[grDevices]{png}}).
#'   Only used if argument \code{filename} is provided and
#'   \code{fileformat="png"}.
#' @param width width of the saved figure. Only used if argument \code{filename}
#'   is provided.
#' @param height height of the saved figure. Only used if argument
#'   \code{filename} is provided.
#' @param units units of width and height. Possible values are \code{"px"},
#'   \code{"in"}, \code{"cm"} and \code{"mm"} (see
#'   \code{\link[grDevices]{png}}). Only used if argument \code{filename} is
#'   provided and \code{fileformat="png"}.
#' @param ... additional arguments to be passed to \code{\link{Graph}}.
#'
#' @family functions for evaluation of model performance
#' @seealso \code{\link{GraphicalModel}}, \code{\link{Graph}}
#'
#' @examples
#' \dontrun{
#'
#' # Data simulation
#' set.seed(1)
#' simul <- SimulateGraphical(pk = 30)
#'
#' # Stability selection
#' stab <- GraphicalModel(xdata = simul$data, K = 10)
#'
#' # Performance graph
#' perfgraph <- SelectionPerformanceGraph(
#'   theta = stab,
#'   theta_star = simul, plot = TRUE
#' )
#'
#' # Alternative formulation
#' perfgraph <- SelectionPerformanceGraph(
#'   theta = Adjacency(stab),
#'   theta_star = simul$theta, plot = TRUE
#' )
#'
#' # User-defined colours/shapes
#' perfgraph <- SelectionPerformanceGraph(
#'   theta = stab, theta_star = simul, plot = TRUE,
#'   colours = c("forestgreen", "orange", "black"),
#'   node_colour = "red", node_shape = "star"
#' )
#' perfgraph <- SelectionPerformanceGraph(
#'   theta = stab, theta_star = simul, plot = TRUE,
#'   colours = c("forestgreen", "orange", "black"), lty = c(4, 2, 3)
#' )
#'
#' # Using and re-formatting igraph object
#' require(igraph)
#' igraph::V(perfgraph)$size <- 10
#' plot(perfgraph, layout = layout_with_kk(perfgraph))
#'
#' # Regression model
#' set.seed(1)
#' simul <- SimulateRegression(pk = 30)
#' stab <- VariableSelection(xdata = simul$xdata, ydata = simul$ydata)
#' perf <- SelectionPerformance(theta = stab, theta_star = simul)
#' perf_graph <- SelectionPerformanceGraph(theta = stab, theta_star = simul, plot = TRUE)
#'
#' # Sparse PLS model
#' set.seed(1)
#' simul <- SimulateRegression(n = 50, pk = c(5, 5, 5), family = "gaussian")
#' stab <- BiSelection(
#'   xdata = simul$xdata, ydata = simul$ydata,
#'   family = "gaussian", ncomp = 3,
#'   LambdaX = 1:(ncol(x) - 1),
#'   LambdaY = 1:(ncol(y) - 1),
#'   implementation = SparsePLS,
#'   n_cat = 2
#' )
#' perf <- SelectionPerformance(theta = stab, theta_star = simul)
#' perf_graph <- SelectionPerformanceGraph(theta = stab, theta_star = simul, plot = TRUE)
#' }
#'
#' @export
SelectionPerformanceGraph <- function(theta, theta_star,
                                      colours = c("tomato", "forestgreen", "navy"),
                                      lty = c(2, 3, 1),
                                      node_colour = NULL,
                                      plot = FALSE, show_labels = TRUE,
                                      filename = NULL, fileformat = "pdf", res = 500,
                                      width = 7, height = 7, units = "in", ...) {
  # Storing extra arguments
  extra_args <- list(...)

  # Re-formatting input theta
  if (any(class(theta) %in% c("variable_selection", "graphical_model", "bi_selection"))) {
    if (class(theta) == "variable_selection") {
      theta <- cbind(SelectedVariables(theta))
      if (is.null(node_colour)) {
        node_colour <- c(rep("skyblue", nrow(theta)), "red")
      }
      if (ncol(theta) == 1) {
        colnames(theta) <- "outcome"
      }
      theta <- Square(theta)
    } else {
      if (class(theta) == "graphical_model") {
        theta <- Adjacency(theta)
      } else {
        # Relating predictors and outcomes (ignoring latent variables)
        if (is.null(node_colour)) {
          node_colour <- c(
            rep("skyblue", nrow(theta$selected)),
            rep("red", ncol(theta$selected))
          )
        }
        theta <- Square(theta$selected)
      }
    }
  }

  # Re-formatting input theta_star
  if (any(class(theta_star) %in% c("simulation_regression", "simulation_graphical_model"))) {
    if (class(theta_star) == "simulation_regression") {
      theta_star <- cbind(theta_star$theta)
      if (ncol(theta_star) == 1) {
        colnames(theta_star) <- "outcome"
      }
      theta_star <- Square(theta_star)
    } else {
      theta_star <- theta_star$theta
    }
  }

  # Defining node colour if not done before
  if (is.null(node_colour)) {
    node_colour <- "skyblue"
  }

  # Checking input is a matrix
  if ((length(dim(theta)) != 2) | (length(dim(theta_star)) != 2)) {
    stop("Arguments 'theta' and 'theta_star' must be adjacency matrices.")
  }

  # Storing similarities/differences between estimated and true sets
  Asum <- theta + 2 * theta_star

  # Refining inputs
  names(colours) <- names(lty) <- c("FP", "TN", "TP")

  # Extracting relevant extra arguments
  tmp_extra_args <- MatchingArguments(extra_args = extra_args, FUN = focus::Graph)
  tmp_extra_args <- tmp_extra_args[!names(tmp_extra_args) %in% c("adjacency", "node_colour")]

  # Making consensus graph
  g <- Graph(adjacency = ifelse(Asum != 0, yes = 1, no = 0), node_colour = node_colour, ...)

  # Formatting vertices
  igraph::V(g)$size <- igraph::V(g)$size / 3 + 1
  if (!show_labels) {
    igraph::V(g)$label <- rep("", length(igraph::V(g)$label))
  }

  # Formatting edges
  myedgecolour <- colours[Asum[igraph::get.edgelist(g)]]
  myedgelty <- lty[Asum[igraph::get.edgelist(g)]]
  igraph::E(g)$color <- myedgecolour
  igraph::E(g)$width <- 1
  igraph::E(g)$lty <- myedgelty

  # Plotting graph
  if (plot | (!is.null(filename))) {
    if (!is.null(filename)) {
      if (fileformat == "pdf") {
        grDevices::pdf(filename, width = width, height = height)
      } else {
        grDevices::png(filename, width = width, height = height, res = res, units = units)
      }
    }
    igraph::plot.igraph(g, layout = igraph::layout_with_kk(g))
    if (!is.null(filename)) {
      grDevices::dev.off()
    }
  }

  # Returning output graph
  return(g)
}


#' Selection performance (internal)
#'
#' Computes different metrics of selection performance from a categorical
#' vector/matrix with 3 for True Positive, 2 for False Negative, 1 for False
#' Positive and 0 for True Negative.
#'
#' @inheritParams SelectionPerformance
#' @param Asum vector (in variable selection) or matrix (in graphical modelling)
#'   containing values of \code{0}, \code{1}, \code{2} or \code{3}.
#'
#' @return A matrix of selection metrics including:
#'
#'   \item{TP}{number of True Positives (TP)} \item{FN}{number of False
#'   Negatives (TN)} \item{FP}{number of False Positives (FP)} \item{TN}{number
#'   of True Negatives (TN)} \item{sensitivity}{sensitivity, i.e. TP/(TP+FN)}
#'   \item{specificity}{specificity, i.e. TN/(TN+FP)} \item{accuracy}{accuracy,
#'   i.e. (TP+TN)/(TP+TN+FP+FN)} \item{precision}{precision (p), i.e.
#'   TP/(TP+FP)} \item{recall}{recall (r), i.e. TP/(TP+FN)}
#'   \item{F1_score}{F1-score, i.e. 2*p*r/(p+r)}
#'
#'   If argument "cor" is provided, the number of False Positives among
#'   correlated (FP_c) and uncorrelated (FP_i) pairs, defined as having
#'   correlations (provided in "cor") above or below the threshold "thr", are
#'   also reported.
#'
#' @keywords internal
SelectionPerformanceSingle <- function(Asum, cor = NULL, thr = 0.5) {
  # Asum is an adjacency matrix with 3 for TP, 2 for FN, 1 for FP, and 0 for TN

  # Preparing objects
  if (is.matrix(Asum)) {
    p <- ncol(Asum)
    N <- p * (p - 1) / 2
    Asum <- Asum[upper.tri(Asum)]
  } else {
    N <- length(Asum)
  }

  # Computing the numbers of True/False Positives/Negatives
  TP <- sum(Asum == 3)
  FN <- sum(Asum == 2)
  FP <- sum(Asum == 1)
  TN <- sum(Asum == 0)

  # Separation between correlated and independent features based on a threshold in correlation
  if (!is.null(cor)) {
    if (is.matrix(cor)) {
      cor_vect <- cor[upper.tri(cor)]
    } else {
      cor_vect <- cor
    }
    FP_c <- sum((Asum == 1) & (abs(cor_vect) >= thr))
    FP_i <- sum((Asum == 1) & (abs(cor_vect) < thr))
  }

  # Computing performances in selection
  sensitivity <- TP / (TP + FN)
  specificity <- TN / (TN + FP)
  accuracy <- (TP + TN) / N
  if (TP + FP > 0) {
    precision <- TP / (TP + FP)
  } else {
    precision <- 0
  }
  if ((TP + FN) > 0) {
    recall <- TP / (TP + FN)
  } else {
    recall <- 1
  }
  if ((precision > 0) | (recall > 0)) {
    F1_score <- 2 * precision * recall / (precision + recall)
  } else {
    F1_score <- 0
  }

  if (is.null(cor)) {
    return(data.frame(
      TP = TP, FN = FN, FP = FP, TN = TN,
      sensitivity = sensitivity, specificity = specificity,
      accuracy = accuracy, precision = precision, recall = recall, F1_score = F1_score
    ))
  } else {
    return(data.frame(
      TP = TP, FN = FN, FP = FP, TN = TN, FP_c = FP_c, FP_i = FP_i,
      sensitivity = sensitivity, specificity = specificity,
      accuracy = accuracy, precision = precision, recall = recall, F1_score = F1_score
    ))
  }
}


#' Clustering performance
#'
#' Computes different metrics of clustering performance by comparing true and
#' predicted pairwise co-membership. This function can only be used in
#' simulation studies (i.e. when the true cluster membership is known).
#'
#' @inheritParams GraphicalModel
#' @param theta binary vector of selected variables (in variable selection) or
#'   binary adjacency matrix (in graphical modelling).
#' @param theta_star binary vector of true predictors (in variable selection) or
#'   true binary adjacency matrix (in graphical modelling).
#'
#' @return A matrix of selection metrics including:
#'
#'   \item{TP}{number of True Positives (TP)} \item{FN}{number of False
#'   Negatives (TN)} \item{FP}{number of False Positives (FP)} \item{TN}{number
#'   of True Negatives (TN)} \item{sensitivity}{sensitivity, i.e. TP/(TP+FN)}
#'   \item{specificity}{specificity, i.e. TN/(TN+FP)} \item{accuracy}{accuracy,
#'   i.e. (TP+TN)/(TP+TN+FP+FN)} \item{precision}{precision (p), i.e.
#'   TP/(TP+FP)} \item{recall}{recall (r), i.e. TP/(TP+FN)}
#'   \item{F1_score}{F1-score, i.e. 2*p*r/(p+r)} \item{rand}{Rand index, i.e.
#'   (TP+TN)/(TP+FP+TN+FN)}
#'
#'   Block-specific performances are reported if "pk" is not NULL. In this case,
#'   the first row of the matrix corresponds to the overall performances, and
#'   subsequent rows correspond to each of the blocks. The order of the blocks
#'   is defined as in \code{\link{BlockStructure}}.
#'
#' @family functions for evaluation of model performance
#'
#' @examples
#' \dontrun{
# Simulation with 5 groups of correlated variables
#' set.seed(1)
#' pk <- sample(1:10, size = 5, replace = TRUE)
#' print(pk)
#' simul <- SimulateGraphical(
#'   n = 100, pk = pk,
#'   nu_within = 0.6,
#'   nu_between = 0.1,
#'   v_within = c(0.1, 1),
#'   v_between = c(0, 0.3),
#'   v_sign = -1
#' )
#' par(mar = c(5, 5, 5, 5))
#' Heatmap(
#'   mat = cor(simul$data),
#'   colours = c("navy", "white", "red"),
#'   legend_range = c(-1, 1)
#' )
#'
#' # Stability grouping
#' stab <- GraphicalModel(
#'   xdata = simul$data,
#'   Lambda = 1:ncol(simul$data),
#'   implementation = HierarchicalClustering
#' )
#'
#' # Clustering performance
#' ClusteringPerformance(theta = stab, theta_star = Clusters(BlockDiagonal(pk)))
#' ClusteringPerformance(
#'   theta = Clusters(stab),
#'   theta_star = Clusters(BlockDiagonal(pk))
#' ) # alternative formulation
#' }
#'
#' @export
ClusteringPerformance <- function(theta, theta_star, pk = NULL) {
  # Re-formatting input theta
  if (any(class(theta) %in% c("graphical_model", "clustering"))) {
    theta <- Clusters(theta)
  }

  # Re-formatting input theta_star
  if (any(class(theta_star) %in% c("simulation_clustering"))) {
    theta_star <- theta_star$theta
  }

  # Initialising unused parameters
  cor <- NULL
  thr <- 0.5

  # Computing co-membership matrices
  theta <- CoMembership(theta)
  theta_star <- CoMembership(theta_star)

  # Storing similarities/differences between estimated and true sets
  Asum <- theta + 2 * theta_star

  # Extracting block-specific performances
  if (is.null(pk)) {
    tmp <- SelectionPerformanceSingle(Asum, cor = cor, thr = thr)
    rand <- (tmp$TP + tmp$TN) / (tmp$TP + tmp$FP + tmp$TN + tmp$FN)
    tmp <- cbind(tmp, rand = rand)
    return(tmp)
  } else {
    Asum_vect <- Asum[upper.tri(Asum)]
    bigblocks <- BlockMatrix(pk)
    bigblocks_vect <- bigblocks[upper.tri(bigblocks)]
    if (!is.null(cor)) {
      cor_vect <- cor[upper.tri(cor)]
    } else {
      cor_vect <- NULL
    }

    tmp <- SelectionPerformanceSingle(Asum, cor = cor, thr = thr)
    rand <- (tmp$TP + tmp$TN) / (tmp$TP + tmp$FP + tmp$TN + tmp$FN)
    tmp <- cbind(tmp, rand = rand)
    out <- tmp
    for (k in sort(unique(bigblocks_vect))) {
      tmp <- SelectionPerformanceSingle(Asum_vect[bigblocks_vect == k],
        cor = cor_vect[bigblocks_vect == k], thr = thr
      )
      rand <- (tmp$TP + tmp$TN) / (tmp$TP + tmp$FP + tmp$TN + tmp$FN)
      tmp <- cbind(tmp, rand = rand)
      out <- rbind(out, tmp)
    }

    return(out)
  }
}