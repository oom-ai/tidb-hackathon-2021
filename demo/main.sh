#!/usr/bin/env bash
set -eu
IFS=$'\n\t'

info() { printf "%b[info]%b %s\n" '\e[0;32m\033[1m' '\e[0m' "$*" >&2; }

SDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) && cd "$SDIR" || exit 1
export OOMCLI_CONFIG="$SDIR/oomcli.yaml"

RECIPE=fraud_detection.yaml
ID_START=1001
ID_END=2000
ID_RANGE=$ID_START..$ID_END
TIME_RANGE_START=$(perl -MTime::Piece -MTime::Seconds -le 'print((Time::Piece->new + ONE_DAY)->ymd)')
TIME_RANGE_END=$(perl -MTime::Piece -MTime::Seconds -le 'print((Time::Piece->new + ONE_DAY * 2)->ymd)')
TIME_RANGE=$TIME_RANGE_START..$TIME_RANGE_END
LABEL_LIMIT=5000
# shellcheck disable=SC2207
PRED_SAMPLE=($(seq $ID_START $ID_END | sort -R | head -20))

info "generate fake group data..."
ffgen group account \
    --seed 0 \
    --recipe $RECIPE \
    --id-range $ID_RANGE \
    > account.csv
ffgen group transaction_stats \
    --seed 0 \
    --recipe $RECIPE \
    --id-range $ID_RANGE \
    > transaction_stats.csv

info "generate fake label data..."
ffgen label target \
    --seed 0 \
    --recipe $RECIPE \
    --id-range $ID_RANGE \
    --time-range "$TIME_RANGE" \
    --limit "$LABEL_LIMIT" > label.csv

info "generate oomstore schema..."
# uncomment this until oomplay is fixed
# currently entity length is limited to 2
# ffgen schema --recipe $RECIPE > oomstore.yaml

info "initialize oomstore..."
oomplay init tidbext tikvext

# give it 5 times to try
for _i in {1..5}; do
    oomcli init && break
    sleep 2
done

oomcli apply -f oomstore.yaml

info "populate oomstore with generated data..."

r1=$(oomcli import \
  --group account \
  --input-file account.csv \
  --description 'sample account data' | grep -o 'RevisionID: [0-9]\+' | awk -F" " '{print $2}')
oomcli sync -r "$r1"

r2=$(oomcli import \
  --group transaction_stats \
  --input-file transaction_stats.csv \
  --description 'sample transaction stat data' | grep -o 'RevisionID: [0-9]\+' | awk -F" " '{print $2}')
oomcli sync -r "$r2"

info "point-in-time join on offline store..."
oomcli join \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --input-file label.csv \
  --output csv \
  | cut -d',' -f3- \
  > fraud_detection_train.csv

info "train the model..."
tangram train --file fraud_detection_train.csv --target is_fraud --output fraud_detection.tangram

info "get by key from online store and make prediction from the model..."
for key in "${PRED_SAMPLE[@]}"; do
    oomcli get online \
      --entity-key "$key" \
      --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
      --output csv | if (( key == ID_START )); then tail -2; else tail -1; fi
done | tangram predict --model fraud_detection.tangram > pred.csv
