# generate fake data

ffgen group account -I 1000..1100 -r fraud_detection.yaml > account.csv
ffgen group transaction_stats -I 1000..1100 -r fraud_detection.yaml > transaction_stats.csv
ffgen label target -r fraud_detection.yaml -I 1000..1100 -l 100 -T 2022-01-01..2022-01-02 > label.csv

# populate oomstore with generated data

oomcli init
oomcli apply -f config.yml
oomcli import \
  --group account \
  --input-file account.csv \
  --description 'sample account data'
oomcli import \
  --group transaction_stats \
  --input-file transaction_stats.csv \
  --description 'sample transaction stat data'

# model training and offline feature point-in-time join

oomcli join \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --input-file label.csv \
  --output csv \
  | cut -d',' -f3- \
  > fraud_detection_train.csv

tangram train --file fraud_detection_train.csv --target is_fraud

# model serving and online feature get

(
echo "user,account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d"
for i in {1000..1100}
do
oomcli get online \
  --entity-key $i \
  --feature account.state,account.credit_score,account.account_age_days,account.has_2fa_installed,transaction_stats.transaction_count_7d,transaction_stats.transaction_count_30d \
  --output csv \
  | sed -n '2 p'
done
) | tangram predict --model fraud_detection.tangram
