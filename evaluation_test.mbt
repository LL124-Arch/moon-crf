///|
fn expect_evaluation_error(
  gold : Array[String],
  predicted : Array[String],
) -> @mooncrf.EvaluationError {
  let _ = @mooncrf.evaluate(gold, predicted) catch { err => return err }
  panic()
}

///|
test "perfect predictions score one" {
  let result = @mooncrf.evaluate(["X", "Y", "X"], ["X", "Y", "X"])
  assert_eq(result.accuracy(), 1.0)
  assert_eq(result.precision(), 1.0)
  assert_eq(result.recall(), 1.0)
  assert_eq(result.f1(), 1.0)
  assert_eq(result.support(), 3)
}

///|
test "partial errors produce micro averaged metrics" {
  let result = @mooncrf.evaluate(["X", "X", "Y"], ["X", "Y", "Y"])
  let expected = 2.0 / 3.0
  assert_true((result.accuracy() - expected).abs() < 1.0e-12)
  assert_true((result.precision() - expected).abs() < 1.0e-12)
  assert_true((result.recall() - expected).abs() < 1.0e-12)
  assert_true((result.f1() - expected).abs() < 1.0e-12)
}

///|
test "all wrong predictions score zero" {
  let result = @mooncrf.evaluate(["X", "X"], ["Y", "Y"])
  assert_eq(result.accuracy(), 0.0)
  assert_eq(result.precision(), 0.0)
  assert_eq(result.recall(), 0.0)
  assert_eq(result.f1(), 0.0)
}

///|
test "empty input has zero support" {
  let result = @mooncrf.evaluate([], [])
  assert_eq(result.support(), 0)
  assert_eq(result.f1(), 0.0)
}

///|
test "rejects mismatched lengths" {
  match expect_evaluation_error(["X"], []) {
    @mooncrf.EvaluationError::LengthMismatch(gold, predicted) => {
      assert_eq(gold, 1)
      assert_eq(predicted, 0)
    }
  }
}
