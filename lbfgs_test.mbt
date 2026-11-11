///|
fn quadratic(x : Array[Double]) -> (Double, Array[Double]) {
  let value = 0.5 * (x[0] * x[0] + 2.0 * x[1] * x[1])
  let gradient : Array[Double] = [x[0], 2.0 * x[1]]
  (value, gradient)
}

///|
fn rosenbrock(x : Array[Double]) -> (Double, Array[Double]) {
  let a = x[0]
  let b = x[1]
  let value = (1.0 - a) * (1.0 - a) + 100.0 * (b - a * a) * (b - a * a)
  let gradient : Array[Double] = [
    -2.0 * (1.0 - a) - 400.0 * a * (b - a * a),
    200.0 * (b - a * a),
  ]
  (value, gradient)
}

///|
fn bad_gradient(_x : Array[Double]) -> (Double, Array[Double]) {
  (0.0, [])
}

///|
fn expect_optimize_error(
  initial : Array[Double],
  evaluate : (Array[Double]) -> (Double, Array[Double]),
) -> @mooncrf.OptimizeError {
  let _ = @mooncrf.minimize(initial, evaluate) catch { err => return err }
  panic()
}

///|
test "minimizes a quadratic to its analytic optimum" {
  let result = @mooncrf.minimize([1.0, 1.0], quadratic)
  assert_true(result.converged())
  assert_true(result.weights()[0].abs() < 1.0e-6)
  assert_true(result.weights()[1].abs() < 1.0e-6)
  assert_true(result.value().abs() < 1.0e-12)
}

///|
test "minimizes the Rosenbrock function" {
  let result = @mooncrf.minimize([-1.2, 1.0], rosenbrock)
  assert_true(result.converged())
  assert_true((result.weights()[0] - 1.0).abs() < 1.0e-3)
  assert_true((result.weights()[1] - 1.0).abs() < 1.0e-3)
}

///|
test "reports dimension mismatches" {
  match expect_optimize_error([1.0], bad_gradient) {
    @mooncrf.OptimizeError::DimensionMismatch(parameters, gradient) => {
      assert_eq(parameters, 1)
      assert_eq(gradient, 0)
    }
  }
}

///|
test "zero iterations returns the initial point" {
  let options = @mooncrf.LbfgsOptions::new(max_iterations=0)
  let result = @mooncrf.minimize([1.0, 1.0], quadratic, options~)
  assert_true(!result.converged())
  assert_eq(result.iterations(), 0)
  assert_eq(result.weights()[0], 1.0)
}

///|
fn empty_objective(_x : Array[Double]) -> (Double, Array[Double]) {
  (0.0, [])
}

///|
test "empty parameters converge immediately" {
  let result = @mooncrf.minimize([], empty_objective)
  assert_true(result.converged())
  assert_eq(result.weights().length(), 0)
  assert_eq(result.gradient_norm(), 0.0)
}
