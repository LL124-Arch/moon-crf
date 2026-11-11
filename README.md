# mooncrf

[中文说明](README.zh-CN.md) | English

A pure MoonBit implementation of linear-chain conditional random fields (CRF)
for sequence labeling.

`mooncrf` is a reusable library and command-line toolkit for token-level
labeling tasks such as named-entity recognition, part-of-speech tagging,
Chinese word segmentation, and biological sequence annotation. It is written in
MoonBit and has no native dependencies.

## Status

The project is under active development. The public API is being built
incrementally, with every feature covered by tests before it is merged.

## Roadmap

- [x] CoNLL-style dataset reader
- [x] Feature templates and feature extraction
- [x] Feature index and ID encoding
- [x] Forward-backward inference
- [x] Viterbi decoding
- [x] L-BFGS optimizer
- [ ] CRF training objective
- [ ] Model serialization
- [ ] Precision / recall / F1 evaluation
- [ ] Command-line interface
- [ ] Published on mooncakes.io

## Installation

```bash
moon add LL124-Arch/mooncrf
```

## Reading a CoNLL dataset

`mooncrf` reads the common two-column CoNLL layout: one `token label` pair per
line, a blank line between sequences, and `#` for comments.

```moonbit
import {
  "LL124-Arch/mooncrf",
}

let dataset = @mooncrf.Dataset::from_conll(
  "Alice B-PER\nmet O\n\nBob B-PER\n",
)
println(dataset.len()) // 2
println(dataset.sequences()[0].tokens()[0]) // Alice
```

Malformed input raises `DatasetError` with the offending line number.

## Feature templates

Templates use `%x[row,column]` references, where `row` is relative to the
current token and `column` is the token field. The current data model is
single-field, so only column `0` is accepted.

```moonbit
let templates = @mooncrf.TemplateSet::parse([
  "%x[0,0]",
  "%x[-1,0]/%x[0,0]",
])
let features = templates.extract(["Alice", "met", "Bob"])
// Position 1 contains "t0:met", "t1:Alice/met", and the bias feature "b".
```

Out-of-range references are skipped, so the first token does not produce a
`%x[-1,0]` feature. Literal text and `%%` escaping are supported.

## Feature IDs

`FeatureIndex` assigns stable integer IDs to feature names, and
`TemplateSet::extract_ids` combines extraction and interning:

```moonbit
let index = @mooncrf.FeatureIndex::new()
let ids = templates.extract_ids(["Alice", "met", "Bob"], index)
```

IDs are assigned in first-seen order, so the same feature always receives the
same ID while an index is being built.

## Scoring and marginals

`CrfModel` stores dense state weights (feature × label) and transition weights
(label × label). The forward-backward pass runs in log space:

```moonbit
let model = @mooncrf.CrfModel::new(2, 3)
model.set_weight(0, 0, 0.5)
model.set_transition(0, 1, -0.4)
let features : Array[Array[Int]] = [[0, 1], [1, 2]]
let log_z = model.log_partition(features)
let marginals = model.marginals(features)
```

`marginals` returns one probability row per position, with each row normalized
to sum to one.

## Viterbi decoding

```moonbit
let result = model.viterbi(features)
println(result.labels())
println(result.score())
```

Ties are resolved in favor of the smallest label index, so decoding is
deterministic.

## L-BFGS optimizer

`minimize` is a standalone L-BFGS minimizer. It takes an initial parameter
vector and a callback returning the objective value and gradient, so it can be
tested independently of the CRF model.

```moonbit
let result = @mooncrf.minimize([1.0, 1.0], quadratic)
println(result.converged())
println(result.iterations())
```

The optimizer uses the two-loop recursion, Armijo backtracking, and a
first-step scaling based on the gradient norm.

## License

Apache-2.0. See [LICENSE](LICENSE).

## References

The implementation follows the standard linear-chain CRF formulation described
in Lafferty, McCallum, and Pereira, *Conditional Random Fields: Probabilistic
Models for Segmenting and Labeling Sequence Data* (ICML 2001).

[CRFsuite](https://github.com/chokkan/crfsuite) (BSD-3-Clause) is used as a
behavioral reference for feature templates and training. `mooncrf` is an
independent MoonBit implementation and does not include CRFsuite source code.
