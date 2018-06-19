#! /bin/bash   

function checkHiveIsOK(){   
	hivedefaultDB=$(/opt/hive/bin/hive -e "show databases;"|grep "default" |sed 's/ //g' )  
	hiveIsOK="false" 
	if [ "$hivedefaultDB"x == "default"x ] 
	then 
		hiveIsOK="true" 
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - checkHiveIsOK : HIVE is Runing!" 1>>$KYLINAPP_LOG  2>&1
		echo $hiveIsOK
		exit 0
	fi 	 
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - checkHiveIsOK : HIVE is not Runing!" 1>>$KYLINAPP_LOG  2>&1   
	echo $hiveIsOK 
} 


function waitHiveReady(){  
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - Excute cmd: /opt/hive/bin/hive -e 'show databases;',to checkHiveIsOK." 1>>$KYLINAPP_LOG  2>&1 
	i=1   
	while [ ${i} -le 50 ]  
	do   		   
		hiveIsOK=$(checkHiveIsOK)
			
		if [  "$hiveIsOK"x == "false"x ] 
		then 
			echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - waitHiveReady  : Waiting Hive to Start..." 1>>$KYLINAPP_LOG  2>&1
			sleep 10
		else
			echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - waitHiveReady : HIVE is Runing!" 1>>$KYLINAPP_LOG  2>&1
			break
		fi   
	  	i=`expr ${i} + 1`
	  	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - waitHiveReady : wait times=$i" 1>>$KYLINAPP_LOG  2>&1
	done   
	
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - waitHiveReady : Jump wait" 1>>$KYLINAPP_LOG  2>&1
	
	hiveIsOK=$(checkHiveIsOK) 
	if [  "$hiveIsOK"x == "false"x ]
	then 
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - Error - waitHiveReady : Wait hive to start for 500s,but hive is still not running,kylin can not start." 1>>$KYLINAPP_LOG  2>&1  
		isRunning="false"
	else
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - waitHiveReady : HIVE is Runing!" 1>>$KYLINAPP_LOG  2>&1
		isRunning="true"  
	fi 
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - isHiveRunning=$isRunning" 1>>$KYLINAPP_LOG  2>&1
	echo $isRunning    
} 

function StartKAP(){    
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - user=`whoami`,kylin.sh start" 1>>$KYLINAPP_LOG  2>&1 
	
	/opt/kap-plus/bin/kylin.sh start  1>>$KYLINAPP_LOG  2>&1
	
	pid=`ps ax | grep kylin | grep -v grep | grep -v 'su kylin' | grep -v 'bash' | grep 'Dkylin.hive.dependency' | awk '{print $1}'` 
	if [ "$pid"x == ""x ]
	then 
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - Error - StartKAP:Start Kylin Service failed." 1>>$KYLINAPP_LOG  2>&1	 
		exit 1
	fi 
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - StartKAP:Started Kylin Service successfully." 1>>$KYLINAPP_LOG  2>&1
}

function StartKyAnalyzer(){   
	/opt/kyanalyzer/start-analyzer.sh  1>>$KYLINAPP_LOG  2>&1
	
	pid=`ps ax | grep kyanalyzer | grep -v grep  | awk '{print $1}'`
	if [ "$pid"x == ""x ]
	then 
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - Error - StartKyAnalyzer:Start kyanalyzer Service failed." 1>>$KYLINAPP_LOG  2>&1	 
		exit 1
	fi  
		echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - StartKyAnalyzer:Started KyAnalyzer Service successfully." 1>>$KYLINAPP_LOG  2>&1
}


function StopKAP(){   
	/opt/kap-plus/bin/kylin.sh stop  1>>$KYLINAPP_LOG  2>&1
	pid=`ps ax | grep kylin | grep -v grep | grep -v 'su kylin' | grep -v 'bash' | grep 'Dkylin.hive.dependency' | awk '{print $1}'` 
	if [ "$pid"x != ""x ]
	then  
		kill -9 $pid
		echo "`date '+%Y-%m-%d %H:%M:%S'`- kylinutil.sh - INFO - Stopped Kylin Service by killing pid=$pid." 1>>$KYLINAPP_LOG  2>&1
	fi  
		echo "`date '+%Y-%m-%d %H:%M:%S'`- kylinutil.sh - INFO - Stopped Kylin Service successfully." 1>>$KYLINAPP_LOG  2>&1
}

function StopKyAnalyzer(){  
	/opt/kyanalyzer/stop-analyzer.sh  1>>$KYLINAPP_LOG  2>&1
	pid=`ps ax | grep kyanalyzer | grep -v grep  | awk '{print $1}'`
	if [ "$pid"x != ""x ]
	then  	
		kill -9 $pid
		echo "`date '+%Y-%m-%d %H:%M:%S'`- kylinutil.sh - INFO - Stopped KyAnalyzer Service by killing pid=$pid." 1>>$KYLINAPP_LOG  2>&1
	fi
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - Stoped KyAnalyzer Service successfully." 1>>$KYLINAPP_LOG  2>&1
}


function DealWithHDFS4Kylin(){   
#Deal with HDFS 
#if enable_kylin is true,for the first time it needs to create HDFS folder for kylin.	 
    #必须要用sudo去执行创建和修改hdfs目录的操作，否则在kylin用户下执行不成功。
    sudo /opt/hadoop/bin/hadoop fs -chmod -R 777 /tmp   1>>$KYLINAPP_LOG  2>&1  
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - sudo chmod hdfs -R 777 /tmp" 1>>$KYLINAPP_LOG  2>&1 
 	
	/opt/hadoop/bin/hadoop fs -test -e /kylin  
	if [ $? -ne 0 ]
    then  
    	sudo /opt/hadoop/bin/hadoop fs -mkdir /kylin  1>>$KYLINAPP_LOG  2>&1
    	sudo /opt/hadoop/bin/hadoop fs -chown kylin /kylin  1>>$KYLINAPP_LOG  2>&1
    	sudo /opt/hadoop/bin/hadoop fs -chmod -R 777 /kylin  1>>$KYLINAPP_LOG  2>&1	
    	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - sudo Create hdfs dir /kylin" 1>>$KYLINAPP_LOG  2>&1
	fi 
    	
  
	/opt/hadoop/bin/hadoop fs -test -e /user
	if [ $? -ne 0 ]
    then  
    	sudo /opt/hadoop/bin/hadoop fs -mkdir /user  1>>$KYLINAPP_LOG  2>&1
    	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - sudo Create hdfs dir /user" 1>>$KYLINAPP_LOG  2>&1
	fi 
	
	/opt/hadoop/bin/hadoop fs -test -e /user/kylin
	if [ $? -ne 0 ]
    then  
    	sudo /opt/hadoop/bin/hadoop fs -mkdir /user/kylin 1>>$KYLINAPP_LOG  2>&1
    	sudo /opt/hadoop/bin/hadoop fs -chown kylin /user/kylin  1>>$KYLINAPP_LOG  2>&1
    	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - sudo Create hdfs dir /user/kylin" 1>>$KYLINAPP_LOG  2>&1 
	fi    
	
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - hdfs dir info - =============================" 1>>$KYLINAPP_LOG  2>&1	
	/opt/hadoop/bin/hadoop fs -ls /  1>>$KYLINAPP_LOG  2>&1   
	
	touch  /opt/kap-plus/sbin/hdfsfolder_created
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - DealWithHDFS4Kylin for kylin service init finished,create /opt/kap-plus/bin/sample_loaded Flag file." 1>>$KYLINAPP_LOG  2>&1
	  
}




function loadSampleData4Kylin(){ 
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - Excute cmd: /opt/kap-plus/bin/sample.sh" 1>>$KYLINAPP_LOG  2>&1  
	/opt/kap-plus/bin/sample.sh    >/dev/null 2>&1
	touch  /opt/kap-plus/sbin/sample_loaded
	echo "`date '+%Y-%m-%d %H:%M:%S'` - kylinutil.sh - INFO - Load sample data for kylin service init finished,create /opt/kap-plus/bin/sample_loadedFlag file." 1>>$KYLINAPP_LOG  2>&1 	
}

 


