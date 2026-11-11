///|
/// Errors produced by the L-BFGS minimizer.
pub suberror OptimizeError {
  DimensionMismatch(Int32, Int32)
}

///|
impl Show for OptimizeError with fn output(self, logger) {
  match self {
    DimensionMismatch(parameters, gradient) =>
      logger.write_string(
        "parameter size \{parameters} does not match gradient size \{gradient}",
      )
  }
}

///|
/// Tunable L-BFGS parameters.
pub struct LbfgsOptions {
  priv max_iterations : Int32
  priv memory : Int32
  priv tolerance : Double
  priv line_search_steps : Int32
}

///|
/// Creates options with explicit values.
pub fn LbfgsOptions::new(
  max_iterations~ : Int32 = 200,
  memory~ : Int32 = 10,
  tolerance~ : Double = 1.0e-6,
  line_search_steps~ : Int32 = 40,
) -> LbfgsOptions {
  LbfgsOptions::{ max_iterations, memory, tolerance, line_search_steps, }
}

///|
/// Default options: 200 iterations, 10 history pairs, tolerance 1e-6.
pub fn LbfgsOptions::default() -> LbfgsOptions {
  LbfgsOptions::new()
}

///|
/// Result of a minimization run.
pub struct LbfgsResult {
  priv weights : Array[Double]
  priv value : Double
  priv gradient_norm : Double
  priv iterations : Int32
  priv converged : Bool
}

///|
/// Final parameter vector.
pub fn LbfgsResult::weights(self : LbfgsResult) -> ArrayView[Double] {
  self.weights[:]
}

///|
/// Final objective value.
pub fn LbfgsResult::value(self : LbfgsResult) -> Double {
  self.value
}

///|
/// Final gradient norm.
pub fn LbfgsResult::gradient_norm(self : LbfgsResult) -> Double {
  self.gradient_norm
}

///|
/// Number of completed iterations.
pub fn LbfgsResult::iterations(self : LbfgsResult) -> Int32 {
  self.iterations
}

///|
/// Whether the gradient tolerance was reached.
pub fn LbfgsResult::converged(self : LbfgsResult) -> Bool {
  self.converged
}

///|
/// One L-BFGS curvature pair.
priv struct LbfgsPair {
  s : Array[Double]
  y : Array[Double]
  rho : Double
}

///|
/// Dot product.
fn dot(left : Array[Double], right : Array[Double]) -> Double {
  let mut total = 0.0
  for i in 0..<left.length() {
    total += left[i] * right[i]
  }
  total
}

///|
/// Euclidean norm.
fn norm(values : Array[Double]) -> Double {
  dot(values, values).sqrt()
}

///|
/// Computes the L-BFGS search direction with the two-loop recursion.
fn direction(
  gradient : Array[Double],
  history : Array[LbfgsPair],
) -> Array[Double] {
  let q = gradient.copy()
  let alphas : Array[Double] = Array::make(history.length(), 0.0)
  let mut i = history.length() - 1
  while i >= 0 {
    let pair = history[i]
    let alpha = pair.rho * dot(pair.s, q)
    alphas[i] = alpha
    for j in 0..<q.length() {
      q[j] = q[j] - alpha * pair.y[j]
    }
    i -= 1
  }
  let r = q
  if history.length() > 0 {
    let last = history[history.length() - 1]
    let gamma = dot(last.s, last.y) / dot(last.y, last.y)
    for j in 0..<r.length() {
      r[j] = r[j] * gamma
    }
  }
  let mut k = 0
  while k < history.length() {
    let pair = history[k]
    let beta = pair.rho * dot(pair.y, r)
    for j in 0..<r.length() {
      r[j] = r[j] + pair.s[j] * (alphas[k] - beta)
    }
    k += 1
  }
  for j in 0..<r.length() {
    r[j] = -r[j]
  }
  r
}

///|
/// Minimizes `evaluate` with L-BFGS and Armijo backtracking.
pub fn minimize(
  initial : Array[Double],
  evaluate : (Array[Double]) -> (Double, Array[Double]),
  options? : LbfgsOptions,
) -> LbfgsResult raise OptimizeError {
  let opts = match options {
    Some(value) => value
    None => LbfgsOptions::default()
  }
  let mut weights = initial.copy()
  let (initial_value, initial_gradient) = evaluate(weights)
  let mut value = initial_value
  let mut gradient = initial_gradient
  if gradient.length() != weights.length() {
    raise DimensionMismatch(weights.length(), gradient.length())
  }
  let mut gradient_norm = norm(gradient)
  let mut iterations = 0
  let mut converged = gradient_norm <= opts.tolerance
  let history : Array[LbfgsPair] = []
  while !converged && iterations < opts.max_iterations {
    let mut search = direction(gradient, history)
    let mut slope = dot(gradient, search)
    if slope >= 0.0 {
      history.clear()
      search = Array::make(weights.length(), 0.0)
      for i in 0..<weights.length() {
        search[i] = -gradient[i]
      }
      slope = -dot(gradient, gradient)
    }
    let mut step = 1.0
    if history.length() == 0 && gradient_norm > 1.0 {
      step = 1.0 / gradient_norm
    }
    let mut accepted = false
    let mut next_weights = weights
    let mut next_value = value
    let mut next_gradient = gradient
    for _ in 0..<opts.line_search_steps {
      let candidate : Array[Double] = []
      for i in 0..<weights.length() {
        candidate.push(weights[i] + step * search[i])
      }
      let (candidate_value, candidate_gradient) = evaluate(candidate)
      if candidate_gradient.length() != weights.length() {
        raise DimensionMismatch(weights.length(), candidate_gradient.length())
      }
      if candidate_value <= value + 1.0e-4 * step * slope {
        next_weights = candidate
        next_value = candidate_value
        next_gradient = candidate_gradient
        accepted = true
        break
      }
      step = step * 0.5
    }
    if !accepted {
      break
    }
    let s : Array[Double] = []
    let y : Array[Double] = []
    for i in 0..<weights.length() {
      s.push(next_weights[i] - weights[i])
      y.push(next_gradient[i] - gradient[i])
    }
    let sy = dot(s, y)
    if sy > 1.0e-12 {
      history.push(LbfgsPair::{ s, y, rho: 1.0 / sy, })
      if history.length() > opts.memory {
        let _ = history.remove(0)
      }
    }
    weights = next_weights
    value = next_value
    gradient = next_gradient
    gradient_norm = norm(gradient)
    iterations += 1
    converged = gradient_norm <= opts.tolerance
  }
  LbfgsResult::{ weights, value, gradient_norm, iterations, converged, }
}
