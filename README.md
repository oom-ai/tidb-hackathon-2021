# RFC: OOM 特征平台 ❤️ TiDB & TiKV

By [jinghancc](https://github.com/jinghancc), 
[lianxmfor](https://github.com/lianxmfor), 
[wfxr](https://github.com/wfxr), 
[yiksanchan](https://github.com/yiksanchan)

Find English version [here](./README.EN.md).
## 概述

OOM 特征平台为机器学习模型的训练和服务提供便捷可靠的特征支持，让用户以最小的代价落地机器学习。
为了最大程度地兼容团队现有的技术选型，OOM 特征平台支持包括云数仓和开源数据库在内的多种后端。

在本次 Hackathon 中，我们支持 TiDB 和 TiKV 作为 OOM 特征平台的后端，让 TiDB 和 TiKV 的用户也能享受到特征平台带来的便利。

## 动机

机器学习支撑起了今天互联网最赚钱的场景，包括搜索、推荐和广告。
业务场景中机器学习的迭代速度决定了业务的增长速度。

然而，高效地迭代机器学习是一件很难的事，主要因为数据问题很难解决。

> Data is the hardest part of ML and the most important piece to get right.
>
> -- Uber Michelangelo

机器学习系统需要处理两类很不同的负载——离线训练和在线服务。
离线训练场景侧重高吞吐，在线服务侧重低延迟，因而很自然需要 OLAP 和 KV 这两类不同的存储。

|          | 离线训练           | 在线服务      |
| -------- | ------------------ | ------------- |
| 运算     | Point-in-time Join | Key-based Get |
| 数据类别 | 历史特征           | 最新特征      |
| 数据大小 | 超大               | 小            |
| 数据库   | OLAP               | KV            |

在企业内，这两类存储和与之相关的业务逻辑通常由不同团队维护。一个常见的合作方式是：

- 算法工程师从数仓获取数据，实现特征工程，训练模型，把训练好的模型交给在线服务团队。
- 在线服务团队从在线数据源获取数据，（用不同的编程语言）重新实现特征工程，将特征输入给模型，产生预测。

通过跨团队的合作维护这样一个大型系统，会带来很多问题：

- 用于离线训练的特征和用于在线服务的特征来源不同，一致性很难保证。
- 数据和代码分散在各个团队，难以集中进行管理。

特征平台是业界为了解决这一问题逐渐形成的实践。
目前，各个大厂都有不同形态的解决方案，但开源的解决方案很少。
我们相信，一个优秀的开源特征平台能帮助中小团队快速地落地机器学习能力。

由于特征平台概念还很早期，现有的开源特征平台主要存在两类问题：

- 与存储捆绑。Hopswork / OpenMLDB 都只支持很有限的存储，且在设计时没有考虑存储组件的可插拔，难以拓展。
- 性能不足。Feast 由 Python 实现，很难满足在线服务对性能的需求。

OOM 特征平台实现了高性能和可插拔这两个重要设计目标：

- 高性能：使用 Go 实现，设计了符合特征平台需求的数据存储结构，尽量不引入外部复杂组件（例如 Spark）。
- 可插拔：支持各式常见的优秀存储，且容易通过实现 Store 接口进行拓展。
  - Online store: DynamoDB, Redis, Cassandra, PostgreSQL, MySQL, SQLite.
  - Offline store: Snowflake, Redshift, BigQuery, PostgreSQL, MySQL, SQLite.
  - Metadata store: PostgreSQL, MySQL, SQLite.

TiDB 和 TiKV 是 PingCAP 主导开发的两款优秀的开源数据库，且与 OOM 特征平台十分契合——TiDB 具有 AP 能力，而 TiKV 是高性能 KV。

在本次 Hackathon 中，我们将在 OOM 特征平台增加对 TiDB 和 TiKV 的支持。一方面，TiDB 和 TiKV 的用户可以以极低的成本享受到特征平台带来的好处；另一方面，也希望让 OOM 特征平台的用户了解到 TiDB 和 TiKV 的优秀，转化为 TiDB 和 TiKV 的用户。

## 相关链接

代码仓库：[oom-ai/oomstore](https://github.com/oom-ai/oomstore)

文档：[oom.ai](https://oom.ai)
