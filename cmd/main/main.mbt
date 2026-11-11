///|
fn default_templates() -> Array[String] {
  ["%x[0,0]", "%x[-1,0]/%x[0,0]", "%x[0,0]/%x[1,0]"]
}

///|
fn print_usage() -> Unit {
  println("mooncrf - 线性链 CRF 序列标注工具")
  println("")
  println("用法：")
  println(
    "  mooncrf train <data.conll> <model.json> [--l2 0.01] [--iterations 200]",
  )
  println("  mooncrf predict <model.json> <data.conll>")
  println("  mooncrf eval <model.json> <data.conll>")
  println("")
  println(
    "数据格式：每行 `token label`，空行分隔序列，# 开头为注释。",
  )
}

///|
fn main {
  let args = @env.args()
  run(args) catch {
    err => println("错误：\{err}")
  }
}

///|
fn run(args : Array[String]) -> Unit raise Error {
  if args.length() < 2 {
    print_usage()
    return
  }
  match args[1] {
    "train" => run_train(args)
    "predict" => run_predict(args)
    "eval" => run_eval(args)
    "help" | "--help" | "-h" => print_usage()
    _ => {
      println("未知命令：\{args[1]}")
      print_usage()
    }
  }
}

///|
fn run_train(args : Array[String]) -> Unit raise Error {
  if args.length() < 4 {
    println(
      "用法：mooncrf train <data.conll> <model.json> [--l2 0.01] [--iterations 200]",
    )
    return
  }
  let data_path = args[2]
  let model_path = args[3]
  let mut l2 = 0.01
  let mut iterations = 200
  let mut i = 4
  while i + 1 < args.length() {
    match args[i] {
      "--l2" => {
        l2 = @string.parse_double(args[i + 1][:])
        i += 2
      }
      "--iterations" => {
        iterations = @string.parse_int(args[i + 1][:])
        i += 2
      }
      _ => {
        println("未知参数：\{args[i]}")
        return
      }
    }
  }
  let text = @fs.read_file_to_string(data_path)
  let dataset = @lib.Dataset::from_conll(text)
  let templates = @lib.TemplateSet::parse(default_templates())
  let trainer = @lib.CrfTrainer::from_dataset(dataset, templates)
  let options = @lib.LbfgsOptions::new(max_iterations=iterations)
  let result = trainer.train(options~, l2~)
  let bundle = trainer.to_bundle(result.model())
  @fs.write_string_to_file(model_path, bundle.to_json_string())
  println(
    "训练完成：序列=\{dataset.len()} 特征=\{trainer.num_features()} 标签=\{trainer.num_labels()} 迭代=\{result.iterations()} 目标值=\{result.objective()} 收敛=\{result.converged()}",
  )
  println("模型已写入 \{model_path}")
}

///|
fn run_predict(args : Array[String]) -> Unit raise Error {
  if args.length() < 4 {
    println("用法：mooncrf predict <model.json> <data.conll>")
    return
  }
  let model_path = args[2]
  let data_path = args[3]
  let bundle = @lib.ModelBundle::from_json_string(
    @fs.read_file_to_string(model_path),
  )
  let dataset = @lib.Dataset::from_conll(@fs.read_file_to_string(data_path))
  for sequence in dataset.sequences() {
    let predicted = bundle.predict(sequence.tokens().to_owned())
    for i in 0..<predicted.length() {
      println("\{sequence.tokens()[i]}\t\{predicted[i]}")
    }
    println("")
  }
}

///|
fn run_eval(args : Array[String]) -> Unit raise Error {
  if args.length() < 4 {
    println("用法：mooncrf eval <model.json> <data.conll>")
    return
  }
  let model_path = args[2]
  let data_path = args[3]
  let bundle = @lib.ModelBundle::from_json_string(
    @fs.read_file_to_string(model_path),
  )
  let dataset = @lib.Dataset::from_conll(@fs.read_file_to_string(data_path))
  let gold : Array[String] = []
  let predicted : Array[String] = []
  for sequence in dataset.sequences() {
    let labels = bundle.predict(sequence.tokens().to_owned())
    for i in 0..<labels.length() {
      gold.push(sequence.labels()[i])
      predicted.push(labels[i])
    }
  }
  let metrics = @lib.evaluate(gold, predicted)
  println("accuracy=\{metrics.accuracy()}")
  println("precision=\{metrics.precision()}")
  println("recall=\{metrics.recall()}")
  println("f1=\{metrics.f1()}")
  println("support=\{metrics.support()}")
}
