#!/bin/bash

nodeexporter_install_path='/data/application/nodeexporter'
prometheus_user='prometheus'
prometheus_group='prometheus'
log_path='/data/log/nodeexporter'
run_old_file='/data/run/node_exporter.pid'
run_path='/data/run/nodeexporter'
TMP_DIR='/tmp'
MD5SUM='ea098f984e3a8d505d029bef2e1df831'
metrics_bash_files="basic_metrics.sh frequent_metrics.sh"

WK_DIR=${TMP_DIR}/node_exporter_install
FILE_NAME=node_exporter_installer.tar.gz

wget_install() {
  yum install wget -y
}

download_pac() {
  DOWNLOAD_URL=ftp://192.168.1.100/software/monitor/node_exporter_deploy/

  if [[ -f "${TMP_DIR}/$FILE_NAME" ]];then
    rm -rf ${TMP_DIR}/${FILE_NAME}
  fi
  wget_res=`which wget`
  if [[ ${wget_res} ]];then
    wget_install
  fi
  echo '**************************************************'
  echo 'Downloading start...'
  echo '**************************************************'
  wget --tries=3 --no-check-certificate -O ${TMP_DIR}/${FILE_NAME} ${DOWNLOAD_URL}/${FILE_NAME}
  MD5_VUE=`md5sum ${TMP_DIR}/${FILE_NAME} |awk '{print $1}'`
  echo ${MD5_VUE}
  sleep 1
  if [[ "$MD5_VUE" == "$MD5SUM" ]]; then

    echo 'Download success!'
    echo '**************************************************'
  else
    echo 'node_exporter data download failed,try again!!!'
    echo '**************************************************'
    exit 1
  fi
}


nodes_update() {
  echo 'Check vars before start install job!'
  if [[ ! "$run_path" || ! "$log_path" || ! "$nodeexporter_install_path" ]];then
    echo 'Var pid_path log_path or nodeexporter_install_path not defined! Use default value!'
    nodeexporter_install_path=${nodeexporter_install_path:-'/data/application/nodeexporter'}
    run_path=${run_path:-'/data/run/nodeexporter'}
    log_path=${log_path:-'/data/log/nodeexporter'}
  fi
  mkdir -p $run_path $log_path
  chown -R ${prometheus_user}:${prometheus_user} $run_path $log_path
  echo 'Install start right now!'
  tar -zxvf ${TMP_DIR}/${FILE_NAME} -C ${TMP_DIR}
  sleep 1
  #load vars defined in config file
  if [[ -f "${WK_DIR}/conf/node_exporter.conf" ]];then
    source ${WK_DIR}/conf/node_exporter.conf
    cp -fr ${WK_DIR}/conf/node_exporter.conf ${nodeexporter_install_path}
  else
    echo 'Config file conde_exporter.conf not exists in conf dir!'
    exit 1
  fi
  if [[ -f "${WK_DIR}/service/node_exporter.init5" ]];then
    cp -fr ${WK_DIR}/service/node_exporter.init5 /etc/init.d/node_exporter
  else
    echo 'service file conde_exporter.init5 not exists in service dir!'
    exit 1
  fi
  for bash_file in ${metrics_bash_files};do
    if [[ -f "${WK_DIR}/bin/${bash_file}" ]];then
      cp -fr ${WK_DIR}/bin/${bash_file} ${nodeexporter_install_path}
    else
      echo 'basic metrics file not exists in bin dir!'
      exit 1
    fi
  done
}

service_start() {
  echo 'delete temp dir after install finished!'
  if [[ -d ${WK_DIR} ]];then
    rm -rf ${WK_DIR}
  fi  
  node_pid=`ps -ef|grep "${nodeexporter_install_path}/node_exporter "|grep -v grep|awk '{print $2}'`
  if [[ "$node_pid" ]];then
    kill -9 ${node_pid}
    if [[ -f "$run_old_file" ]];then
      rm -rf $run_old_file
    fi
    #find ${run_path} -type f -name node_exporter.pid|xargs rm -rf {}
  fi
  echo 'Service starting!'
  service node_exporter restart
  service node_exporter start
  
  #Run once for instant
  for bash_file in ${metrics_bash_files};do
    bash ${nodeexporter_install_path}/${bash_file}
  done
  #check service status
  SERVICE_CHK=`netstat -tunlp | grep ":${nodeexporter_port}"|grep -v grep|wc -l`
  if [[ ${SERVICE_CHK} -eq 1 ]]; then
    echo '**************************************************'
    echo 'node exporter install successful!'
    echo '**************************************************'
    #exit 0
  else
    echo '**************************************************'
    echo 'node exporter service start failed!!!'
    echo '**************************************************'
    #exit 1
  fi
}

download_pac
nodes_update
service_start
