# monitoring_deploy

## 方案
### 方案简述
本项目实现了Prometheus（为了方便，下文均采用简称：Prome）监控方案的快速部署。

```

    Prometheus方案
    - 数据收集：
        主机信息采集	Prometheus node_exporter
        硬件信息采集	Prometheus snmp_exporter
        应用信息采集	Prometheus blackbox_exporter
        事务性数据采集	Prometheus pushgateway
    - 数据存储：
        InfluxDB
    - 数据查询：
        Prometheus Server
    - 告警管理：
        Prometheus Alert Manager
    - 告警发送：
        钉钉告警	webhook-dingtalk
        电话短信告警	alertmanager-webhook
    - 展示：
        Grafana

```

### 架构图


Prometheus联邦集群架构图


![](https://github.com/sunnywalden/prometheus_management_ansible/raw/master/pictures/prometheus_arctecture.png)

## Installation

Dillinger requires [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html?extIdCarryOver=true&sc_cid=701f2000001OH6uAAG#latest-release-via-dnf-or-yum) v2.7+ to run.

Install the dependencies and devDependencies and clone the project.


### 配置文件管理
 

#### 部署组件配置
#### webhook dingtalk配置
##### 必须修改的配置
###### vars路径下全局配置
位于vars/all.yml,主要包括组件部署配置及启动项配置。
参考:

```

#安装配置，不建议修改
tmp_dir: "/tmp"
base_path: "/data/application"

#请勿改动
pid_path: "/data/run"
log_path: "/data/log"

#依赖部署版本，请勿改动
gosu_version: 1.11

#部署版本，请留意版本变更说明。
nodeexporter_version: "0.17.0-rc.0"
dingtalk_version: "0.3.0"
alertmanager_version: "0.15.2"
blackbox_version: "0.13.0"
pushgateway_version: "0.6.0"
snmp_version: "0.14.0"
prometheus_version: "2.5.0"

#端口规划
influx_port: 8086
dingtalk_port: 8060
webhook_port: 7879
nodeexporter_port: 9100
alertmanager_port: 9093
alertmanager_cluster_port: 9094
blackbox_port: 9115
pushgateway_port: 9091
snmp_port: 9116
prometheus_port: 9090
grafana_port: 3000

#部署用户
prometheus_user: "prometheus"
prometheus_group: "prometheus"


#域名配置
prometheus_site_proto: 'https'
prometheus_site: 'prom.demo.com'
prometheus_prefix: 'prome'
alertmanager_prefix: 'am'
dingtalk_prefix: "webhook"
grafana_prefix: ""


influxdb_prometheus_database: "prometheus"

#告警群组
dingtalk_webhooks:
  default: ""
  devops: ""
  servers: ""

## 告警检测值平均值的计算时长
evalue_time:
  INFO: 1m
  WARNING: 10m
  CRITICAL: 20m

```

###### vars路径下各组件的配置
位于vars/[组件名称].yml,主要包括组件部署配置及启动项配置。
参考vars/prometheus.yml：

```

---

#安装配置，请勿修改。
prometheus_install_path: "{{ base_path }}/prometheus"
prometheus_config_path: "{{ prometheus_install_path }}"
prometheus_rule_path: "{{ prometheus_install_path }}/rules"
prometheus_console_libs_path: "{{ prometheus_install_path }}/console_libraries"
prometheus_consoles_path: "{{ prometheus_install_path }}/consoles"
prometheus_data_path: "{{ prometheus_install_path }}/data"
prometheus_file_sd_path: "{{ prometheus_install_path }}/file_ds"

##configure params for startup
#反向代理域名，请勿修改。
web_external_url: "{{ prometheus_site_proto }}://{{ prometheus_site }}/{{ prometheus_prefix }}"
#使用反向代理时的子路由
web_route_prefix: ""
log_level: "error"
snmp_scrape_interval: 120s
snmp_scrape_timeout: 120s

```

###### 与主机绑定配置

位于host_vars/[IP地址],主要为主机级别的全局配置，被多个组件共享。
参考host_vars/192.168.1.33：

```
#组件部署规划
influx_host: "192.168.1.32"
webhook_hosts: "192.168.1.33"
dingtalk_hosts: ["192.168.1.33"]
alertmanager_hosts: ["192.168.1.33","192.168.1.34"]
pushgateway_hosts: ["192.168.1.33"]
snmp_hosts: "192.168.1.33"
blackbox_hosts: "10.1.5.17"
grafana_hosts: "192.168.1.32"
prometheus_hosts: ["192.168.1.33","192.168.1.34"]

#alertmanager集群配置
cluster_peer: "192.168.1.34"

#alertmanager组件配置
alertmanager_subroute:
  - receiver: "devops"
    group_wait: "30s"
    group_interval: "30s"
    repeat_interval: "30s"
    match_re:
      job: "influxdb|grafana|alertmanager|push_gateway|snmp_exporter|prometheus|blackbox_exporter|nodes"
      severity: "INFO|info"
  - receiver: "voiceops"
    group_wait: "30s"
    group_interval: "270s"
    repeat_interval: "24h"
    match_re:
      job: "^blackbox_.*$"
      severity: "CRITICAL|critical"
  - receiver: "smsops"
    group_wait: "30s"
    group_interval: "150s"
    repeat_interval: "570s"
    match_re:
      job: "^blackbox_.*$"
      severity: "WARNING|warning"
  - receiver: "servers"
    group_wait: "30s"
    group_interval: "30s"
    repeat_interval: "30s"
    match_re:
      job: "^blackbox_.*$"
      severity: "INFO|info"

```
 

##### 默认配置
roles路径下各组件的配置,位于roles/[组件名称]/defaults/main.yml，为默认配置，一般不需要修改。参考roles/prometheus/defaults/main.yml：

```

---

#安装配置，不建议修改
tmp_dir: "/tmp"
base_path: "/data/application"

#请勿改动
pid_path: "/data/run"
log_path: "/data/log"

#依赖部署版本，请勿改动
gosu_version: 1.11

pushgateway_version: "0.6.0"

#influxdb部署版本（与influxdb部署保持配置一致），不建议改动
influx_port: 8086

#alertmanager部署端口，与alertmanager部署保持配置一致
alertmanager_port: 9093
alertmanager_cluster_port: 9094

#pushgateway部署端口，与pushgateway部署保持配置一致
pushgateway_port: 9091

#nodeexporter部署端口，与nodeexporter部署保持配置一致
nodeexporter_port: 9100

#blackbox_exporter部署端口，与blackbox_exporter部署保持配置一致
blackbox_port: 9115

#snmp_exporter部署端口，与snmp_exporter部署保持配置一致
snmp_port: 9116

#influxdb prometheus用数据库
influxdb_prometheus_database: "prometheus"

#部署用户
prometheus_user: "prometheus"
prometheus_group: "prometheus"

#influxdb服务主机
influx_host: '192.168.1.32'

#nodeexporter部署的版本
nodeexporter_version: "0.17.0-rc.0"

#安装配置，请勿修改。
prometheus_install_path: "{{ base_path }}/prometheus"
prometheus_config_path: "{{ prometheus_install_path }}"
prometheus_rule_path: "{{ prometheus_install_path }}/rules"
prometheus_console_libs_path: "{{ prometheus_install_path }}/console_libraries"
prometheus_consoles_path: "{{ prometheus_install_path }}/consoles"
prometheus_data_path: "{{ prometheus_install_path }}/data"
prometheus_file_sd_path: "{{ prometheus_install_path }}/file_ds"

##configure params for startup
web_read_timeout: "5m"
web_max_connections: 512

#反向代理域名，请勿修改。
web_external_url: "{{ prometheus_site_proto }}://{{ prometheus_site }}/{{ prometheus_prefix }}"

#使用反向代理时的子路由
web_route_prefix: ""

#用户资产访问路径，默认/user。
web_user_assets: ""

#启用关闭与配置重载API
web_enable_lifecycle: false

#启动adminAPI
web_enable_admin_api: true

#本地存储配置，未启用。
storage_tsdb_retention: "3d"
#alertmanager部署主机列表
storage_tsdb_no_lockfile: false

#远端写时限
storage_remote_flush_deadline: "1m"

#远程读数据大小限制
storage_remote_read_sample_limit: 5e7

#远程读并发限制
storage_remote_read_concurrent_limit: 10

rules_alert_for_outage_tolerance: "1h"
rules_alert_for_grace_period: "10m"
rules_alert_resend_delay: "1m"

alertmanager_notification_queue_capacity: 10000
alertmanager_timeout: "10s"

query_lookback_delta: "5m"
query_timeout: "5m"
query_max_concurrency: 100
query_max_samples: 50000000

log_level: "error"

snmp_scrape_interval: 120s
snmp_scrape_timeout: 120s

```

#### pushgateway配置
##### 必须修改的配置
###### vars路径下的配置
位于vars/pushgateway.yml，参考：

```

---

#安装配置，请勿修改
pushgateway_install_path: "{{ base_path }}/pushgateway"
pushgateway_daemon_dir: "{{ pushgateway_install_path }}"
pushgateway_config_path: "{{ pushgateway_install_path }}"
pushgateway_db_path: "{{ pushgateway_install_path  }}"

#暴露metrics的路径,不建议修改
web_telemetry_path: "/metrics"

#反向代理路径
web_route_prefix: ""

#metrics持久化存储的文件
persistence_file: ""

#metrics存储到文件的频率
persistence_interval: "5m"

#日志配置
log_level: "error"
log_format: "logger:stderr"

```

##### 默认配置
修改roles路径下组件的配置（位于roles/pushgateway/defaults/main.yml）。默认配置，可忽略，文档中不再展示。



#### prometheus配置
##### 必须修改的配置

###### 安装与启动配置
修改vars路径下组件的配置（位于vars/prometheus.yml）。参考：

```
---


#安装配置，请勿修改。
prometheus_install_path: "{{ base_path }}/prometheus"
prometheus_config_path: "{{ prometheus_install_path }}"
prometheus_rule_path: "{{ prometheus_install_path }}/rules"
prometheus_console_libs_path: "{{ prometheus_install_path }}/console_libraries"
prometheus_consoles_path: "{{ prometheus_install_path }}/consoles"
prometheus_data_path: "{{ prometheus_install_path }}/data"
prometheus_file_sd_path: "{{ prometheus_install_path }}/file_ds"

##configure params for startup
#反向代理域名，请勿修改。
web_external_url: "{{ prometheus_site_proto }}://{{ prometheus_site }}/{{ prometheus_prefix }}"
#使用反向代理时的子路由
web_route_prefix: ""
log_level: "error"
snmp_scrape_interval: 120s
snmp_scrape_timeout: 120s

#应用监控
blackbox_job:
  - job_name: 'blackbox_app'
    metrics_path: /probe
    params:
      module: [app]  # rong-boot qos
    static_configs:
      - targets:
        - http://192.168.1.38:9007/applica
        labels:
          app_name: user-services
          env: prod
          team: sales
          ...


```
###### 全局配置

vars/all.yml prometheus相关配置，参考：

```
#请勿改动
pid_path: "/data/run"
log_path: "/data/log"

#依赖部署版本，请勿改动
gosu_version: 1.11

#部署版本，请留意版本变更说明。
prometheus_version: "2.5.0"

#端口规划
influx_port: 8086
dingtalk_port: 8060
webhook_port: 7879
nodeexporter_port: 9100
alertmanager_port: 9093
alertmanager_cluster_port: 9094
blackbox_port: 9115
pushgateway_port: 9091
snmp_port: 9116
prometheus_port: 9090
grafana_port: 3000

#部署用户
prometheus_user: "prometheus"
prometheus_group: "prometheus"


#域名配置
prometheus_site_proto: 'https'
prometheus_site: 'prom.demo.com'
prometheus_prefix: 'prome'
alertmanager_prefix: 'am'


influxdb_prometheus_database: "prometheus"



```

##### 可修改默认配置

修改roles路径下各组件的配置（位于roles/prometheus/defaults/main.yml）。默认配置，可忽略，文档中不再展示。


### 单节点模式部署

   单节点模式，只部署单台Promethues server进行监控指标的采集，且其它组件默认全部部署到同一台主机。此模式适用于不要求高可用或监控主机与应用较少--即采集任务较少的场景。

   部署步骤：

   部署单点prometheus server 请将主机添加到待部署环境对应的iventory/prometheus文件（，并配置prome_type="slave"，其它组件默认部署在prometheus server（可以通过更改iventory配置制定部署到其它主机），可参考下例。
   
 
```
[dev]
192.168.1.35 prome_type="slave" scrape_nodes=true scrape_snmp=true scrape_blackbox=true
[test]
192.168.1.34 prome_type="slave" scrape_nodes=true scrape_snmp=true scrape_blackbox=true
[pro]
192.168.1.33 prome_type="slave" scrape_nodes=true scrape_snmp=true scrape_blackbox=true

```

执行ansible playbook开始部署。
   
```sh
$ ansible-playbook -i iventory/prometheus prometheus.yml -f 200 --key-file=ssh-keys/zhangbo

```


### 联邦集群模式部署
   
   联邦集群模式，适用于混合云场景或监控应用、主机庞大或对有高可用要求的场景。通过部署多台Prometheus server，每台采集不同的应用或不同环境的监控指标，上层的master再将所有server采集的数据采集存储到远端Influxdb，即可提高采集的性能，降低server宕机造成的监控完全不可用问题。

#### 各组件一键部署

   一键部署模式，在配置不同组件待部署的主机后，只需执行一次playbook即可完成联邦集群的部署。
##### 部署主机配置
   请将主机添加到【prometheus-cluster】群组下，并配置prome_type="master"。


iventory配置参考。

```
[dev]
192.168.1.35 prome_type="slave" scrape_nodes=true scrape_snmp=true scrape_blackbox=true
[test]
192.168.1.34 prome_type="slave" scrape_nodes=true scrape_snmp=true scrape_blackbox=true
[pro]
192.168.1.33 prome_type="master"

```

在host_vars下192.168.1.33文件定义：

```
prometheus_node_hosts: ["192.168.1.34", "192.168.1.35"]

```

#### 各组件部署
如果需要部署某个组件，可通过执行此组件的playbook即可。
请修改对应环境iventory文件的主机群组配置。playbook名称指定为对应组件的yml文件即可。
各组件与playbook对应关系如下：
	
	Influxdb	influx.yml
	
	Webhook-dingtalk	dingtalk.yml
	
	Alertmanager	alertmanager.yml
	
	Pushgateway	pushgateway.yml
	
	Node_Exporter nodeexporter.yml
	
	Snmp_Exporter snmp.yml
	
	Blackbox_Exporter blackbox.yml
	
	Prometheus server      prometheus.yml
	
	Grafana      grafana.yml

如部署alertmanager:

```sh
$ ansible-playbook -i iventory/alertmanager alertmanager.yml

```
	
编排主要有环境配置、下载、安装、配置服务及配置更新组成，支持通过tag指定执行局部编排,tag分为部署配置(包含安装前配置与安装后配置二部分，值为components-conf,如alertmanager-conf)、下载(值为components-download,如alertmanager-download)、安装(值为components-install,如alertmanager-install)、服务配置(值为components-service,如alertmanager-service)及配置更新(值为components-conf-update,如alertmanager-conf-update，配置更新包含安装后配置、服务配置)。如alertmanager配置的更新：

```sh
$ ansible-playbook -i iventory/production-single prometheus-monitoring.yml

```
#### HA部署
   Prometheus HA集群的部署，只需要执行多次联邦集群部署的步骤，再通过Nginx配置反向代理即可。
   
   
![](https://github.com/sunnywalden/prometheus_management_ansible/raw/master/pictures/prometheus_arctecture.png)


#### ansible更新组件配置
首先，请根据需求，修改对应组件的vars下的配置项或defaults下的默认配置项。

然后，执行playbook更新修改，通过指定标签为 ”[组件名称]-conf-update“ 实现。如更新alertmanager：

```sh
$ ansible-playbook -i iventory/alertmanager alertmanager.yml -t alertmanager-conf-update
```

#### node_exporter客户端部署

  客户端的部署，可以通过运行ansible playbook批量部署或通过shell脚本部署。

采集指标
##### 开启的采集指标
https://github.com/prometheus/node_exporter#enabled-by-default

 

##### 默认关闭可开启的采集指标
https://github.com/prometheus/node_exporter#disabled-by-default 

##### 资产采集定义的指标 

![](https://github.com/sunnywalden/prometheus_management_ansible/raw/master/pictures/metrics_custom.png)

##### ansible部署
  
  首先，将需要部署的主机IP添加到iventory/node_exporter文件：

```

[test]
192.168.1.34
[dev]
192.168.1.35
[pro]
10.1.1.[1:255]


```
	
然后，修改vars/nodeexporter.yml中变量：

```
---

collectors_settings:
  filesystem.ignored-fs-types: "^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|rootfs|nfs)$"
  filesystem.ignored-mount-points: "^/(dev|proc|sys|boot|run.*|var/lib/kubelet/.+|var/lib/docker/.+|data/docker/overlay)($|/)"
  diskstats.ignored-devices: "^(ram|loop|fd|(h|v)d[a-z]|nvme\\d+n\\d+p|tmpfs|md|up-|sr|rootfs)(\\d*)$"
  netstat.fields: "^(.*_(InErrors|InErrs)|Ip_Forwarding|Ip(6|Ext)_(InOctets|OutOctets)|Icmp6?_(InMsgs|OutMsgs)|TcpExt_(Listen.*|Syncookies.*)|Tcp_(ActiveOpens|PassiveOpens|RetransSegs|CurrEstab)|Udp6?_(InDatagrams|OutDatagrams|NoPorts))$"
  netdev.ignored-devices: "^(tap|cali|docker|veth|tun).*$"
  netclass.ignored-devices: "^(tap|cali|docker|veth|tun).*$"

#需要开启的插件列表
enable_collectors: ["tcpstat", "processes"]

#需要关闭的插件列表
disable_collectors: ["mdadm"]

#自定义metric采集脚本列表
metrics_bash_files: ["basic_metrics.sh","frequent_metrics.sh"]

```


部署客户端node_expoter只需要在预先在iventory/node_exporter定义主机群组，添加待部署主机的ip，并修改nodeexporter.yml文件，将hosts制定为该群组名称，执行：

```sh
$ ansible-playbook -i iventory/node_exporter nodeexporter.yml
```

##### ansible更新node_exporter配置
首先，请根据需求，修改对应组件的vars下的配置项或defaults下的默认配置项。

然后，执行playbook更新修改，通过指定标签为 ”nodeexporter-conf-update“ 实现。

```sh
$ ansible-playbook -i iventory/node_exporter nodeexporter.yml -t nodeexporter-conf-update
```


##### shell部署

获取安装脚本，本项目路径 node_exporter_install下。

分发到主机，执行脚本。

```sh
$ bash node_exporter_install.sh
```


## 资产信息采集


服务地址：

https://prom.demo.com/prome

查询接口

/api/v1/query

例子：

查询客户端IP地址，metric_name: node_ip：

curl https://prom.demo.com/prome/api/v1/query?query=node_ip

接口返回：

```
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"node_ip","instance":"192.168.1.20:9100","ipaddress":"192.168.1.20","job":"prometheus_node"},"value":[1542874037.079,"1"]},{"metric":{"__name__":"node_ip","instance":"192.168.1.32:9100","ipaddress":"192.168.1.32","job":"prometheus_node"},"value":[1542874037.079,"1"]}]}}zhangbo055559:monitoring_deploy admin$ s={"status":"success","da"metric":{"__name__":"node_ip","instance":"192.168.1.20:9100","ipaddress":"192.168.1.20","job":"prometheus_node"},"value":[1542874037.079,"1"]},{"metric":{"__name__":"node_ip","instance":"192.168.1.32:9100","ipaddress":"192.168.1.32","job":"prometheus_node"},"value":[1542874037.079,"1"]}]}}
```

解析结果（python）：

```

metric_info = json.loads(res) 

if metric_info['status'] == "success":
	Ip_addr = ['data']['result'][0]['metric']['instance']
	
return ip_addr 

```






## Todos

 - 加入服务监控

## License
----

MIT


**Free Software, Hell Yeah!**

[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)


   [dill]: <https://github.com/joemccann/dillinger>
   [git-repo-url]: <https://github.com/joemccann/dillinger.git>
   [john gruber]: <http://daringfireball.net>
   [df1]: <http://daringfireball.net/projects/markdown/>
   [markdown-it]: <https://github.com/markdown-it/markdown-it>
   [Ace Editor]: <http://ace.ajax.org>
   [node.js]: <http://nodejs.org>
   [Twitter Bootstrap]: <http://twitter.github.com/bootstrap/>
   [jQuery]: <http://jquery.com>
   [@tjholowaychuk]: <http://twitter.com/tjholowaychuk>
   [express]: <http://expressjs.com>
   [AngularJS]: <http://angularjs.org>
   [Gulp]: <http://gulpjs.com>

   [PlDb]: <https://github.com/joemccann/dillinger/tree/master/plugins/dropbox/README.md>
   [PlGh]: <https://github.com/joemccann/dillinger/tree/master/plugins/github/README.md>
   [PlGd]: <https://github.com/joemccann/dillinger/tree/master/plugins/googledrive/README.md>
   [PlOd]: <https://github.com/joemccann/dillinger/tree/master/plugins/onedrive/README.md>
   [PlMe]: <https://github.com/joemccann/dillinger/tree/master/plugins/medium/README.md>
   [PlGa]: <https://github.com/RahulHP/dillinger/blob/master/plugins/googleanalytics/README.md>
