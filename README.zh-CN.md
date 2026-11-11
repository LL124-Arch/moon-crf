# mooncrf 中文说明

纯 MoonBit 实现的线性链条件随机场（CRF）序列标注库。

适合命名实体识别（NER）、词性标注、中文分词、生物序列标注等 token 级任务。项目不依赖 native 库，可作为 MoonBit 项目中的普通依赖使用。

[English README](README.md)

## 当前进度

- [x] CoNLL 格式数据读取
- [x] 特征模板与特征抽取
- [x] 特征 ID 索引
- [x] 前向-后向推理
- [x] Viterbi 解码
- [x] L-BFGS 优化器
- [x] CRF 训练与预测
- [x] 模型序列化
- [x] 精确率 / 召回率 / F1 评测
- [x] 命令行工具
- [ ] 发布到 mooncakes.io

## 安装

```bash
moon add LL124-Arch/mooncrf
```

## 读取 CoNLL 数据

读取常见的两列 CoNLL 格式：每行是 `token label`，空行分隔不同序列，`#` 开头的是注释。

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

输入格式不合法时会抛出 `DatasetError`，并带上出错的行号。

## 特征模板

模板使用 `%x[row,column]` 引用 token：`row` 是相对当前位置的偏移，`column` 是 token 的字段下标。当前数据模型是单字段，因此只接受 `column = 0`。

```moonbit
let templates = @mooncrf.TemplateSet::parse([
  "%x[0,0]",
  "%x[-1,0]/%x[0,0]",
])
let features = templates.extract(["Alice", "met", "Bob"])
// 第 1 个位置包含 "t0:met"、"t1:Alice/met" 和偏置特征 "b"
```

上下文越界时该模板会被跳过，例如第一个 token 不会产生 `%x[-1,0]` 特征。支持字面量文本和 `%%` 转义。

## 特征 ID

`FeatureIndex` 为特征名分配稳定的整数 ID，`TemplateSet::extract_ids` 把“抽取 + 编号”合并成一步：

```moonbit
let index = @mooncrf.FeatureIndex::new()
let ids = templates.extract_ids(["Alice", "met", "Bob"], index)
```

ID 按首次出现顺序分配；在同一个索引内，同一特征名始终得到同一个 ID。

## 打分与边缘概率

`CrfModel` 保存稠密的状态权重（feature × label）和转移权重（label × label），前向-后向全程使用 log-space：

```moonbit
let model = @mooncrf.CrfModel::new(2, 3)
model.set_weight(0, 0, 0.5)
model.set_transition(0, 1, -0.4)
let features : Array[Array[Int]] = [[0, 1], [1, 2]]
let log_z = model.log_partition(features)
let marginals = model.marginals(features)
```

`marginals` 返回每个位置每个标签的后验概率，每行都会归一化到 1。

## Viterbi 解码

```moonbit
let result = model.viterbi(features)
println(result.labels())
println(result.score())
```

平局时选择较小的标签 ID，保证解码结果确定。

## L-BFGS 优化器

`minimize` 是一个独立的 L-BFGS 最小化器：传入初始参数和一个返回“目标函数值 + 梯度”的回调即可，不依赖 CRF 模型，便于单独测试和复用。

```moonbit
let result = @mooncrf.minimize([1.0, 1.0], quadratic)
println(result.converged())
println(result.iterations())
```

实现使用 two-loop recursion、Armijo 回溯线搜索，并在首步按梯度范数缩放步长。

## 训练与预测

`CrfTrainer` 用模板集把 CoNLL 数据集编码，并用带 L2 正则的负对数似然训练模型：

```moonbit
let dataset = @mooncrf.Dataset::from_conll("a X
b Y
")
let templates = @mooncrf.TemplateSet::parse(["%x[0,0]"])
let trainer = @mooncrf.CrfTrainer::from_dataset(dataset, templates)
let result = trainer.train(l2=0.01)
let labels = trainer.predict(result.model(), ["a", "b"])
```

预测时复用训练阶段的特征索引，未知特征会被跳过，不会改变模型参数布局。

## 评测

`evaluate` 对比 gold 与预测标签序列，返回 token 准确率和 micro 平均的精确率、召回率、F1：

```moonbit
let metrics = @mooncrf.evaluate(["X", "Y"], ["X", "X"])
println(metrics.accuracy())
println(metrics.f1())
```

## 保存与加载

`ModelBundle` 把模型、模板字符串、特征索引和标签索引一起保存为 JSON：

```moonbit
let bundle = trainer.to_bundle(result.model())
let text = bundle.to_json_string()
let loaded = @mooncrf.ModelBundle::from_json_string(text)
let labels = loaded.predict(["a", "b"])
```

## 命令行工具

```bash
moon run cmd/main -- train examples/sample.conll examples/sample.model.json --l2 0.01 --iterations 100
moon run cmd/main -- predict examples/sample.model.json examples/sample.conll
moon run cmd/main -- eval examples/sample.model.json examples/sample.conll
```

`examples/sample.conll` 是一个很小的 NER 风格示例数据，可直接用来跑通全流程。

## 参考与许可证

CRF 公式参考 Lafferty、McCallum、Pereira 的 *Conditional Random Fields: Probabilistic Models for Segmenting and Labeling Sequence Data*（ICML 2001）。

[CRFsuite](https://github.com/chokkan/crfsuite)（BSD-3-Clause）作为特征模板和训练行为参考；`mooncrf` 是独立的 MoonBit 实现，不包含 CRFsuite 源码。

本项目使用 Apache-2.0 许可证，详见 [LICENSE](LICENSE)。
