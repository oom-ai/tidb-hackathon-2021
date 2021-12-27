# RFC: OOM Feature Store ❤️ TiDB & TiKV

Authors: [jinghancc](https://github.com/jinghancc), 
[lianxmfor](https://github.com/lianxmfor), 
[wfxr](https://github.com/wfxr), 
[yiksanchan](https://github.com/yiksanchan)

## Overview

In this RFC, we walk through why are TiDB/TiKV and OOM Feature Store better together by allowing users to productionize ML with minimal efforts,
and how do we design OOM Feature Store to fulfill this mission. 

## Motivation

ML powers the most monetized use cases in the current web, including but not limited to search, recommenders, and ads.
The better your ML pipelines are, the faster your business grows.

However, running ML in production is hard, among which managing data is the hardest.
The 2 most common workloads in ML - offline model training and online model serving -
are very different workloads thus requiring very different data infrastructures.

|            | Offline Training    | Online Serving      |
|------------|---------------------|---------------------|
| Data type  | Historical features | Up-to-date features |
| Data size  | Large               | Small               |
| Data store | Data warehouse      | KV                  |
| Data op    | Point-in-time Join  | Key-based Get       |

OOM Feature Store provides just 1 interface to serve both needs.
Under the hood, it supports various storages to seamlessly fit into users' existing data infrastructures.

TiDB and TiKV users should not be ignored. By bringing OOM Feature Store onto TiDB and TiKV, we are hoping to help TiDB users to succeed with faster ML iterations. And we believe, TiDB and OOM ecosystems are better together.

## Design

TODO
