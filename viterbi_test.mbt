///|
fn brute_force_best(
  model : @mooncrf.CrfModel,
  features : Array[Array[Int32]],
) -> (Array[Int32], Double) raise @mooncrf.ModelError {
  let sequences = enumerate_labels(features.length(), model.num_labels())
  let mut best_labels : Array[Int32] = []
  let mut best_score = -1.0e300
  for labels in sequences {
    let score = model.score(features, labels)
    if score > best_score {
      best_score = score
      best_labels = labels
    }
  }
  (best_labels, best_score)
}

///|
fn expect_viterbi_error(
  model : @mooncrf.CrfModel,
  features : Array[Array[Int32]],
) -> @mooncrf.ModelError {
  let _ = model.viterbi(features) catch { err => return err }
  panic()
}

///|
test "matches brute force on a small sequence" {
  let model = @mooncrf.CrfModel::new(3, 4)
  model.set_weight(0, 0, 0.4)
  model.set_weight(0, 1, -0.1)
  model.set_weight(0, 2, 0.2)
  model.set_weight(1, 0, -0.3)
  model.set_weight(1, 1, 0.8)
  model.set_weight(1, 2, 0.1)
  model.set_weight(2, 0, 0.5)
  model.set_weight(2, 1, -0.6)
  model.set_weight(2, 2, 0.9)
  model.set_weight(3, 0, 0.2)
  model.set_weight(3, 1, 0.3)
  model.set_weight(3, 2, -0.4)
  model.set_transition(0, 1, 0.7)
  model.set_transition(1, 2, 0.5)
  model.set_transition(2, 0, 0.6)
  model.set_transition(2, 2, -0.2)
  let features : Array[Array[Int32]] = [[0, 2], [1], [3, 0]]
  let (expected_labels, expected_score) = brute_force_best(model, features)
  let result = model.viterbi(features)
  assert_eq(result.labels().length(), expected_labels.length())
  for position in 0..<expected_labels.length() {
    assert_eq(result.labels()[position], expected_labels[position])
  }
  assert_true((result.score() - expected_score).abs() < 1.0e-9)
}

///|
test "transition weights can dominate state weights" {
  let model = @mooncrf.CrfModel::new(2, 1)
  model.set_transition(0, 1, 10.0)
  let result = model.viterbi([[0], [0]])
  assert_eq(result.labels()[0], 0)
  assert_eq(result.labels()[1], 1)
}

///|
test "ties choose the smallest label" {
  let model = @mooncrf.CrfModel::new(2, 1)
  let result = model.viterbi([[0]])
  assert_eq(result.labels().length(), 1)
  assert_eq(result.labels()[0], 0)
}

///|
test "empty sequence has an empty path and zero score" {
  let model = @mooncrf.CrfModel::new(2, 1)
  let result = model.viterbi([])
  assert_eq(result.labels().length(), 0)
  assert_eq(result.score(), 0.0)
}

///|
test "rejects feature ids outside the model" {
  let model = @mooncrf.CrfModel::new(2, 1)
  match expect_viterbi_error(model, [[5]]) {
    @mooncrf.ModelError::FeatureOutOfRange(feature, count) => {
      assert_eq(feature, 5)
      assert_eq(count, 1)
    }
    _ => panic()
  }
}
