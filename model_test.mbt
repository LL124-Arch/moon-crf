///|
fn enumerate_labels(n : Int32, k : Int32) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  if n == 0 {
    result.push([])
    return result
  }
  let shorter = enumerate_labels(n - 1, k)
  for prefix in shorter {
    for label in 0..<k {
      let sequence = prefix.copy()
      sequence.push(label)
      result.push(sequence)
    }
  }
  result
}

///|
fn brute_force_marginals(
  model : @mooncrf.CrfModel,
  features : Array[Array[Int32]],
) -> (Double, Array[Array[Double]]) raise @mooncrf.ModelError {
  let sequences = enumerate_labels(features.length(), model.num_labels())
  let scores : Array[Double] = []
  let mut maximum = -1.0e300
  for labels in sequences {
    let score = model.score(features, labels)
    scores.push(score)
    if score > maximum {
      maximum = score
    }
  }
  let mut total = 0.0
  for score in scores {
    total += @math.exp(score - maximum)
  }
  let log_z = maximum + @math.ln(total)
  let marginals : Array[Array[Double]] = []
  for _ in 0..<features.length() {
    marginals.push(Array::make(model.num_labels(), 0.0))
  }
  for index, labels in sequences {
    let probability = @math.exp(scores[index] - log_z)
    for position, label in labels {
      marginals[position][label] += probability
    }
  }
  (log_z, marginals)
}

///|
fn expect_partition_error(
  model : @mooncrf.CrfModel,
  features : Array[Array[Int32]],
) -> @mooncrf.ModelError {
  let _ = model.log_partition(features) catch { err => return err }
  panic()
}

///|
fn expect_score_error(
  model : @mooncrf.CrfModel,
  features : Array[Array[Int32]],
  labels : Array[Int32],
) -> @mooncrf.ModelError {
  let _ = model.score(features, labels) catch { err => return err }
  panic()
}

///|
fn expect_new_error(labels : Int32, features : Int32) -> @mooncrf.ModelError {
  let _ = @mooncrf.CrfModel::new(labels, features) catch { err => return err }
  panic()
}

///|
test "matches brute force on a small sequence" {
  let model = @mooncrf.CrfModel::new(2, 3)
  model.set_weight(0, 0, 0.5)
  model.set_weight(0, 1, -0.25)
  model.set_weight(1, 0, 1.0)
  model.set_weight(1, 1, 0.3)
  model.set_weight(2, 0, -0.7)
  model.set_weight(2, 1, 0.9)
  model.set_transition(0, 0, 0.2)
  model.set_transition(0, 1, -0.4)
  model.set_transition(1, 0, 0.6)
  model.set_transition(1, 1, -0.1)
  let features : Array[Array[Int32]] = [[0, 1], [1, 2]]
  let (expected_log_z, expected_marginals) = brute_force_marginals(
    model, features,
  )
  let actual_log_z = model.log_partition(features)
  assert_true((actual_log_z - expected_log_z).abs() < 1.0e-9)
  let actual = model.marginals(features)
  for position in 0..<features.length() {
    for label in 0..<model.num_labels() {
      assert_true(
        (actual[position][label] - expected_marginals[position][label]).abs() <
        1.0e-9,
      )
    }
  }
}

///|
test "matches softmax for a single position" {
  let model = @mooncrf.CrfModel::new(2, 1)
  model.set_weight(0, 1, 1.0)
  let marginals = model.marginals([[0]])
  let expected = 1.0 / (1.0 + @math.exp(-1.0))
  assert_true((marginals[0][1] - expected).abs() < 1.0e-12)
  assert_true((marginals[0][0] + marginals[0][1] - 1.0).abs() < 1.0e-12)
}

///|
test "stays stable with large weights" {
  let model = @mooncrf.CrfModel::new(2, 1)
  model.set_weight(0, 1, 1000.0)
  let marginals = model.marginals([[0]])
  assert_true((marginals[0][1] - 1.0).abs() < 1.0e-12)
  assert_true(marginals[0][0].abs() < 1.0e-12)
  assert_true(model.log_partition([[0]]) > 999.0)
}

///|
test "empty sequence has log partition zero" {
  let model = @mooncrf.CrfModel::new(2, 1)
  assert_eq(model.log_partition([]), 0.0)
  assert_eq(model.marginals([]).length(), 0)
}

///|
test "positions without features are uniform" {
  let model = @mooncrf.CrfModel::new(2, 1)
  let marginals = model.marginals([[]])
  assert_true((marginals[0][0] - 0.5).abs() < 1.0e-12)
  assert_true((marginals[0][1] - 0.5).abs() < 1.0e-12)
}

///|
test "score and log probability agree with the partition function" {
  let model = @mooncrf.CrfModel::new(2, 2)
  model.set_weight(0, 0, 0.4)
  model.set_weight(0, 1, -0.2)
  model.set_weight(1, 0, 0.1)
  model.set_weight(1, 1, 0.7)
  model.set_transition(0, 1, 0.3)
  model.set_transition(1, 0, -0.5)
  let features : Array[Array[Int32]] = [[0], [1]]
  let labels : Array[Int32] = [1, 0]
  let expected = -0.2 + -0.5 + 0.1
  let actual = model.score(features, labels)
  assert_true((actual - expected).abs() < 1.0e-12)
  let log_probability = model.log_probability(features, labels)
  assert_true(
    (log_probability - (actual - model.log_partition(features))).abs() < 1.0e-12,
  )
}

///|
test "rejects feature ids outside the model" {
  let model = @mooncrf.CrfModel::new(2, 1)
  match expect_partition_error(model, [[1]]) {
    @mooncrf.ModelError::FeatureOutOfRange(feature, count) => {
      assert_eq(feature, 1)
      assert_eq(count, 1)
    }
    _ => panic()
  }
}

///|
test "rejects label ids outside the model" {
  let model = @mooncrf.CrfModel::new(2, 1)
  match expect_score_error(model, [[0]], [2]) {
    @mooncrf.ModelError::LabelOutOfRange(label, count) => {
      assert_eq(label, 2)
      assert_eq(count, 2)
    }
    _ => panic()
  }
}

///|
test "rejects mismatched feature and label lengths" {
  let model = @mooncrf.CrfModel::new(2, 1)
  match expect_score_error(model, [[0]], []) {
    @mooncrf.ModelError::LengthMismatch(features, labels) => {
      assert_eq(features, 1)
      assert_eq(labels, 0)
    }
    _ => panic()
  }
}

///|
test "rejects models without labels" {
  match expect_new_error(0, 1) {
    @mooncrf.ModelError::NoLabels => ()
    _ => panic()
  }
}
