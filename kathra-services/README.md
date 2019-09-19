# Dry run
`helm template --tiller-namespace factory --namespace test-kathra -n test-kathra -f secret_values.yaml . > output.yaml`
# Installation
`helm install --tiller-namespace factory --namespace test-kathra -n test-kathra -f secret_values.yaml .`