///|
/// Errors produced while evaluating predictions.
pub suberror EvaluationError {
  LengthMismatch(Int32, Int32)
}

///|
impl Show for EvaluationError with fn output(self, logger) {
  match self {
    LengthMismatch(gold, predicted) =>
      logger.write_string(
        "gold has \{gold} labels but predictions have \{predicted}",
      )
  }
}

///|
/// Token-level evaluation metrics.
pub struct Evaluation {
  priv accuracy : Double
  priv precision : Double
  priv recall : Double
  priv f1 : Double
  priv support : Int32
}

///|
/// Fraction of positions where the prediction matches the gold label.
pub fn Evaluation::accuracy(self : Evaluation) -> Double {
  self.accuracy
}

///|
/// Micro-averaged precision.
pub fn Evaluation::precision(self : Evaluation) -> Double {
  self.precision
}

///|
/// Micro-averaged recall.
pub fn Evaluation::recall(self : Evaluation) -> Double {
  self.recall
}

///|
/// Micro-averaged F1.
pub fn Evaluation::f1(self : Evaluation) -> Double {
  self.f1
}

///|
/// Number of evaluated positions.
pub fn Evaluation::support(self : Evaluation) -> Int32 {
  self.support
}

///|
/// Computes token-level accuracy and micro P/R/F1.
pub fn evaluate(
  gold : Array[String],
  predicted : Array[String],
) -> Evaluation raise EvaluationError {
  if gold.length() != predicted.length() {
    raise LengthMismatch(gold.length(), predicted.length())
  }
  let total = gold.length()
  if total == 0 {
    return Evaluation::{
      accuracy: 0.0,
      precision: 0.0,
      recall: 0.0,
      f1: 0.0,
      support: 0,
    }
  }
  let mut correct = 0
  let mut true_positive = 0
  let mut false_positive = 0
  let mut false_negative = 0
  for i in 0..<total {
    if gold[i] == predicted[i] {
      correct += 1
      true_positive += 1
    } else {
      false_positive += 1
      false_negative += 1
    }
  }
  let accuracy = correct.to_double() / total.to_double()
  let precision = if true_positive + false_positive == 0 {
    0.0
  } else {
    true_positive.to_double() / (true_positive + false_positive).to_double()
  }
  let recall = if true_positive + false_negative == 0 {
    0.0
  } else {
    true_positive.to_double() / (true_positive + false_negative).to_double()
  }
  let f1 = if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
  Evaluation::{ accuracy, precision, recall, f1, support: total, }
}
