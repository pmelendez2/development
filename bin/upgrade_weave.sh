helm upgrade \
--set rbac.create=true \
--set helmOperator.create=true \
--set git.url=git@github.com:tidepool-org/dev-ops \
--set git-poll-interval=1m \
--set update-chart-deps=false \
--namespace flux \
flux weaveworks/flux
