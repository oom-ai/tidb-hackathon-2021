# generate fake data

ffgen group account -I 1000..1099 -r fraud_detection.yaml > account.csv
ffgen group transaction_stats -I 1000..1099 -r fraud_detection.yaml > transaction_stats.csv
ffgen label target -r fraud_detection.yaml -I 1000..1099 -l 100 -T $(date -v +1d +'%Y-%m-%d')..$(date -v +2d +'%Y-%m-%d') > label.csv

# populate oomstore with generated data

rm /tmp/oomstore.db
oomcli init
oomcli apply -f config.yml
r1=$(oomcli import \
  --group account \
  --input-file account.csv \
  --description 'sample account data' | grep -o '[0-9]\+')
oomcli sync -r $r1
r2=$(oomcli import \
  --group transaction_stats \
  --input-file transaction_stats.csv \
  --description 'sample transaction stat data' | grep -o '[0-9]\+')
oomcli sync -r $r2

# model training and offline feature point-in-time join

oomcli join \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --input-file label.csv \
  --output csv \
  | cut -d',' -f3- \
  > fraud_detection_train.csv

tangram train --file fraud_detection_train.csv --target is_fraud --output fraud_detection.tangram

# model serving and online feature get

(
echo "user,account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d"
for i in {1000..1099}
do
oomcli get online \
  --entity-key $i \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --output csv \
  | sed -n '2 p'
done
) | tangram predict --model fraud_detection.tangram > pred.csv
