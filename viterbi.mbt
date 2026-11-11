///|
/// The best label sequence for one observation sequence.
pub struct ViterbiResult {
  priv labels : Array[Int32]
  priv score : Double
}

///|
/// Best label sequence.
pub fn ViterbiResult::labels(self : ViterbiResult) -> ArrayView[Int32] {
  self.labels[:]
}

///|
/// Score of the best label sequence.
pub fn ViterbiResult::score(self : ViterbiResult) -> Double {
  self.score
}

///|
/// Decodes the highest-scoring label sequence with Viterbi dynamic
/// programming.
///
/// Ties are resolved in favor of the smallest label index at each step, so
/// the result is deterministic.
pub fn CrfModel::viterbi(
  self : CrfModel,
  features : Array[Array[Int32]],
) -> ViterbiResult raise ModelError {
  let state = self.state_scores(features)
  let length = state.length()
  if length == 0 {
    return ViterbiResult::{ labels: [], score: 0.0, }
  }
  let delta : Array[Array[Double]] = []
  let backpointers : Array[Array[Int32]] = []
  let first : Array[Double] = []
  for label in 0..<self.num_labels {
    first.push(state[0][label])
  }
  delta.push(first)
  for position in 1..<length {
    let previous = delta[position - 1]
    let row : Array[Double] = []
    let back : Array[Int32] = []
    for current in 0..<self.num_labels {
      let mut best_previous = 0
      let mut best_value = previous[0] + self.transitions[0][current]
      for previous_label in 1..<self.num_labels {
        let value = previous[previous_label] +
          self.transitions[previous_label][current]
        if value > best_value {
          best_value = value
          best_previous = previous_label
        }
      }
      row.push(state[position][current] + best_value)
      back.push(best_previous)
    }
    delta.push(row)
    backpointers.push(back)
  }
  let final_row = delta[length - 1]
  let mut best_label = 0
  let mut best_score = final_row[0]
  for label in 1..<self.num_labels {
    if final_row[label] > best_score {
      best_score = final_row[label]
      best_label = label
    }
  }
  let labels : Array[Int32] = Array::make(length, 0)
  labels[length - 1] = best_label
  let mut position = length - 1
  while position > 0 {
    labels[position - 1] = backpointers[position - 1][labels[position]]
    position -= 1
  }
  ViterbiResult::{ labels, score: best_score, }
}
