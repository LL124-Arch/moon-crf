///|
/// Errors produced while constructing or evaluating a CRF model.
pub suberror ModelError {
  NoLabels
  FeatureOutOfRange(Int32, Int32)
  LabelOutOfRange(Int32, Int32)
  LengthMismatch(Int32, Int32)
}

///|
impl Show for ModelError with fn output(self, logger) {
  match self {
    NoLabels => logger.write_string("model requires at least one label")
    FeatureOutOfRange(feature, count) =>
      logger.write_string("feature id \{feature} is outside [0, \{count})")
    LabelOutOfRange(label, count) =>
      logger.write_string("label \{label} is outside [0, \{count})")
    LengthMismatch(features, labels) =>
      logger.write_string(
        "sequence has \{features} positions but \{labels} labels",
      )
  }
}

///|
/// A linear-chain CRF with dense state and transition weights.
///
/// State weights are indexed as `weights[feature_id][label]`; transition
/// weights are indexed as `transitions[previous_label][current_label]`.
pub struct CrfModel {
  priv num_labels : Int32
  priv weights : Array[Array[Double]]
  priv transitions : Array[Array[Double]]
}

///|
/// Creates a zero-initialized model.
pub fn CrfModel::new(
  num_labels : Int32,
  num_features : Int32,
) -> CrfModel raise ModelError {
  if num_labels <= 0 {
    raise NoLabels
  }
  let weights : Array[Array[Double]] = Array::makei(num_features, fn(_) {
    Array::make(num_labels, 0.0)
  })
  let transitions : Array[Array[Double]] = Array::makei(num_labels, fn(_) {
    Array::make(num_labels, 0.0)
  })
  CrfModel::{ num_labels, weights, transitions, }
}

///|
/// Number of labels in the model.
pub fn CrfModel::num_labels(self : CrfModel) -> Int32 {
  self.num_labels
}

///|
/// Number of state features in the model.
pub fn CrfModel::num_features(self : CrfModel) -> Int32 {
  self.weights.length()
}

///|
/// Checks a label index.
fn CrfModel::check_label(
  self : CrfModel,
  label : Int32,
) -> Unit raise ModelError {
  if label < 0 || label >= self.num_labels {
    raise LabelOutOfRange(label, self.num_labels)
  }
}

///|
/// Checks a feature index.
fn CrfModel::check_feature(
  self : CrfModel,
  feature : Int32,
) -> Unit raise ModelError {
  let count = self.weights.length()
  if feature < 0 || feature >= count {
    raise FeatureOutOfRange(feature, count)
  }
}

///|
/// Reads one state weight.
pub fn CrfModel::weight(
  self : CrfModel,
  feature : Int32,
  label : Int32,
) -> Double raise ModelError {
  self.check_feature(feature)
  self.check_label(label)
  self.weights[feature][label]
}

///|
/// Writes one state weight.
pub fn CrfModel::set_weight(
  self : CrfModel,
  feature : Int32,
  label : Int32,
  value : Double,
) -> Unit raise ModelError {
  self.check_feature(feature)
  self.check_label(label)
  self.weights[feature][label] = value
}

///|
/// Reads one transition weight.
pub fn CrfModel::transition(
  self : CrfModel,
  previous : Int32,
  current : Int32,
) -> Double raise ModelError {
  self.check_label(previous)
  self.check_label(current)
  self.transitions[previous][current]
}

///|
/// Writes one transition weight.
pub fn CrfModel::set_transition(
  self : CrfModel,
  previous : Int32,
  current : Int32,
  value : Double,
) -> Unit raise ModelError {
  self.check_label(previous)
  self.check_label(current)
  self.transitions[previous][current] = value
}

///|
/// Computes the unnormalized score of a labeled sequence.
pub fn CrfModel::score(
  self : CrfModel,
  features : Array[Array[Int32]],
  labels : Array[Int32],
) -> Double raise ModelError {
  if features.length() != labels.length() {
    raise LengthMismatch(features.length(), labels.length())
  }
  let mut total = 0.0
  for i, label in labels {
    self.check_label(label)
    total += self.state_score(features[i], label)
    if i > 0 {
      total += self.transitions[labels[i - 1]][label]
    }
  }
  total
}

///|
/// Computes the state score of one position for one label.
pub fn CrfModel::state_score(
  self : CrfModel,
  feature_ids : Array[Int32],
  label : Int32,
) -> Double raise ModelError {
  self.check_label(label)
  let mut total = 0.0
  for feature in feature_ids {
    self.check_feature(feature)
    total += self.weights[feature][label]
  }
  total
}

///|
/// Precomputes state scores for every position and label.
fn CrfModel::state_scores(
  self : CrfModel,
  features : Array[Array[Int32]],
) -> Array[Array[Double]] raise ModelError {
  let result : Array[Array[Double]] = []
  for feature_ids in features {
    let row : Array[Double] = []
    for label in 0..<self.num_labels {
      let mut total = 0.0
      for feature in feature_ids {
        self.check_feature(feature)
        total += self.weights[feature][label]
      }
      row.push(total)
    }
    result.push(row)
  }
  result
}

///|
/// Log-sum-exp with a max shift for numerical stability.
fn log_sum_exp(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return -1.0e300
  }
  let mut maximum = values[0]
  for i in 1..<values.length() {
    if values[i] > maximum {
      maximum = values[i]
    }
  }
  let mut sum = 0.0
  for value in values {
    sum += @math.exp(value - maximum)
  }
  maximum + @math.ln(sum)
}

///|
/// Forward pass in log space. Returns log-alpha and log Z.
fn CrfModel::forward(
  self : CrfModel,
  state : Array[Array[Double]],
) -> (Array[Array[Double]], Double) {
  let alpha : Array[Array[Double]] = []
  if state.length() == 0 {
    return (alpha, 0.0)
  }
  let first : Array[Double] = []
  for label in 0..<self.num_labels {
    first.push(state[0][label])
  }
  alpha.push(first)
  for position in 1..<state.length() {
    let previous = alpha[position - 1]
    let row : Array[Double] = []
    for current in 0..<self.num_labels {
      let candidates : Array[Double] = []
      for previous_label in 0..<self.num_labels {
        candidates.push(
          previous[previous_label] + self.transitions[previous_label][current],
        )
      }
      row.push(state[position][current] + log_sum_exp(candidates))
    }
    alpha.push(row)
  }
  let log_z = log_sum_exp(alpha[alpha.length() - 1])
  (alpha, log_z)
}

///|
/// Backward pass in log space.
fn CrfModel::backward(
  self : CrfModel,
  state : Array[Array[Double]],
) -> Array[Array[Double]] {
  let beta : Array[Array[Double]] = []
  if state.length() == 0 {
    return beta
  }
  for _ in 0..<state.length() {
    beta.push(Array::make(self.num_labels, 0.0))
  }
  let mut position = state.length() - 2
  while position >= 0 {
    for previous in 0..<self.num_labels {
      let candidates : Array[Double] = []
      for current in 0..<self.num_labels {
        candidates.push(
          self.transitions[previous][current] +
          state[position + 1][current] +
          beta[position + 1][current],
        )
      }
      beta[position][previous] = log_sum_exp(candidates)
    }
    position -= 1
  }
  beta
}

///|
/// Computes log Z for a feature sequence.
pub fn CrfModel::log_partition(
  self : CrfModel,
  features : Array[Array[Int32]],
) -> Double raise ModelError {
  let state = self.state_scores(features)
  let (_, log_z) = self.forward(state)
  log_z
}

///|
/// Computes the posterior marginal probability of every position and label.
pub fn CrfModel::marginals(
  self : CrfModel,
  features : Array[Array[Int32]],
) -> Array[Array[Double]] raise ModelError {
  let state = self.state_scores(features)
  let (alpha, log_z) = self.forward(state)
  let beta = self.backward(state)
  let result : Array[Array[Double]] = []
  for position in 0..<state.length() {
    let row : Array[Double] = []
    let mut sum = 0.0
    for label in 0..<self.num_labels {
      let value = @math.exp(
        alpha[position][label] + beta[position][label] - log_z,
      )
      row.push(value)
      sum += value
    }
    if sum > 0.0 {
      for label in 0..<self.num_labels {
        row[label] = row[label] / sum
      }
    }
    result.push(row)
  }
  result
}

///|
/// Computes the log probability of a labeled sequence.
pub fn CrfModel::log_probability(
  self : CrfModel,
  features : Array[Array[Int32]],
  labels : Array[Int32],
) -> Double raise ModelError {
  self.score(features, labels) - self.log_partition(features)
}
