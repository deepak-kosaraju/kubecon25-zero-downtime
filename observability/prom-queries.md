# Prom Query Learning

## Prom explorer

```sh
# # sum by (envoy_response_code,envoy_cluster_name) (envoy_cluster_upstream_rq_xx{envoy_cluster_name=~".+"}) / sum by (envoy_cluster_name) (envoy_cluster_upstream_rq_total{envoy_cluster_name=~".+"}) * 100
# sum by (envoy_response_code, envoy_cluster_name) (envoy_cluster_upstream_rq) 
# / 
# on(envoy_cluster_name) group_left() 
# sum by (envoy_cluster_name) (envoy_cluster_upstream_rq) 
# * 
# 100
# sum by (envoy_response_code) (envoy_cluster_upstream_rq{envoy_cluster_name="monolith-backend", envoy_response_code=~"500|503|504|502"}) / on(envoy_cluster_name)group_left() sum(envoy_cluster_upstream_rq{envoy_cluster_name="monolith-backend"}) * 100
# 100* sum(envoy_cluster_upstream_rq_total{envoy_cluster_name="asg-web-pool"}) / (sum(envoy_cluster_upstream_rq_total{envoy_cluster_name="monolith-backend"}))
100* sum(rate(envoy_cluster_upstream_rq_total{envoy_cluster_name=~"asg-web-pool,k8s-web-pool"}[1m])) by (envoy_cluster_name) / on(envoy_cluster_name) group_left() (sum(rate(envoy_cluster_upstream_rq_total{envoy_cluster_name="monolith-backend"}[1m])))
# sum by (envoy_response_code) (envoy_cluster_upstream_rq{envoy_cluster_name="monolith-backend", envoy_response_code=~"500|503|504|502"}) / on() group_left() sum(envoy_cluster_upstream_rq{envoy_cluster_name="monolith-backend"}) * 100
# Explanation:
# envoy_cluster_upstream_rq_xx{envoy_cluster_name=~".+"}: This part selects the counter metrics for upstream requests with specific HTTP response codes (e.g., envoy_cluster_upstream_rq_2xx, envoy_cluster_upstream_rq_3xx, envoy_cluster_upstream_rq_4xx, envoy_cluster_upstream_rq_5xx). The envoy_cluster_name=~".+" label matcher ensures all upstream clusters are included.
# sum by (envoy_cluster_name, envoy_response_code): This aggregates the selected response code counters by both the envoy_cluster_name and the envoy_response_code labels, providing the count of each response code for each cluster.
# envoy_cluster_upstream_rq_total{envoy_cluster_name=~".+"}: This selects the total upstream requests counter for all clusters.
# sum by (envoy_cluster_name): This aggregates the total requests by envoy_cluster_name, giving the total number of requests for each cluster.
# /: Dividing the sum of specific response codes by the sum of total requests for each cluster calculates the ratio.
# * 100: Multiplies the ratio by 100 to express the result as a percentage.
# This query will return a series of percentages, where each series represents the percentage of a specific envoy_response_code for a given envoy_cluster_name in relation to the total requests handled by that cluster.
```

## Grafana Explore

```sh
# Stacked Graph
sum by (envoy_response_code,envoy_cluster_name) (rate(envoy_cluster_upstream_rq{envoy_response_code=~"2..|304"}[5m])) / on (envoy_cluster_name) group_left() sum by (envoy_cluster_name)(rate(envoy_cluster_upstream_rq[5m])) * 100
sum by (envoy_response_code,envoy_cluster_name) (rate(envoy_cluster_upstream_rq{envoy_response_code=~"5.."}[5m])) / on (envoy_cluster_name) group_left() sum by (envoy_cluster_name)(rate(envoy_cluster_upstream_rq[5m])) * 100
sum by (envoy_response_code,envoy_cluster_name) (rate(envoy_cluster_upstream_rq{envoy_response_code=~"4.."}[5m])) / on (envoy_cluster_name) group_left() sum by (envoy_cluster_name)(rate(envoy_cluster_upstream_rq[5m])) * 100
sum by (envoy_response_code,envoy_cluster_name) (rate(envoy_cluster_upstream_rq{envoy_response_code=~"3..",envoy_response_code!~"304" }[5m])) / on (envoy_cluster_name) group_left() sum by (envoy_cluster_name)(rate(envoy_cluster_upstream_rq[5m])) * 100
```
