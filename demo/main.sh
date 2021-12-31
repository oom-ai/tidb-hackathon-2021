#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

info() { printf "%b[info]%b %s\n" '\e[0;32m\033[1m' '\e[0m' "$*" >&2; }

SDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) && cd "$SDIR" || exit 1
export OOMCLI_CONFIG="$SDIR/oomcli.yaml"

RECIPE=fraud_detection.yaml
ID_START=1000
ID_END=1099
ID_RANGE=$ID_START..$ID_END
TIME_RANGE_START=$(perl -MTime::Piece -MTime::Seconds -le 'print((Time::Piece->new + ONE_DAY)->ymd)')
TIME_RANGE_END=$(perl -MTime::Piece -MTime::Seconds -le 'print((Time::Piece->new + ONE_DAY * 2)->ymd)')
TIME_RANGE=$TIME_RANGE_START..$TIME_RANGE_END
LABEL_LIMIT=100

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
ffgen schema --recipe $RECIPE > oomstore.yaml

info "populate oomstore with generated data..."
rm -f oomstore.db
oomcli init
oomcli apply -f oomstore.yaml

r1=$(oomcli import \
  --group account \
  --input-file account.csv \
  --description 'sample account data' | grep -o '[0-9]\+')
oomcli sync -r "$r1"

r2=$(oomcli import \
  --group transaction_stats \
  --input-file transaction_stats.csv \
  --description 'sample transaction stat data' | grep -o '[0-9]\+')
oomcli sync -r "$r2"

info "model training and offline feature point-in-time join..."

oomcli join \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --input-file label.csv \
  --output csv \
  | cut -d',' -f3- \
  > fraud_detection_train.csv

tangram train --file fraud_detection_train.csv --target is_fraud --output fraud_detection.tangram

info "model serving and online feature get..."

for ((key = ID_START; key <= ID_END; key++)); do
oomcli get online \
  --entity-key "$key" \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --output csv | tail -n +$((key != ID_START))
done | tangram predict --model fraud_detection.tangram > pred.csv
