# mooncrf

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
- [ ] Feature templates and feature extraction
- [ ] Forward-backward inference
- [ ] Viterbi decoding
- [ ] L-BFGS training
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

Malformed input raises `DatasetError` with the offending line number. Callers
that prefer not to raise can use `Dataset::parse_conll`, which returns a
`Result`.

## License

Apache-2.0. See [LICENSE](LICENSE).

## References

The implementation follows the standard linear-chain CRF formulation described
in Lafferty, McCallum, and Pereira, *Conditional Random Fields: Probabilistic
Models for Segmenting and Labeling Sequence Data* (ICML 2001).

[CRFsuite](https://github.com/chokkan/crfsuite) (BSD-3-Clause) is used as a
behavioral reference for feature templates and training. `mooncrf` is an
independent MoonBit implementation and does not include CRFsuite source code.
