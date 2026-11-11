///|
/// Errors produced while preparing training data.
pub suberror TrainError {
  EmptyDataset
}

///|
impl Show for TrainError with fn output(self, logger) {
  match self {
    EmptyDataset =>
      logger.write_string("training dataset contains no sequences")
  }
}

///|
/// One sequence encoded as feature IDs and label IDs.
priv struct EncodedSequence {
  features : Array[Array[Int32]]
  labels : Array[Int32]
}

///|
/// Encodes a dataset and exposes the CRF training objective.
pub struct CrfTrainer {
  priv feature_index : FeatureIndex
  priv label_index : LabelIndex
  priv sequences : Array[EncodedSequence]
  priv num_labels : Int32
  priv num_features : Int32
}

///|
/// Encodes every non-empty sequence in `dataset`.
///
/// Labels and features are interned in first-seen order. The resulting trainer
/// owns the indexes, so prediction can reuse the exact same feature space.
pub fn CrfTrainer::from_dataset(
  dataset : Dataset,
  templates : TemplateSet,
) -> CrfTrainer raise TrainError {
  let feature_index = StringIndex::new()
  let label_index = StringIndex::new()
  let sequences : Array[EncodedSequence] = []
  for sequence in dataset.sequences() {
    if sequence.len() == 0 {
      continue
    }
    let features = templates.extract_ids(
      sequence.tokens().to_owned(),
      feature_index,
    )
    let labels : Array[Int32] = []
    for label in sequence.labels() {
      labels.push(label_index.intern(label))
    }
    sequences.push(EncodedSequence::{ features, labels, })
  }
  if sequences.length() == 0 {
    raise EmptyDataset
  }
  let num_labels = label_index.len()
  let num_features = feature_index.len()
  CrfTrainer::{
    feature_index,
    label_index,
    sequences,
    num_labels,
    num_features,
  }
}

///|
/// Number of labels in the encoded training set.
pub fn CrfTrainer::num_labels(self : CrfTrainer) -> Int32 {
  self.num_labels
}

///|
/// Number of state features in the encoded training set.
pub fn CrfTrainer::num_features(self : CrfTrainer) -> Int32 {
  self.num_features
}

///|
/// Resolves a label ID back to its string.
pub fn CrfTrainer::label_name(self : CrfTrainer, id : Int32) -> String? {
  self.label_index.name(id)
}

///|
/// Resolves a feature ID back to its string.
pub fn CrfTrainer::feature_name(self : CrfTrainer, id : Int32) -> String? {
  self.feature_index.name(id)
}

///|
/// Computes the regularized negative log-likelihood and its gradient.
///
/// The gradient uses the same layout as `CrfModel::to_parameters`.
pub fn CrfTrainer::objective_and_gradient(
  self : CrfTrainer,
  parameters : Array[Double],
  l2~ : Double = 0.0,
) -> (Double, Array[Double]) raise ModelError {
  let model = CrfModel::from_parameters(
    parameters,
    self.num_labels,
    self.num_features,
  )
  self.objective_and_gradient_with_model(parameters, model, l2)
}

///|
/// Objective and gradient for an already validated model.
fn CrfTrainer::objective_and_gradient_with_model(
  self : CrfTrainer,
  parameters : Array[Double],
  model : CrfModel,
  l2 : Double,
) -> (Double, Array[Double]) {
  let labels_count = self.num_labels
  let features_count = self.num_features
  let transition_base = features_count * labels_count
  let gradient : Array[Double] = Array::make(parameters.length(), 0.0)
  let mut objective = 0.0
  for sequence in self.sequences {
    let features = sequence.features
    let labels = sequence.labels
    let length = labels.length()
    if length == 0 {
      continue
    }
    let state = model.state_scores_unchecked(features)
    let (alpha, log_z) = model.forward(state)
    let beta = model.backward(state)
    let mut score = 0.0
    for position in 0..<length {
      for feature in features[position] {
        score += model.weights[feature][labels[position]]
      }
      if position > 0 {
        score += model.transitions[labels[position - 1]][labels[position]]
      }
    }
    objective += log_z - score
    for position in 0..<length {
      for label in 0..<labels_count {
        let probability = @math.exp(
          alpha[position][label] + beta[position][label] - log_z,
        )
        for feature in features[position] {
          gradient[feature * labels_count + label] += probability
        }
      }
      for feature in features[position] {
        gradient[feature * labels_count + labels[position]] -= 1.0
      }
    }
    for position in 1..<length {
      for previous in 0..<labels_count {
        for current in 0..<labels_count {
          let probability = @math.exp(
            alpha[position - 1][previous] +
            model.transitions[previous][current] +
            state[position][current] +
            beta[position][current] -
            log_z,
          )
          gradient[transition_base + previous * labels_count + current] += probability
        }
      }
      gradient[transition_base +
      labels[position - 1] * labels_count +
      labels[position]] -= 1.0
    }
  }
  if l2 > 0.0 {
    let mut squared_norm = 0.0
    for i in 0..<parameters.length() {
      squared_norm += parameters[i] * parameters[i]
      gradient[i] += l2 * parameters[i]
    }
    objective += 0.5 * l2 * squared_norm
  }
  (objective, gradient)
}
