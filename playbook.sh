#!/usr/bin/env bash

# PRE
export OOMCLI_CONFIG="$PWD/oomcli.yaml"
export FEATURE_LIST=account.state,account.credit_score,account.account_age_days,account.2fa_installed,txn_stats.count_7d,txn_stats.count_30d
asciinema rec demo.cast --overwrite
function # { }

# initialize tidb and tikv playground
oomplay init tidb tikv

# initialize oomstore based on tikv and tidb
cat oomcli.yaml
oomcli init --config oomcli.yaml

# register features into feature store
cat features.yaml
oomcli apply -f features.yaml
oomcli get meta feature

# import feature data into offline store
head account.csv | csview
head transaction_stats.csv | csview
oomcli import --group account --input-file account.csv --description 'sample user data'
oomcli import --group txn_stats --input-file transaction_stats.csv  --description 'sample transaction stats data'
oomcli get meta revision

# sync data from offline store into online store
oomcli sync -r 1 && oomcli sync -r 2

# generate tranning data using point-in-time join from labels
head label.csv | csview
wc -l label.csv
cat feature_list
oomcli join --feature $FEATURE_LIST --input-file label.csv --output csv | xsv select "is_fraud,$FEATURE_LIST" > train.csv
head train.csv | csview

# train the model using tangram
tangram train --file train.csv --target is_fraud --output model

# get feature value from online store with keys from 1001 to 2000
oomcli get online --feature $FEATURE_LIST --output csv -k $(seq 1001 2000 | paste -sd,)  > query.csv
wc -l query.csv
head query.csv | csview

# predict fraud class
tangram predict --model model -f query.csv > pred.csv
head pred.csv | csview

oomplay stop tikv tidb

# 1955
